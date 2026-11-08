extends SceneTree

var failures: int = 0
var checks: int = 0
var selected_tool: String = ""
var selected_overlay: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session: Node = root.get_node("Session")
	var simulation: Node = root.get_node("Park")
	simulation.reset(451)
	session.command("speed", {"value":0})
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var hud: Node = main.get_node("ParkHUD")
	hud.tool_selected.connect(func(kind: String): selected_tool = kind)
	hud.overlay_selected.connect(func(mode: String): selected_overlay = mode)
	_check(hud.blocks_world_input(Vector2(640, 350)), "Welcome modal blocks world input")
	await _click(hud, "Continue to the park")
	_check(not hud.blocks_world_input(Vector2(640, 350)), "Dismissed welcome allows map input")
	_check(hud.blocks_world_input(Vector2(640, 25)), "Top toolbar blocks map input")
	_check(hud.blocks_world_input(Vector2(640, 780)), "Construction bar blocks map input")
	await _click(hud, "Roads")
	await _click(hud, "Gravel road", true)
	_check(selected_tool == "road", "Road catalog selects construction tool")
	await _click(hud, "Utilities")
	await _click(hud, "Water tower", true)
	_check(selected_tool == "water", "Utility category exposes water construction")
	await _click(hud, "Manage", true)
	var rent_input: SpinBox = _find_spin(hud)
	_check(rent_input != null, "Finance panel exposes rent field")
	if rent_input != null:
		rent_input.value = 140
		await _click(hud, "Set rent")
		_check(float(simulation.state.rent) == 140.0, "Rent button sends management command")
	await _click(hud.get("_management"), "Services")
	await _click(hud.get("_management"), "View network")
	_check(selected_overlay == "power", "Service overlay button connects to world signal")
	await _click(hud, "Growth")
	var cash_before: float = float(simulation.state.cash)
	await _click(hud, "Parcel 2", true)
	_check(simulation.state.owned.has(1), "Land button purchases the selected parcel")
	_check(float(simulation.state.cash) == cash_before - float(simulation.PARCEL_COST), "Land purchase debits shared funds exactly once")
	await _click(hud, "Households")
	await _click(hud.get("_management"), "Inspect")
	_check(hud.selected_building_id > 0, "Household inspect stores selected building")
	await _click(hud, "Relocate")
	_check(selected_tool == "move", "Inspector exposes functional relocation tool")
	await _click(hud, "Solo · Menu")
	await _click(hud, "Join")
	_check(_find_button(hud, "Join park") != null, "Join flow exposes connection form")
	var line_edits: Array[LineEdit] = []
	_find_fields(hud, line_edits)
	_check(line_edits.size() >= 3, "Join form has name, address and access code fields")
	await _click(hud.get("_modal_shade"), "Close")
	_check(not hud.blocks_world_input(Vector2(640,350)), "Session menu dismisses back to park")
	print("UI_SMOKE_RESULT ", checks, " checks; ", failures, " failures")
	main.queue_free()
	await process_frame
	await create_timer(4.4).timeout
	quit(1 if failures > 0 else 0)

func _click(parent: Node, caption: String, prefix: bool = false) -> void:
	var button: Button = _find_button(parent, caption, prefix)
	_check(button != null, "Button available: " + caption)
	if button != null:
		button.pressed.emit()
	await process_frame
	await process_frame

func _find_button(parent: Node, caption: String, prefix: bool = false) -> Button:
	if parent is Button:
		var button: Button = parent
		if button.is_visible_in_tree() and (button.text.begins_with(caption) if prefix else button.text == caption):
			return button
	for child in parent.get_children():
		var found: Button = _find_button(child, caption, prefix)
		if found != null:
			return found
	return null

func _find_spin(parent: Node) -> SpinBox:
	if parent is SpinBox and parent.is_visible_in_tree():
		return parent
	for child in parent.get_children():
		var found: SpinBox = _find_spin(child)
		if found != null:
			return found
	return null

func _find_fields(parent: Node, output: Array[LineEdit]) -> void:
	if parent is LineEdit and parent.is_visible_in_tree():
		output.append(parent)
	for child in parent.get_children():
		_find_fields(child, output)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
