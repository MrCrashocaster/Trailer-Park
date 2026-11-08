extends SceneTree
## Process fixture driven by tools/test_network.py. Each peer is a real ENet process.

var _session: Node
var _park: Node

var _role: String = ""
var _index: int = 0
var _directory: String = ""
var _action_at: float = 0.0
var _results: Array = []
var _statuses: Array[String] = []
var _started_at: int = 0
var _approval_phase_done: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			_role = argument.trim_prefix("--test-role=")
		elif argument.begins_with("--test-index="):
			_index = int(argument.trim_prefix("--test-index="))
		elif argument.begins_with("--test-dir="):
			_directory = argument.trim_prefix("--test-dir=")
		elif argument.begins_with("--action-at="):
			_action_at = float(argument.trim_prefix("--action-at="))
	_started_at = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	_session = root.get_node("Session")
	_park = root.get_node("Park")
	_session.save_directory = _directory.path_join("saves" if _role == "server" else "client_saves_%d" % _index)
	_session.command_result.connect(func(message: String, ok: bool) -> void: _results.append({"message": message, "ok": ok}))
	_session.status_changed.connect(func(message: String) -> void: _statuses.append(message))
	if _role == "server":
		await _run_server()
	elif _role == "overflow":
		await _run_overflow()
	elif _role == "observer":
		await _run_observer()
	else:
		await _run_client()


func _run_server() -> void:
	# These test-only starting funds let the race prove affordability as well as
	# collision handling. There is no debug-money RPC in the game protocol.
	_park.state.cash = float(_park.CATALOG.tree.cost)
	_park.apply_command("speed", {"value": 0}, "Test")
	_write("server.ready", {"ready": _session.mode == "server"})
	print("NETWORK_SERVER_READY")
	var funded_approval_test: bool = false
	var sent_bad_snapshot: bool = false
	var sent_good_snapshot: bool = false
	var kicked_observer: bool = false
	var departed_observer: int = 0
	var expired_requests: bool = false
	while not FileAccess.file_exists(_directory.path_join("stop")):
		if not funded_approval_test and FileAccess.file_exists(_directory.path_join("begin_approvals")):
			_park.state.cash = float(_park.CATALOG.tree.cost)
			_park.apply_command("set_rent", {"value": 125}, "Test")
			_session._broadcast_state()
			funded_approval_test = true
			_write("approval_funded.json", {"cash": _park.state.cash})
		if not sent_bad_snapshot and FileAccess.file_exists(_directory.path_join("inject_bad_snapshot.json")):
			var injection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join("inject_bad_snapshot.json")))
			var malformed: Dictionary = _park.snapshot()
			malformed.cash = INF
			_session._receive_state.rpc_id(int(injection.peer), malformed, _session._snapshot_serial + 100)
			sent_bad_snapshot = true
		if not expired_requests and FileAccess.file_exists(_directory.path_join("expire_requests")):
			# Advance request age, not gameplay time, to test the real expiry
			# handler without adding a two-minute sleep to every CI run.
			for request: Dictionary in _session.pending_requests:
				request.created = Time.get_ticks_msec() - _session.APPROVAL_LIFETIME_MS - 1
			_session._expire_approvals()
			expired_requests = true
		if not sent_good_snapshot and FileAccess.file_exists(_directory.path_join("send_good_snapshot")):
			_session._broadcast_state()
			sent_good_snapshot = true
		if not kicked_observer and FileAccess.file_exists(_directory.path_join("kick_observer.json")):
			var kick: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join("kick_observer.json")))
			departed_observer = int(kick.peer)
			_session.multiplayer.multiplayer_peer.disconnect_peer(departed_observer)
			kicked_observer = true
		if kicked_observer and not _session.players.has(departed_observer) and not FileAccess.file_exists(_directory.path_join("pending_cleanup.json")):
			_write("pending_cleanup.json", {"pending": _session.pending_requests.size()})
		if Time.get_ticks_msec() - _started_at > 55000:
			_fail("Server fixture timed out.")
			return
		await create_timer(0.05).timeout
	var initial_snapshot: Dictionary = _park.snapshot()
	var saved_twice: bool = _session.save_game(_session.save_slot) and _session.save_game(_session.save_slot)
	var bad_path: String = _session.save_directory.path_join(_session.save_slot + ".json")
	var damaged: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
	if damaged != null:
		damaged.store_string("{broken save")
		damaged.close()
	var recovered: bool = _session.load_game(_session.save_slot)
	# JSON numerics normalize through a save (1 and 1.0 have the same value).
	var same_after_recovery: bool = JSON.parse_string(JSON.stringify(_park.snapshot())) == JSON.parse_string(JSON.stringify(initial_snapshot))
	var saved_after_recovery: bool = _session.save_game(_session.save_slot)
	damaged = FileAccess.open(bad_path, FileAccess.WRITE)
	if damaged != null:
		damaged.store_string("{damaged again")
		damaged.close()
	var backup_still_valid: bool = _session.load_game(_session.save_slot)
	_write("server.json", {"state": _park.snapshot(), "save_twice": saved_twice, "backup_recovered": recovered, "same_after_recovery": same_after_recovery, "saved_after_recovery": saved_after_recovery, "backup_still_valid": backup_still_valid, "policy_after_recovery": _session.spending_limit})
	quit(0)


