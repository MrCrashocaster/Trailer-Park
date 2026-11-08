extends Node
## The single authority for simulation, network requests and save files.
## Clients send intentions; only the host/server changes Park state.

signal status_changed(message: String)
signal peers_changed()
signal command_result(message: String, ok: bool)
signal plans_changed()
signal approvals_changed()

const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 27840
const MAX_PLAYERS: int = 4
const MAX_PACKET_CHARACTERS: int = 8192
const SNAPSHOT_INTERVAL: float = 0.65
const AUTOSAVE_INTERVAL: float = 30.0
const PLAN_LIFETIME_MS: int = 4500
const APPROVAL_LIFETIME_MS: int = 120000
const ALLOWED_ACTIONS: Array[String] = [
	"place", "demolish", "move", "repair", "upgrade", "set_rent",
	"buy_land", "loan", "repay", "speed", "resolve_event", "rename", "road_path"
]

var player_name: String = "Manager"
var players: Dictionary = {}
var plans: Dictionary = {}
var mode: String = "solo"
var connected: bool = false
var connecting: bool = false
var server_address: String = ""
var server_port: int = DEFAULT_PORT
var access_code: String = ""
var save_slot: String = "park"
var save_directory: String = "user://saves"
var spending_limit: float = 0.0
var pending_requests: Array = []
var manager_id: int = 1
var last_status: String = "Local park — host a session to invite friends."

var _session_id: String = ""
var _command_sequence: int = 0
var _last_sequences: Dictionary = {}
var _rate_windows: Dictionary = {}
var _pending_peers: Dictionary = {}
var _joined: bool = false
var _dirty: bool = false
var _snapshot_clock: float = 0.0
var _autosave_clock: float = 0.0
var _plan_clock: float = 0.0
var _snapshot_serial: int = 0
var _last_snapshot_serial: int = -1
var _local_plan_at: int = 0
var _autosave_enabled: bool = true
var _recovered_backup_slots: Dictionary = {}
var _next_request_id: int = 1


func _ready() -> void:
	Park.changed.connect(_on_park_changed)
	if multiplayer is SceneMultiplayer:
		# Clients speak only to the authority. Our explicit roster replication
		# does not need Godot's peer-to-peer relay mesh or its extra disconnects.
		multiplayer.server_relay = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	players[1] = {"name": player_name}
	# Autoloads are ready before Main. Configure here so a dedicated server
	# never constructs the visual park or HUD while waiting for a deferred call.
	_configure_command_line()


func _process(delta: float) -> void:
	if is_authority():
		# A dedicated park sleeps when the final player leaves.
		if mode != "server" or not players.is_empty():
			Park.advance(minf(delta, 0.25))
		_snapshot_clock += delta
		if _dirty and _snapshot_clock >= SNAPSHOT_INTERVAL:
			_snapshot_clock = 0.0
			_broadcast_state()
		_autosave_clock += delta
		if _autosave_enabled and _autosave_clock >= AUTOSAVE_INTERVAL:
			_autosave_clock = 0.0
			_write_save(save_slot, true)
		_plan_clock += delta
		if _plan_clock >= 1.0:
			_plan_clock = 0.0
			_expire_plans()
			_expire_unregistered_peers()
			_expire_approvals()


func is_authority() -> bool:
	return mode != "client"


func host_game(port: int = DEFAULT_PORT) -> Error:
	return _start_host(port, false)


func _start_host(port: int, dedicated: bool) -> Error:
	if port < 1024 or port > 65535:
		_set_status("Choose a port between 1024 and 65535.")
		return ERR_INVALID_PARAMETER
	_close_peer()
	mode = "solo"
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var result: Error = peer.create_server(port, MAX_PLAYERS if dedicated else MAX_PLAYERS - 1)
	if result != OK:
		_set_status("Could not host on port %d. Another park may already be using it." % port)
		return result
	multiplayer.multiplayer_peer = peer
	mode = "server" if dedicated else "host"
	connected = true
	server_address = "0.0.0.0"
	server_port = port
	_session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]
	_joined = true
	players.clear()
	manager_id = 0 if dedicated else 1
	if not dedicated:
		players[1] = {"name": _clean_name(player_name)}
	_last_sequences.clear()
	_rate_windows.clear()
	_pending_peers.clear()
	_snapshot_serial = 0
	_set_status("Park hosted on port %d. Share your reachable address%s." % [port, " and access code" if not access_code.is_empty() else ""])
	peers_changed.emit()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var host_address: String = address.strip_edges()
	if host_address.is_empty() or host_address.length() > 253 or port < 1024 or port > 65535:
		_set_status("Enter a server address and a port between 1024 and 65535.")
		return ERR_INVALID_PARAMETER
	_close_peer()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var result: Error = peer.create_client(host_address, port)
	if result != OK:
		_set_status("Could not start a connection to that park.")
		return result
	mode = "client"
	connected = false
	connecting = true
	_joined = false
	server_address = host_address
	server_port = port
	players.clear()
	_command_sequence = 0
	_last_snapshot_serial = -1
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s:%d…" % [server_address, server_port])
	peers_changed.emit()
	return OK