func _run_client() -> void:
	if not await _wait_join(16.0):
		_fail("Client %d did not join: %s" % [_index, _session.last_status])
		return
	while _session.players.size() < 4:
		if Time.get_ticks_msec() - _started_at > 20000:
			_fail("Four-player roster was not received.")
			return
		await create_timer(0.025).timeout
	while Time.get_unix_time_from_system() < _action_at:
		await create_timer(0.01).timeout
	# Four simultaneous purchases of one tile, followed by distinct purchases
	# with no remaining funds. Exactly one tree may be added.
	_session.command("place", {"kind": "tree", "x": 12, "z": 3, "rotation": 0})
	await create_timer(0.7).timeout
	_session.command("place", {"kind": "tree", "x": 12 + _index, "z": 5, "rotation": 0})
	if _index == 0:
		await create_timer(0.25).timeout
		_session._request_command.rpc_id(1, "place", {"kind": "tree", "x": 12, "z": 3, "rotation": 0}, 2, _session._session_id)
		_session._request_command.rpc_id(1, "new_game", {}, 3, _session._session_id)
		_session._request_command.rpc_id(1, "place", {"kind": "tree", "x": NAN, "z": 5}, 4, _session._session_id)
		_session._command_sequence = 4
		_session.command("road_path", {"points": [{"x": 0, "z": 18}, {"x": 1, "z": 18}]})
		_session._request_command.rpc_id(1, "road_path", {"points": [{"x": INF, "z": 18}]}, 6, _session._session_id)
		_session._command_sequence = 6
		_session.command("rename", {"name": "Invalid" + String.chr(27) + "Park"})
	await create_timer(1.0).timeout
	var client_save_denied: bool = not _session.save_game("must_not_exist")
	_write("client_%d.json" % _index, {"state": _park.snapshot(), "results": _results, "players": _session.players.size(), "roster": _session.players, "client_save_denied": client_save_denied, "peer_id": _session.multiplayer.get_unique_id(), "manager_id": _session.manager_id})
	while not FileAccess.file_exists(_directory.path_join("stop")):
		if not _approval_phase_done and FileAccess.file_exists(_directory.path_join("begin_approvals")):
			await _run_approval_phase()
			_approval_phase_done = true
		if FileAccess.file_exists(_directory.path_join("release_client_%d" % _index)):
			_session.disconnect_game()
			quit(0)
			return
		if Time.get_ticks_msec() - _started_at > 50000:
			_fail("Client fixture timed out waiting for completion.")
			return
		await create_timer(0.05).timeout
	quit(0)


func _run_approval_phase() -> void:
	while not FileAccess.file_exists(_directory.path_join("approval_funded.json")):
		await create_timer(0.025).timeout
	await create_timer(0.3).timeout
	if _session.is_manager():
		_session.set_spending_limit(10.0)
	while _session.spending_limit != 10.0:
		await create_timer(0.025).timeout
	var my_peer: int = _session.multiplayer.get_unique_id()
	if _session.is_manager():
		while _session.pending_requests.size() < 3:
			await create_timer(0.025).timeout
		# Leave a window for non-managers' attempted self-approval and policy
		# changes. Neither may alter the queued intentions or the treasury.
		await create_timer(0.5).timeout
		_write("approval_queue.json", {"state": _park.snapshot(), "pending": _session.pending_requests.duplicate(true), "limit": _session.spending_limit})
		var requests: Array = _session.pending_requests.duplicate(true)
		for request: Dictionary in requests:
			_session.approve_request(int(request.id), true)
		_session.approve_request(int(requests[0].id), true)
		while not _session.pending_requests.is_empty():
			await create_timer(0.025).timeout
	else:
		_session.set_spending_limit(999999.0)
		_session.command("place", {"kind": "tree", "x": 12 + _index, "z": 7, "rotation": 0})
		var own_request: int = -1
		while own_request < 0:
			for request: Dictionary in _session.pending_requests:
				if int(request.peer) == my_peer:
					own_request = int(request.id)
			await create_timer(0.025).timeout
		_session.approve_request(own_request, true)
		while not _session.pending_requests.is_empty():
			await create_timer(0.025).timeout
	await create_timer(0.35).timeout
	_write("approval_client_%d.json" % _index, {"state": _park.snapshot(), "results": _results, "limit": _session.spending_limit, "pending": _session.pending_requests.size(), "manager_id": _session.manager_id, "peer_id": my_peer, "was_manager": _session.is_manager()})