func disconnect_game() -> void:
	if is_authority():
		_write_save(save_slot, true)
	_close_peer()
	mode = "solo"
	players = {1: {"name": _clean_name(player_name)}}
	_set_status("Disconnected. The last received park is available locally.")
	peers_changed.emit()


func new_game() -> void:
	if not is_authority():
		command_result.emit("Only the park host can start a new park.", false)
		return
	Park.reset()
	pending_requests.clear()
	_dirty = true
	_broadcast_state()
	_broadcast_policy()
	command_result.emit("New park started.", true)


func command(action: String, data: Dictionary = {}) -> void:
	if not _valid_request(action, data):
		command_result.emit("That action is not valid.", false)
		return
	if mode == "client":
		if not connected or not _joined:
			command_result.emit("Wait for the park connection before making changes.", false)
			return
		_command_sequence += 1
		_request_command.rpc_id(1, action, data, _command_sequence, _session_id)
	else:
		var result: Dictionary = _dispatch_action(1, action, data)
		command_result.emit(str(result.get("message", "Done.")), bool(result.get("ok", false)))


func is_manager() -> bool:
	if mode == "solo":
		return true
	if mode == "server":
		return false
	return connected and manager_id == multiplayer.get_unique_id()


func set_spending_limit(value: float) -> void:
	if not is_finite(value) or value < 0.0 or value > 1000000.0:
		command_result.emit("Choose a spending limit between $0 and $1,000,000; zero turns approvals off.", false)
		return
	if mode == "client":
		if not connected or not _joined:
			command_result.emit("Connect to the park before changing its policy.", false)
			return
		_request_policy.rpc_id(1, value, _session_id)
	elif mode == "server" or is_manager():
		_apply_policy(value)
	else:
		command_result.emit("Only the session manager can change spending approval.", false)


func approve_request(id: int, allowed: bool) -> void:
	if mode == "client":
		if not connected or not _joined:
			command_result.emit("Connect to the park before reviewing requests.", false)
			return
		_request_approval.rpc_id(1, id, allowed, _session_id)
	elif is_manager():
		_review_request(1, id, allowed)
	else:
		command_result.emit("Only the session manager can review requests.", false)


func publish_plan(kind: String, x: int, z: int, rotation: int = 0) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _local_plan_at < 120:
		return
	_local_plan_at = now
	if not _valid_plan(kind, x, z, rotation):
		return
	if mode == "client":
		if connected and _joined:
			_request_plan.rpc_id(1, kind, x, z, rotation, _session_id)
	else:
		_set_plan(1, kind, x, z, rotation)


func save_game(slot: String = "park") -> bool:
	if not is_authority():
		command_result.emit("The host saves the shared park. Your changes are already synchronized.", false)
		return false
	return _write_save(slot, false)


func load_game(slot: String = "park") -> bool:
	if not is_authority():
		command_result.emit("Only the host can load a shared park.", false)
		return false
	var safe_slot: String = _safe_slot(slot)
	if safe_slot.is_empty():
		command_result.emit("Invalid save name.", false)
		return false
	var path: String = save_directory.path_join(safe_slot + ".json")
	var loaded: bool = _try_load(path)
	var recovered: bool = false
	if not loaded:
		loaded = _try_load(path + ".bak")
		recovered = loaded
	if not loaded:
		command_result.emit("No valid saved park was found. Your current park was kept.", false)
		return false
	save_slot = safe_slot
	if recovered:
		_recovered_backup_slots[safe_slot] = true
	_dirty = true
	_broadcast_state()
	_broadcast_policy()
	command_result.emit("Recovered the backup park." if recovered else "Park loaded.", true)
	return true


func _write_save(slot: String, quiet: bool) -> bool:
	var safe_slot: String = _safe_slot(slot)
	if safe_slot.is_empty():
		return _save_failure("Invalid save name.", quiet)
	var directory: String = ProjectSettings.globalize_path(save_directory)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return _save_failure("The save folder could not be created.", quiet)
	var path: String = directory.path_join(safe_slot + ".json")
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _save_failure("The park could not be written. Check available storage.", quiet)
	file.store_string(JSON.stringify({"format": "trailer-park", "version": 1, "saved_at": Time.get_datetime_string_from_system(true), "state": Park.snapshot(), "policy": {"spending_limit": spending_limit}}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _save_failure("The park save was interrupted. The previous save was kept.", quiet)
	if FileAccess.file_exists(path):
		if _recovered_backup_slots.has(safe_slot):
			# The primary is known bad. Keep the recovered good backup until a
			# complete new primary has been finalized, including across a crash.
			if DirAccess.remove_absolute(path) != OK:
				return _save_failure("The damaged primary save could not be replaced.", quiet)
		else:
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
				return _save_failure("The previous backup could not be replaced.", quiet)
			if DirAccess.rename_absolute(path, backup) != OK:
				return _save_failure("The previous save could not be backed up.", quiet)
	if DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup, path)
		return _save_failure("The new save could not be finalized. The previous save was kept.", quiet)
	save_slot = safe_slot
	_recovered_backup_slots.erase(safe_slot)
	if not quiet:
		command_result.emit("Park saved.", true)
	return true


func _try_load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		return false
	var parser: JSON = JSON.new()
	var parsed_ok: Error = parser.parse(file.get_as_text())
	file.close()
	if parsed_ok != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return false
	var envelope: Dictionary = parser.data
	if envelope.get("format") != "trailer-park" or envelope.get("version") != 1 or typeof(envelope.get("state")) != TYPE_DICTIONARY:
		return false
	var policy: Variant = envelope.get("policy", {"spending_limit": 0.0})
	if not policy is Dictionary:
		return false
	var limit: Variant = policy.get("spending_limit", 0.0)
	if not (limit is int or limit is float) or not is_finite(float(limit)) or float(limit) < 0.0 or float(limit) > 1000000.0:
		return false
	if not Park.restore(envelope["state"]):
		return false
	spending_limit = float(limit)
	pending_requests.clear()
	return true


func _save_failure(message: String, quiet: bool) -> bool:
	if not quiet:
		command_result.emit(message, false)
	else:
		_set_status(message)
	return false


func _safe_slot(slot: String) -> String:
	if slot.is_empty() or slot.length() > 40:
		return ""
	for character: String in slot:
		if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return ""
	return slot


func _configure_command_line() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var port: int = DEFAULT_PORT
	var dedicated: bool = false
	var join_address: String = ""
	for argument: String in arguments:
		if argument == "--server":
			dedicated = true
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--join="):
			join_address = argument.trim_prefix("--join=")
		elif argument.begins_with("--name="):
			player_name = _clean_name(argument.trim_prefix("--name="))
		elif argument.begins_with("--save-slot="):
			var candidate: String = _safe_slot(argument.trim_prefix("--save-slot="))
			if not candidate.is_empty():
				save_slot = candidate
		elif argument.begins_with("--access-code="):
			access_code = argument.trim_prefix("--access-code=").left(64)
		elif argument == "--no-autosave":
			_autosave_enabled = false
	if dedicated:
		Engine.max_fps = 30
		var path: String = save_directory.path_join(save_slot + ".json")
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			load_game(save_slot)
		var error: Error = _start_host(port, true)
		if error != OK:
			get_tree().quit(2)
	elif not join_address.is_empty():
		join_game(join_address, port)
	else:
		players[1] = {"name": _clean_name(player_name)}
		peers_changed.emit()


@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(name_value: String, protocol: int, code: String) -> void:
	if not _network_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _pending_peers.has(sender) or players.has(sender):
		return
	if protocol != PROTOCOL_VERSION or (not access_code.is_empty() and code != access_code):
		_reject_join.rpc_id(sender, "The park access code or game version does not match.")
		_disconnect_later(sender)
		return
	if players.size() >= MAX_PLAYERS:
		_reject_join.rpc_id(sender, "This park already has four players.")
		_disconnect_later(sender)
		return
	_pending_peers.erase(sender)
	players[sender] = {"name": _clean_name(name_value)}
	if manager_id == 0:
		manager_id = sender
	_last_sequences[sender] = 0
	_rate_windows[sender] = {"at": Time.get_ticks_msec(), "commands": 0, "plans": 0}
	_accept_join.rpc_id(sender, Park.snapshot(), players, _session_id, _snapshot_serial)
	_broadcast_roster()
	_broadcast_policy()
	peers_changed.emit()
	_set_status("%s joined the park (%d/4)." % [str(players[sender]["name"]), players.size()])


@rpc("authority", "call_remote", "reliable", 0)
func _accept_join(snapshot: Dictionary, roster: Dictionary, session_id: String, serial: int) -> void:
	if mode != "client":
		return
	if not Park.restore(snapshot):
		_set_status("The host sent an incompatible park. Update both copies of the game.")
		_close_peer()
		return
	players = roster.duplicate(true)
	_session_id = session_id
	_last_snapshot_serial = serial
	_command_sequence = 0
	_joined = true
	connected = true
	connecting = false
	_set_status("Connected to the shared park (%d/4)." % players.size())
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _reject_join(message: String) -> void:
	if mode == "client":
		_set_status(message)
		command_result.emit(message, false)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_command(action: String, data: Dictionary, sequence: int, token: String) -> void:
	if not _network_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or token != _session_id:
		return
	if sequence != int(_last_sequences.get(sender, 0)) + 1:
		_action_result.rpc_id(sender, "This action was already processed or arrived out of order.", false)
		return
	# Consume each sequence even for rejected actions, so one typo cannot strand a peer.
	_last_sequences[sender] = sequence
	if not _allow_rate(sender, "commands", 40):
		_action_result.rpc_id(sender, "Too many actions at once. Try again in a moment.", false)
		return
	if not _valid_request(action, data):
		_action_result.rpc_id(sender, "That action is not valid.", false)
		return
	var result: Dictionary = _dispatch_action(sender, action, data)
	var ok: bool = bool(result.get("ok", false))
	_action_result.rpc_id(sender, str(result.get("message", "Done.")), ok)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_policy(value: float, token: String) -> void:
	if not _network_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or token != _session_id:
		return
	if sender != manager_id:
		_action_result.rpc_id(sender, "Only the session manager can change spending approval.", false)
		return
	if not _allow_rate(sender, "policy", 8) or not is_finite(value) or value < 0.0 or value > 1000000.0:
		_action_result.rpc_id(sender, "Invalid spending limit or too many policy changes.", false)
		return
	_apply_policy(value)
	_action_result.rpc_id(sender, "Spending approval policy updated.", true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_approval(id: int, allowed: bool, token: String) -> void:
	if not _network_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or token != _session_id:
		return
	if sender != manager_id or not _allow_rate(sender, "policy", 8):
		_action_result.rpc_id(sender, "Only the session manager can review requests.", false)
		return
	_review_request(sender, id, allowed)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_policy(limit: float, manager: int, requests: Array) -> void:
	if mode != "client" or not _joined:
		return
	spending_limit = limit
	manager_id = manager
	pending_requests = requests.duplicate(true)
	approvals_changed.emit()


func _dispatch_action(peer_id: int, action: String, data: Dictionary) -> Dictionary:
	if spending_limit > 0.0 and peer_id != manager_id and not (mode == "server" and peer_id == 1):
		var cost: float = _estimated_cost(action, data)
		if cost > spending_limit or action in ["loan", "demolish"]:
			return _queue_approval(peer_id, action, data, cost)
	var actor: String = str(players.get(peer_id, {}).get("name", _clean_name(player_name)))
	var result: Dictionary = Park.apply_command(action, data, actor)
	if bool(result.get("ok", false)):
		_dirty = true
		_broadcast_state()
	return result


func _estimated_cost(action: String, data: Dictionary) -> float:
	match action:
		"place":
			return float(Park.CATALOG.get(str(data.get("kind", "")), {}).get("cost", 0.0))
		"buy_land":
			return float(Park.PARCEL_COST)
		"road_path":
			var check: Dictionary = Park.validate_road_path(data.get("points", []))
			return maxf(0.0, float(check.get("cost", 0.0)))
		"loan", "repay":
			return maxf(0.0, float(data.get("amount", 0.0))) if data.get("amount") is int or data.get("amount") is float else 0.0
		"repair", "upgrade", "move":
			var building: Dictionary = {}
			for candidate: Dictionary in Park.state.buildings:
				if candidate.id == data.get("id"):
					building = candidate
					break
			if building.is_empty():
				return 0.0
			if action == "repair":
				return Park.repair_cost(building)
			if action == "upgrade":
				return Park.upgrade_cost(building)
			return Park.move_cost(building)
		"resolve_event":
			var choice_value: Variant = data.get("choice")
			if not (choice_value is int or choice_value is float) or int(choice_value) < 0 or int(choice_value) > 2:
				return 0.0
			for event: Dictionary in Park.state.events:
				if event.id == data.get("id"):
					return maxf(0.0, float(event.choices[int(choice_value)].cost))
	return 0.0


func _queue_approval(peer_id: int, action: String, data: Dictionary, cost: float) -> Dictionary:
	var owned_count: int = 0
	for request: Dictionary in pending_requests:
		if int(request.peer) == peer_id:
			owned_count += 1
			if str(request.action) == action and request.data == data:
				return {"ok": false, "message": "That action is already awaiting manager approval."}
	if owned_count >= 4 or pending_requests.size() >= 12:
		return {"ok": false, "message": "There are already several requests waiting. Let the manager review them first."}
	var request: Dictionary = {"id": _next_request_id, "peer": peer_id, "name": str(players.get(peer_id, {}).get("name", "Manager")), "action": action, "data": data.duplicate(true), "cost": cost, "created": Time.get_ticks_msec()}
	_next_request_id += 1
	pending_requests.append(request)
	_broadcast_policy()
	return {"ok": true, "message": "Sent to the session manager for approval. No park funds have been spent."}


func _apply_policy(value: float) -> void:
	spending_limit = snappedf(value, 1.0)
	if spending_limit == 0.0:
		for request: Dictionary in pending_requests:
			_deliver_result(int(request.peer), "Spending approval was turned off. Submit your action again to carry it out.", false)
		pending_requests.clear()
	_broadcast_policy()
	if mode != "server":
		command_result.emit("Spending approval disabled." if spending_limit == 0.0 else "Purchases above $%d, loans and demolition now need manager approval." % int(spending_limit), true)


func _review_request(reviewer: int, id: int, allowed: bool) -> void:
	if reviewer != manager_id:
		_deliver_result(reviewer, "Only the session manager can review requests.", false)
		return
	var index: int = -1
	for i: int in range(pending_requests.size()):
		if int(pending_requests[i].id) == id:
			index = i
			break
	if index < 0:
		_deliver_result(reviewer, "That request has already been reviewed or expired.", false)
		return
	var request: Dictionary = pending_requests[index]
	pending_requests.remove_at(index)
	if not players.has(int(request.peer)):
		_deliver_result(reviewer, "That player has left the park.", false)
	elif not allowed:
		_deliver_result(int(request.peer), "The session manager declined your request.", false)
		_deliver_result(reviewer, "Request declined.", true)
	else:
		# Re-evaluate current funds, footprint, access, unlocks and condition. A
		# request is an intention, never a reservation or a cached transaction.
		var result: Dictionary = Park.apply_command(str(request.action), request.data, str(request.name) + " (approved)")
		var success: bool = bool(result.get("ok", false))
		var message: String = str(result.get("message", "Request reviewed."))
		_deliver_result(int(request.peer), message, success)
		if reviewer != int(request.peer):
			_deliver_result(reviewer, "%s: %s" % [str(request.name), message], success)
		if success:
			_dirty = true
			_broadcast_state()
	_broadcast_policy()


func _deliver_result(peer_id: int, message: String, ok: bool) -> void:
	if peer_id == 1 and mode != "server":
		command_result.emit(message, ok)
	elif _remote_recipients().has(peer_id):
		_action_result.rpc_id(peer_id, message, ok)


func _expire_approvals() -> void:
	var now: int = Time.get_ticks_msec()
	var removed: bool = false
	for i: int in range(pending_requests.size() - 1, -1, -1):
		var request: Dictionary = pending_requests[i]
		if now - int(request.created) > APPROVAL_LIFETIME_MS:
			pending_requests.remove_at(i)
			_deliver_result(int(request.peer), "Your pending request expired. Submit it again if it is still needed.", false)
			removed = true
	if removed:
		_broadcast_policy()


func _broadcast_policy() -> void:
	if _network_authority():
		for peer_id: int in _remote_recipients():
			_receive_policy.rpc_id(peer_id, spending_limit, manager_id, pending_requests)
	approvals_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _action_result(message: String, ok: bool) -> void:
	if mode == "client":
		command_result.emit(message, ok)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_state(snapshot: Dictionary, serial: int) -> void:
	if mode != "client" or not _joined or serial <= _last_snapshot_serial:
		return
	if Park.restore(snapshot):
		_last_snapshot_serial = serial
	else:
		_set_status("A park update was incompatible. Reconnect to recover the latest save.")


@rpc("authority", "call_remote", "reliable", 0)
func _receive_roster(roster: Dictionary) -> void:
	if mode == "client" and _joined:
		players = roster.duplicate(true)
		peers_changed.emit()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _request_plan(kind: String, x: int, z: int, rotation: int, token: String) -> void:
	if not _network_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or token != _session_id or not _allow_rate(sender, "plans", 12):
		return
	if _valid_plan(kind, x, z, rotation):
		_set_plan(sender, kind, x, z, rotation)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_plans(value: Dictionary) -> void:
	if mode == "client" and _joined:
		plans = value.duplicate(true)
		plans_changed.emit()


func _valid_request(action: String, data: Dictionary) -> bool:
	if not action in ALLOWED_ACTIONS or data.size() > 16:
		return false
	for key: Variant in data:
		if typeof(key) != TYPE_STRING or str(key).length() > 40:
			return false
		var value: Variant = data[key]
		if action == "road_path" and str(key) == "points":
			if not _valid_road_points(value):
				return false
			continue
		if typeof(value) == TYPE_FLOAT and not is_finite(float(value)):
			return false
		if not typeof(value) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_NIL]:
			return false
		if typeof(value) == TYPE_STRING and str(value).length() > 160:
			return false
	return JSON.stringify(data).length() <= MAX_PACKET_CHARACTERS


func _valid_road_points(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > 96:
		return false
	for point: Variant in value:
		if not point is Dictionary or point.size() != 2:
			return false
		for key: String in ["x", "z"]:
			var coordinate: Variant = point.get(key)
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate) != floorf(float(coordinate)):
				return false
		if int(point.x) < 0 or int(point.x) >= Park.GRID_W or int(point.z) < 0 or int(point.z) >= Park.GRID_H:
			return false
	return true


func _valid_plan(kind: String, x: int, z: int, rotation: int) -> bool:
	return (kind.is_empty() or Park.CATALOG.has(kind)) and x >= 0 and x < Park.GRID_W and z >= 0 and z < Park.GRID_H and rotation >= 0 and rotation <= 3


func _allow_rate(peer_id: int, category: String, maximum: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var window: Dictionary = _rate_windows.get(peer_id, {"at": now, "commands": 0, "plans": 0})
	if now - int(window["at"]) >= 1000:
		window = {"at": now, "commands": 0, "plans": 0}
	window[category] = int(window.get(category, 0)) + 1
	_rate_windows[peer_id] = window
	return int(window[category]) <= maximum


func _set_plan(peer_id: int, kind: String, x: int, z: int, rotation: int) -> void:
	if kind.is_empty():
		plans.erase(peer_id)
	else:
		plans[peer_id] = {"peer": peer_id, "name": str(players.get(peer_id, {}).get("name", player_name)), "kind": kind, "x": x, "z": z, "rotation": rotation, "updated": Time.get_ticks_msec()}
	_broadcast_plans()


func _expire_plans() -> void:
	var removed: bool = false
	var now: int = Time.get_ticks_msec()
	for peer_id: Variant in plans.keys():
		if now - int(plans[peer_id].get("updated", 0)) > PLAN_LIFETIME_MS:
			plans.erase(peer_id)
			removed = true
	if removed:
		_broadcast_plans()


func _expire_unregistered_peers() -> void:
	var now: int = Time.get_ticks_msec()
	for peer_id: Variant in _pending_peers.keys():
		if now - int(_pending_peers[peer_id]) > 10000:
			_pending_peers.erase(peer_id)
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(int(peer_id))


func _broadcast_state() -> void:
	_dirty = false
	if not _network_authority():
		return
	_snapshot_serial += 1
	var recipients: Array[int] = _remote_recipients()
	if not recipients.is_empty():
		var snapshot: Dictionary = Park.snapshot()
		for peer_id: int in recipients:
			_receive_state.rpc_id(peer_id, snapshot, _snapshot_serial)


func _broadcast_roster() -> void:
	if _network_authority():
		for peer_id: int in _remote_recipients():
			_receive_roster.rpc_id(peer_id, players)


func _broadcast_plans() -> void:
	if _network_authority():
		for peer_id: int in _remote_recipients():
			_receive_plans.rpc_id(peer_id, plans)
	plans_changed.emit()


func _remote_recipients() -> Array[int]:
	var result: Array[int] = []
	if not _network_authority():
		return result
	var live_peers: PackedInt32Array = multiplayer.get_peers()
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	for value: Variant in players:
		var peer_id: int = int(value)
		if peer_id == 1 or not live_peers.has(peer_id):
			continue
		var packet_peer: ENetPacketPeer = peer.get_peer(peer_id)
		# During peer_disconnected callbacks Godot can still list a transport
		# whose channels are already closed. Never broadcast to that handle.
		if packet_peer != null and packet_peer.is_active() and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED and packet_peer.get_channels() >= 3:
			result.append(peer_id)
	return result


func _on_park_changed() -> void:
	if is_authority():
		_dirty = true


func _on_peer_connected(peer_id: int) -> void:
	if _network_authority():
		_pending_peers[peer_id] = Time.get_ticks_msec()


func _on_peer_disconnected(peer_id: int) -> void:
	if not _network_authority():
		return
	var departed_name: String = str(players.get(peer_id, {}).get("name", "A player"))
	players.erase(peer_id)
	plans.erase(peer_id)
	_last_sequences.erase(peer_id)
	_rate_windows.erase(peer_id)
	_pending_peers.erase(peer_id)
	for i: int in range(pending_requests.size() - 1, -1, -1):
		if int(pending_requests[i].peer) == peer_id:
			pending_requests.remove_at(i)
	if manager_id == peer_id:
		manager_id = int(players.keys()[0]) if not players.is_empty() else 0
	_broadcast_roster()
	_broadcast_plans()
	_broadcast_policy()
	peers_changed.emit()
	_set_status("%s left the park." % departed_name)
	if mode == "server" and players.is_empty():
		_write_save(save_slot, true)


func _on_connected_to_server() -> void:
	if mode == "client":
		_set_status("Connected. Loading the shared park…")
		_hello.rpc_id(1, _clean_name(player_name), PROTOCOL_VERSION, access_code)


func _on_connection_failed() -> void:
	_close_peer()
	mode = "client"
	_set_status("Could not reach the park. Check its address, port and connection.")
	peers_changed.emit()


func _on_server_disconnected() -> void:
	_close_peer()
	# Keep the disconnected replica frozen. It must not become an authority or
	# overwrite a local save merely because a phone temporarily loses its network.
	mode = "client"
	_set_status("Connection lost. Rejoin the host to resume the shared park.")
	peers_changed.emit()


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	connecting = false
	_joined = false
	plans.clear()
	players.clear()
	_pending_peers.clear()
	_last_sequences.clear()
	_rate_windows.clear()
	_command_sequence = 0
	_last_snapshot_serial = -1
	pending_requests.clear()
	manager_id = 1
	approvals_changed.emit()
	plans_changed.emit()


func _disconnect_later(peer_id: int) -> void:
	await get_tree().create_timer(0.25).timeout
	if _network_authority():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _network_authority() -> bool:
	return mode in ["host", "server"] and multiplayer.is_server() and connected


func _clean_name(value: String) -> String:
	var cleaned: String = ""
	var prefix: String = value.left(128)
	for index: int in range(prefix.length()):
		var codepoint: int = prefix.unicode_at(index)
		cleaned += " " if codepoint < 32 or codepoint == 127 else prefix.substr(index, 1)
	cleaned = cleaned.strip_edges().left(24)
	return cleaned if not cleaned.is_empty() else "Manager"


func _set_status(message: String) -> void:
	last_status = message
	status_changed.emit(message)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and is_authority() and is_node_ready():
		_write_save(save_slot, true)