func _run_observer() -> void:
	if not await _wait_join(10.0):
		_fail("Rejoining client did not receive a park snapshot.")
		return
	await create_timer(0.3).timeout
	_write("rejoined.json", {"state": _park.snapshot(), "players": _session.players.size(), "manager_id": _session.manager_id, "is_manager": _session.is_manager(), "limit": _session.spending_limit})
	if not await _wait_file("begin_resilience", 12.0):
		return
	var authoritative_snapshot: Dictionary = _park.snapshot()
	var my_peer: int = _session.multiplayer.get_unique_id()
	for amount: int in [1000, 2000, 3000, 4000, 5000]:
		_session.command("loan", {"amount": amount})
	await create_timer(0.6).timeout
	_write("observer_pending.json", {"peer_id": my_peer, "pending": _session.pending_requests.size(), "state": _park.snapshot(), "results": _results})
	while not _session.pending_requests.is_empty():
		await create_timer(0.025).timeout
	for amount: int in [6000, 7000]:
		_session.command("loan", {"amount": amount})
	await create_timer(0.4).timeout
	_write("observer_after_expiry.json", {"pending": _session.pending_requests.size(), "state": _park.snapshot(), "results": _results})
	var previous_serial: int = _session._last_snapshot_serial
	var until: int = Time.get_ticks_msec() + 10000
	while not _statuses.any(func(message: String) -> bool: return message.contains("incompatible")):
		if Time.get_ticks_msec() > until:
			_fail("Malformed authoritative snapshot was not rejected.")
			return
		await create_timer(0.025).timeout
	_write("observer_bad_snapshot.json", {"unchanged": _equivalent(_park.snapshot(), authoritative_snapshot), "serial_unchanged": _session._last_snapshot_serial == previous_serial, "connected": _session.connected})
	until = Time.get_ticks_msec() + 10000
	while _session._last_snapshot_serial <= previous_serial:
		if Time.get_ticks_msec() > until:
			_fail("Valid snapshot after a malformed snapshot was not accepted.")
			return
		await create_timer(0.025).timeout
	_write("observer_good_snapshot.json", {"unchanged": _equivalent(_park.snapshot(), authoritative_snapshot), "serial_advanced": _session._last_snapshot_serial > previous_serial})
	until = Time.get_ticks_msec() + 10000
	while _session.connected or _session.connecting:
		if Time.get_ticks_msec() > until:
			_fail("Observer was not disconnected by the server.")
			return
		await create_timer(0.025).timeout
	# A running local replica would expose any accidental authority promotion,
	# even though the real server is paused for deterministic test comparisons.
	_park.state.speed = 4
	var frozen: Dictionary = _park.snapshot()
	_session.save_directory = _directory.path_join("frozen_replica_must_not_save")
	_session._autosave_enabled = true
	_session._autosave_clock = 31.0
	_session._process(31.0)
	_session.command("rename", {"name": "Disconnected client mutation"})
	var denied_save: bool = not _session.save_game("must_not_exist")
	var denied_load: bool = not _session.load_game("must_not_exist")
	_session.new_game()
	await create_timer(0.35).timeout
	_write("observer_disconnected.json", {"unchanged": _equivalent(_park.snapshot(), frozen), "mode": _session.mode, "authority": _session.is_authority(), "denied_save": denied_save, "denied_load": denied_load, "autosave_absent": not DirAccess.dir_exists_absolute(_session.save_directory)})
	var port: int = _session.server_port
	_session.access_code = "incorrect-code"
	_session.join_game("127.0.0.1", port)
	until = Time.get_ticks_msec() + 10000
	while _session.connecting:
		if Time.get_ticks_msec() > until:
			_fail("Failed-code retry did not finish.")
			return
		await create_timer(0.025).timeout
	_write("observer_failed_retry.json", {"unchanged": _equivalent(_park.snapshot(), frozen), "mode": _session.mode, "authority": _session.is_authority(), "connected": _session.connected})
	_session.access_code = "coop-test"
	_session.join_game("127.0.0.1", port)
	if not await _wait_join(10.0):
		_fail("Valid retry after a failed-code attempt did not reconnect.")
		return
	_write("resilience_complete.json", {"state": _park.snapshot(), "restored_authority_state": _equivalent(_park.snapshot(), authoritative_snapshot), "players": _session.players.size()})
	while not FileAccess.file_exists(_directory.path_join("stop")):
		await create_timer(0.05).timeout
	quit(0)


func _run_overflow() -> void:
	var joined: bool = await _wait_join(5.0)
	_write("overflow.json", {"joined": joined, "status": _session.last_status})
	quit(1 if joined else 0)


func _wait_join(seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if _session.mode == "client" and _session.connected and _session._joined:
			return true
		await create_timer(0.025).timeout
	return false


func _wait_file(filename: String, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not FileAccess.file_exists(_directory.path_join(filename)):
		if Time.get_ticks_msec() > until:
			_fail("Timed out waiting for " + filename)
			return false
		await create_timer(0.025).timeout
	return true


func _equivalent(a: Dictionary, b: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _write(filename: String, data: Dictionary) -> void:
	var path: String = _directory.path_join(filename)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Unable to write network test result: " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


func _fail(message: String) -> void:
	_write("failure_%s_%d.json" % [_role, _index], {"error": message})
	push_error(message)
	quit(1)
