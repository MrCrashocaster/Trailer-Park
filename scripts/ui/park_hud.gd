class_name ParkHUD
extends CanvasLayer

signal tool_selected(kind: String)
signal rotation_requested()
signal overlay_selected(mode: String)
signal camera_requested(action: String)
signal new_park_requested()
signal inspect_requested(id: int)

var selected_building_id: int = -1

const UI := preload("res://scripts/ui/ui_theme.gd")
const CATEGORIES := ["All", "Roads", "Homes", "Utilities", "Services", "Business", "Grounds"]
const TOOLTIPS := {
	"road": "Connect lots and facilities to the park entrance.",
	"trailer": "A furnished home. Needs road access, power, water and sewage service.",
	"power": "Supplies electricity to buildings on the connected road network.",
	"water": "Supplies clean water. Expand capacity as your park grows.",
	"sewage": "Treats sewage from occupied homes.",
	"trash": "Provides trash collection to nearby households.",
	"maintenance": "Helps keep the park's buildings and services in good condition.",
	"laundry": "A useful service and an additional source of income.",
	"store": "A neighborhood shop for the everyday essentials.",
	"office": "The park's office and management hub.",
	"lamp": "A little light makes a gravel lane feel like home.",
	"tree": "Add shade and soften the edges of your park.",
	"fence": "Mark out a yard or give the neighbors something to argue over."
}

var _canvas: Control
var _top: PanelContainer
var _bottom: PanelContainer
var _inspector: PanelContainer
var _inspector_body: VBoxContainer
var _management: PanelContainer
var _management_body: VBoxContainer
var _management_title: Label
var _modal_shade: ColorRect
var _modal_card: PanelContainer
var _modal_body: VBoxContainer
var _modal_scroll: ScrollContainer
var _toast_panel: PanelContainer
var _toast_label: Label
var _placement_label: Label
var _clock_label: Label
var _cash_label: Label
var _people_label: Label
var _happy_label: Label
var _park_label: Label
var _session_button: Button
var _catalog: HBoxContainer
var _search: LineEdit
var _category_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _overlay_option: OptionButton
var _camera_panel: PanelContainer
var _selection: Dictionary = {}
var _active_tool: String = "select"
var _category: String = "All"
var _management_tab: String = "finance"
var _management_metric_labels: Dictionary = {}
var _service_bars: Dictionary = {}
var _session_status: Label
var _sound_player: AudioStreamPlayer
var _sound_on: bool = true
var _toast_version: int = 0
var _refresh_elapsed: float = 0.0
var _last_day: int = -1
var _last_event_hash: int = 0
var _top_buttons: HBoxContainer
var _manage_button: Button
var _portrait_warning: Label
var _stats_row: HBoxContainer


func _ready() -> void:
	layer = 20
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UI.make_theme()
	add_child(_canvas)
	_build_sound()
	_build_top()
	_build_bottom()
	_build_inspector()
	_build_management()
	_build_camera()
	_build_toast()
	_build_modal()
	_portrait_warning = _label("Rotate your device for the best park view", 16, Color.WHITE)
	_portrait_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_portrait_warning.position = Vector2(-220, 92)
	_portrait_warning.size = Vector2(440, 30)
	_portrait_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_portrait_warning)
	Park.changed.connect(_on_state_changed)
	Session.command_result.connect(show_toast)
	Session.status_changed.connect(_on_session_status)
	Session.peers_changed.connect(_refresh_top)
	if Session.has_signal("approvals_changed"):
		Session.connect("approvals_changed", _on_approvals_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_top()
	if not OS.get_cmdline_user_args().has("--skip-welcome"):
		_show_welcome()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui="):
			_close_modal()
			_open_management(argument.trim_prefix("--ui="))


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0.0
		_refresh_top()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _modal_shade.visible:
			_close_modal()
		elif _management.visible:
			_management.hide()
		else:
			_choose_tool("select")
		get_viewport().set_input_as_handled()


func _build_top() -> void:
	_top = _panel(_canvas, UI.PAPER, 0, 12)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 78
	_top.add_theme_stylebox_override("panel", UI.box(UI.PAPER, 0, Color.TRANSPARENT, 12))
	var row := _hbox(_top, 16)
	var brand := _vbox(row, 0)
	brand.custom_minimum_size.x = 180
	_park_label = _label("TRAILER PARK", 21, UI.INK)
	_park_label.clip_text = true
	_park_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brand.add_child(_park_label)
	var tagline := _label("A LITTLE LAND. A LOT OF PROBLEMS.", 9, UI.MUTED)
	tagline.clip_text = true
	tagline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brand.add_child(tagline)
	_stats_row = _hbox(row, 18)
	_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash_label = _stat(_stats_row, "PARK FUNDS", "$0")
	_people_label = _stat(_stats_row, "HOMES", "0 / 0")
	_happy_label = _stat(_stats_row, "SATISFACTION", "—")
	var clock := _vbox(row, 1)
	_clock_label = _label("DAY 01 · 08:00", 13, UI.INK)
	clock.add_child(_clock_label)
	var speeds := _hbox(clock, 4)
	for speed_value in [0, 1, 2, 4]:
		var value: int = speed_value
		var caption: String = "Ⅱ" if value == 0 else "%d×" % value
		var button := _button(caption, func(): Session.command("speed", {"value": value}), "QuietButton")
		button.custom_minimum_size = Vector2(36, 27)
		button.add_theme_font_size_override("font_size", 13)
		button.tooltip_text = "Pause simulation" if value == 0 else "Simulation speed: %d×" % value
		speeds.add_child(button)
	_top_buttons = _hbox(row, 6)
	_manage_button = _button("Manage", func(): _open_management("finance"), "PrimaryButton")
	_top_buttons.add_child(_manage_button)
	_session_button = _button("Solo · Menu", _show_session, "Button")
	_top_buttons.add_child(_session_button)


func _build_bottom() -> void:
	_bottom = _panel(_canvas, UI.PAPER, 0, 12)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -166
	_bottom.add_theme_stylebox_override("panel", UI.box(UI.PAPER, 0, Color.TRANSPARENT, 12))
	var column := _vbox(_bottom, 8)
	var toolbar := _hbox(column, 7)
	for tool in ["select", "demolish"]:
		var kind: String = tool
		var caption: String = "Inspect" if kind == "select" else "Demolish"
		var button := _button(caption, func(): _choose_tool(kind))
		button.custom_minimum_size = Vector2(78, 35)
		button.add_theme_font_size_override("font_size", 13)
		toolbar.add_child(button)
		_tool_buttons[kind] = button
	var divider := VSeparator.new()
	toolbar.add_child(divider)
	for category_value in CATEGORIES:
		var category: String = category_value
		var button := _button(category, func(): _set_category(category), "QuietButton")
		button.custom_minimum_size = Vector2(58, 35)
		button.add_theme_font_size_override("font_size", 13)
		toolbar.add_child(button)
		_category_buttons[category] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_search = LineEdit.new()
	_search.placeholder_text = "Find a building…"
	_search.custom_minimum_size = Vector2(160, 35)
	_search.add_theme_font_size_override("font_size", 13)
	_search.text_changed.connect(func(_value: String): _refresh_catalog())
	toolbar.add_child(_search)
	var rotate := _button("Rotate ↻", func(): rotation_requested.emit(), "Button")
	rotate.add_theme_font_size_override("font_size", 13)
	rotate.custom_minimum_size.y = 35
	rotate.tooltip_text = "Rotate the placement preview. Keyboard: R."
	toolbar.add_child(rotate)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 72
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_catalog = _hbox(scroll, 8)
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placement_label = _label("Inspect a lot, or choose something to build. Drag to pan · Pinch / scroll to zoom", 12, UI.MUTED)
	_placement_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_placement_label)
	_refresh_catalog()
	_set_category("All")
	set_active_tool("select")


func _build_inspector() -> void:
	_inspector = _panel(_canvas, UI.CARD, 12, 16)
	_inspector.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_inspector.offset_left = -330
	_inspector.offset_right = -16
	_inspector.offset_top = 94
	_inspector.offset_bottom = 550
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.add_child(scroll)
	_inspector_body = _vbox(scroll, 10)
	_inspector_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.hide()


func _build_management() -> void:
	_management = _panel(_canvas, UI.PAPER, 12, 16)
	_management.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_management.position = Vector2(16, 94)
	_management.size = Vector2(610, 470)
	var column := _vbox(_management, 12)
	var heading := _hbox(column, 8)
	_management_title = _label("PARK MANAGEMENT", 18, UI.INK)
	_management_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_management_title)
	heading.add_child(_button("Close", func(): _management.hide(), "QuietButton"))
	var tabs := _hbox(column, 5)
	for entry in [["finance", "Money"], ["services", "Services"], ["households", "Households"], ["events", "Problems"], ["goals", "Growth"]]:
		var key: String = entry[0]
		var button := _button(entry[1], func(): _open_management(key), "QuietButton")
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size.y = 38
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_management_body = _vbox(scroll, 11)
	_management_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_management.hide()


func _build_camera() -> void:
	_camera_panel = _panel(_canvas, Color("f5f1e6e8"), 9, 5)
	_camera_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_camera_panel.offset_left = -268
	_camera_panel.offset_right = -16
	_camera_panel.offset_top = -220
	_camera_panel.offset_bottom = -178
	var row := _hbox(_camera_panel, 3)
	for entry in [["rotate_left", "↶"], ["rotate_right", "↷"], ["zoom_out", "−"], ["zoom_in", "+"], ["home", "Home"]]:
		var action: String = entry[0]
		var button := _button(entry[1], func(): camera_requested.emit(action), "QuietButton")
		button.custom_minimum_size = Vector2(36, 32)
		button.tooltip_text = action.replace("_", " ").capitalize()
		row.add_child(button)
	_overlay_option = OptionButton.new()
	_overlay_option.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_overlay_option.offset_left = 16
	_overlay_option.offset_right = 208
	_overlay_option.offset_top = -220
	_overlay_option.offset_bottom = -178
	for caption in ["View: Natural", "View: Power", "View: Water", "View: Sewage", "View: Satisfaction", "View: Condition", "View: Land parcels"]:
		_overlay_option.add_item(caption)
	_overlay_option.item_selected.connect(func(index: int):
		var modes: Array[String] = ["normal", "power", "water", "sewage", "happiness", "condition", "land"]
		overlay_selected.emit(modes[index])
	)
	_canvas.add_child(_overlay_option)


func _build_toast() -> void:
	_toast_panel = _panel(_canvas, UI.DARK, 8, 13)
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.position = Vector2(-250, 92)
	_toast_panel.custom_minimum_size = Vector2(500, 46)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _label("", 15, Color.WHITE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 470
	_toast_panel.add_child(_toast_label)
	_toast_panel.hide()


func _build_modal() -> void:
	_modal_shade = ColorRect.new()
	_modal_shade.color = Color(0.07, 0.12, 0.10, 0.76)
	_modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_modal_shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_shade.add_child(center)
	_modal_card = _panel(center, UI.PAPER, 16, 26)
	_modal_card.custom_minimum_size = Vector2(540, 0)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_card.add_child(_modal_scroll)
	_modal_body = _vbox(_modal_scroll, 13)
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_shade.hide()


func _build_sound() -> void:
	_sound_player = AudioStreamPlayer.new()
	_sound_player.volume_db = -20.0
	add_child(_sound_player)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var count: int = 1100
	samples.resize(count * 2)
	for index in range(count):
		var fraction: float = float(index) / float(count)
		var value: float = sin(float(index) * TAU * 720.0 / 22050.0) * exp(-fraction * 8.0) * 0.3
		samples.encode_s16(index * 2, int(value * 32767.0))
	stream.data = samples
	_sound_player.stream = stream


func _ping() -> void:
	if _sound_on and is_instance_valid(_sound_player):
		_sound_player.play()


func _layout() -> void:
	if not is_instance_valid(_canvas):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var insets: Vector4 = _safe_insets(viewport_size)
	_canvas.offset_left = insets.x
	_canvas.offset_top = insets.y
	_canvas.offset_right = -insets.z
	_canvas.offset_bottom = -insets.w
	var width: float = viewport_size.x - insets.x - insets.z
	var height: float = viewport_size.y - insets.y - insets.w
	_management.size = Vector2(minf(610.0, width - 32.0), maxf(230.0, height - 270.0))
	_inspector.offset_bottom = maxf(245.0, height - 238.0)
	_modal_card.custom_minimum_size.x = minf(540.0, width - 32.0)
	_modal_scroll.custom_minimum_size.y = minf(520.0, maxf(240.0, height - 108.0))
	_search.visible = width >= 1160.0
	_happy_label.get_parent().visible = width >= 1100.0
	_portrait_warning.visible = height > width
	if width < 1000.0:
		_park_label.add_theme_font_size_override("font_size", 17)
		_park_label.get_parent().custom_minimum_size.x = 145
	else:
		_park_label.add_theme_font_size_override("font_size", 21)
		_park_label.get_parent().custom_minimum_size.x = 180


func _safe_insets(viewport_size: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	# Some platform window modes already exclude system bars. Avoid padding twice.
	if window_size.x <= safe.size.x + 2 and window_size.y <= safe.size.y + 2:
		return Vector4.ZERO
	var scale_x: float = viewport_size.x / float(screen_size.x)
	var scale_y: float = viewport_size.y / float(screen_size.y)
	return Vector4(maxf(0.0, float(safe.position.x) * scale_x), maxf(0.0, float(safe.position.y) * scale_y), maxf(0.0, float(screen_size.x - safe.end.x) * scale_x), maxf(0.0, float(screen_size.y - safe.end.y) * scale_y))


func _refresh_catalog() -> void:
	_clear(_catalog)
	var kinds: Array[String] = ["road", "trailer", "power", "water", "sewage", "trash", "maintenance", "laundry", "store", "office", "lamp", "tree", "fence"]
	var search_value: String = _search.text.strip_edges().to_lower() if is_instance_valid(_search) else ""
	for kind_value in kinds:
		var kind: String = kind_value
		if not Park.CATALOG.has(kind):
			continue
		var item: Dictionary = Park.CATALOG[kind]
		var title: String = str(item.get("name", kind.capitalize()))
		if _category != "All" and _kind_category(kind) != _category:
			continue
		if not search_value.is_empty() and not title.to_lower().contains(search_value):
			continue
		var button := _button("%s\n%s" % [title, _money(float(item.get("cost", 0)))], func(): _choose_tool(kind), "ActiveButton" if _active_tool == kind else "Button")
		button.custom_minimum_size = Vector2(126, 66)
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = str(TOOLTIPS.get(kind, "")) + "\nUpkeep: %s / day" % _money(float(item.get("upkeep", 0)))
		_catalog.add_child(button)
	if _catalog.get_child_count() == 0:
		_catalog.add_child(_label("No matching buildings. Try another category.", 14, UI.MUTED))


func _kind_category(kind: String) -> String:
	if kind == "road":
		return "Roads"
	if kind == "trailer":
		return "Homes"
	if kind in ["power", "water", "sewage"]:
		return "Utilities"
	if kind in ["trash", "maintenance", "office"]:
		return "Services"
	if kind in ["laundry", "store"]:
		return "Business"
	return "Grounds"


func _set_category(category: String) -> void:
	_category = category
	for key in _category_buttons:
		var button: Button = _category_buttons[key]
		button.theme_type_variation = "ActiveButton" if key == category else "QuietButton"
	_refresh_catalog()


func _choose_tool(kind: String) -> void:
	set_active_tool(kind)
	tool_selected.emit(kind)
	if kind != "select":
		_management.hide()
		_inspector.hide()


func set_active_tool(kind: String) -> void:
	_active_tool = kind
	for key in _tool_buttons:
		var button: Button = _tool_buttons[key]
		button.theme_type_variation = "ActiveButton" if key == kind else "Button"
	_refresh_catalog()
	if kind == "select":
		set_placement_status("Inspect a lot, or choose something to build. Drag to pan · Pinch / scroll to zoom", true)
	elif kind == "demolish":
		set_placement_status("Demolish: tap an eligible building or road. Occupied homes and essential access are protected.", false)
	elif kind == "move":
		set_placement_status("Relocate: choose a new position. Rotate with R or the Rotate button.", true)
	elif Park.CATALOG.has(kind):
		var item: Dictionary = Park.CATALOG[kind]
		set_placement_status("%s · %s · Tap the ground to place. Rotate with R." % [str(item.get("name", kind)), _money(float(item.get("cost", 0)))], true)


func set_placement_status(message: String, valid: bool) -> void:
	if not is_instance_valid(_placement_label):
		return
	_placement_label.text = message
	_placement_label.add_theme_color_override("font_color", UI.MUTED if valid else UI.ORANGE)


func set_selection(building: Dictionary) -> void:
	_selection = building.duplicate(true)
	selected_building_id = int(building.get("id", -1))
	_refresh_inspector()


func _refresh_inspector() -> void:
	_clear(_inspector_body)
	if _selection.is_empty():
		_inspector.hide()
		return
	_inspector.show()
	var kind: String = str(_selection.get("kind", "trailer"))
	var item: Dictionary = Park.CATALOG.get(kind, {})
	var heading := _hbox(_inspector_body, 5)
	var title := _label(str(item.get("name", kind.capitalize())), 20, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("×", func(): _inspector.hide(), "QuietButton"))
	var id: int = int(_selection.get("id", -1))
	_inspector_body.add_child(_label("LOT %02d  ·  LEVEL %d" % [id, int(_selection.get("level", 1))], 11, UI.MUTED))
	var occupied: bool = bool(_selection.get("occupied", false))
	if kind == "trailer":
		_inspector_body.add_child(_label(str(_selection.get("household", "Vacant home")) if occupied else "Available for a new household", 16, UI.MOSS))
		if occupied:
			_meter(_inspector_body, "Satisfaction", float(_selection.get("happiness", 0.0)), 100.0)
			var effective_rent: float = float(Park.state.get("rent", 0)) * (1.0 + float(int(_selection.get("level", 1)) - 1) * 0.12)
			_row(_inspector_body, "Rent", "%s / day" % _money(effective_rent))
			_row(_inspector_body, "Arrears", _money(float(_selection.get("arrears", 0.0))))
	_meter(_inspector_body, "Condition", float(_selection.get("condition", 100.0)), 100.0)
	_row(_inspector_body, "Road access", "Connected" if bool(_selection.get("connected", false)) else "No entrance connection")
	var services: Dictionary = _selection.get("services", {})
	if kind == "trailer":
		for service_name in ["power", "water", "sewage", "trash"]:
			var supplied: bool = bool(services.get(service_name, false))
			_row(_inspector_body, str(service_name).capitalize(), "Available" if supplied else "Missing / at capacity")
	_inspector_body.add_child(HSeparator.new())
	var condition: float = float(_selection.get("condition", 100.0))
	if condition < 99.5:
		_inspector_body.add_child(_button("Arrange repairs · " + _money(Park.repair_cost(_selection)), func(): Session.command("repair", {"id": id}), "PrimaryButton"))
	if int(_selection.get("level", 1)) < 3:
		_inspector_body.add_child(_button("Upgrade · " + _money(Park.upgrade_cost(_selection)), func(): Session.command("upgrade", {"id": id})))
	var actions := _hbox(_inspector_body, 6)
	actions.add_child(_button("Relocate", func(): _choose_tool("move")))
	actions.add_child(_button("Demolish", func():
		_confirm("Remove this building?", "The server will check occupants, road access and other dependencies before demolition.", "Demolish", func(): Session.command("demolish", {"id": id}))
	, "DangerButton"))
	_inspector_body.add_child(_paragraph(str(TOOLTIPS.get(kind, "")), 12, UI.MUTED))


func _open_management(tab: String) -> void:
	_management_tab = tab
	_management.show()
	_inspector.hide()
	_refresh_management()


func _refresh_management() -> void:
	_clear(_management_body)
	_management_metric_labels.clear()
	_service_bars.clear()
	match _management_tab:
		"finance": _build_finance()
		"services": _build_services()
		"households": _build_households()
		"events": _build_events()
		"goals": _build_goals()
	_refresh_management_values()


func _build_finance() -> void:
	_management_title.text = "MAKE THE NUMBERS WORK"
	var cards := _hbox(_management_body, 9)
	for entry in [["income", "RENT & BUSINESS / DAY"], ["expenses", "RUNNING COSTS / DAY"], ["profit", "NET CASH FLOW / DAY"]]:
		var card := _panel(cards, UI.CARD, 8, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := _vbox(card, 3)
		column.add_child(_label(entry[1], 9, UI.MUTED))
		var value := _label("—", 21, UI.INK)
		column.add_child(value)
		_management_metric_labels[entry[0]] = value
	_management_body.add_child(_paragraph("Rent funds the park. High charges can cover bills today and leave you with empty homes tomorrow.", 14, UI.MUTED))
	var rent_row := _hbox(_management_body, 9)
	rent_row.add_child(_label("Daily lot rent", 15, UI.INK))
	var rent := SpinBox.new()
	rent.min_value = 25
	rent.max_value = 350
	rent.step = 5
	rent.value = float(Park.state.get("rent", 65))
	rent.custom_minimum_size = Vector2(125, 42)
	rent.prefix = "$"
	rent_row.add_child(rent)
	rent_row.add_child(_button("Set rent", func(): Session.command("set_rent", {"value": int(rent.value)}), "PrimaryButton"))
	var debt_row := _hbox(_management_body, 8)
	var debt_value := _label("", 15, UI.INK)
	debt_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debt_row.add_child(debt_value)
	_management_metric_labels["debt"] = debt_value
	debt_row.add_child(_button("Borrow $10,000", func(): Session.command("loan", {"amount": 10000})))
	debt_row.add_child(_button("Repay $5,000", func(): Session.command("repay", {"amount": 5000})))
	_management_body.add_child(HSeparator.new())
	_management_body.add_child(_label("RECENT TRANSACTIONS", 11, UI.MUTED))
	var ledger: Array = Park.state.get("ledger", [])
	if ledger.is_empty():
		_management_body.add_child(_label("No transactions yet. Your first expansion starts here.", 13, UI.MUTED))
	else:
		for index in range(mini(8, ledger.size())):
			var entry: Dictionary = ledger[index]
			var description: String = str(entry.get("text", entry.get("description", "Park transaction")))
			_row(_management_body, description, _money(float(entry.get("amount", 0))), 13)


func _build_services() -> void:
	_management_title.text = "KEEP THE PARK RUNNING"
	_management_body.add_child(_paragraph("Buildings need a road connection back to the entrance. Connected utility facilities supply the network up to their working capacity.", 14, UI.MUTED))
	for kind_value in ["power", "water", "sewage"]:
		var kind: String = kind_value
		var card := _panel(_management_body, UI.CARD, 8, 12)
		var column := _vbox(card, 7)
		var row := _hbox(column, 8)
		var title := _label(kind.capitalize(), 16, UI.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		row.add_child(_button("View network", func():
			overlay_selected.emit(kind)
			_overlay_option.select(["normal", "power", "water", "sewage"].find(kind))
		, "QuietButton"))
		row.add_child(_button("Build", func(): _choose_tool(kind), "PrimaryButton"))
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 16
		bar.show_percentage = false
		column.add_child(bar)
		var capacity := _label("", 12, UI.MUTED)
		column.add_child(capacity)
		_service_bars[kind] = {"bar": bar, "label": capacity}
	for entry in [["trash_coverage", "Trash coverage"], ["maintenance_coverage", "Maintenance coverage"]]:
		var value := _label("", 14, UI.INK)
		_management_body.add_child(value)
		_management_metric_labels[entry[0]] = value
	var actions := _hbox(_management_body, 7)
	actions.add_child(_button("Build trash depot", func(): _choose_tool("trash")))
	actions.add_child(_button("Build maintenance shed", func(): _choose_tool("maintenance")))


func _build_households() -> void:
	_management_title.text = "PEOPLE MAKE A PARK"
	_management_body.add_child(_paragraph("Affordable rent, working services and maintained homes attract households. Unhappy residents can stop paying or move out.", 14, UI.MUTED))
	var count: int = 0
	for raw_building in Park.state.get("buildings", []):
		var building: Dictionary = raw_building
		if str(building.get("kind", "")) != "trailer":
			continue
		count += 1
		var id: int = int(building.get("id", 0))
		var card := _panel(_management_body, UI.CARD, 7, 10)
		var row := _hbox(card, 8)
		var column := _vbox(row, 2)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var occupied: bool = bool(building.get("occupied", false))
		column.add_child(_label("Lot %02d · %s" % [id, str(building.get("household", "Household")) if occupied else "Vacant"], 14, UI.INK))
		column.add_child(_label("Condition %d%% · %s" % [int(building.get("condition", 100)), "Satisfaction %d%%" % int(building.get("happiness", 0)) if occupied else "Waiting for a household"], 12, UI.MUTED))
		row.add_child(_button("Inspect", func():
			_management.hide()
			set_selection(building)
			inspect_requested.emit(id)
		, "QuietButton"))
	if count == 0:
		_management_body.add_child(_label("No homes yet. Build a trailer on a serviced lot.", 14, UI.MUTED))


func _build_events() -> void:
	_management_title.text = "THE COMPLAINT BOX"
	_build_approval_cards()
	var events: Array = Park.state.get("events", [])
	if events.is_empty():
		_management_body.add_child(_label("A suspiciously quiet day.", 22, UI.MOSS))
		_management_body.add_child(_paragraph("No outstanding problems. Keep an eye on services, building condition and your cash flow as the park grows.", 15, UI.MUTED))
		return
	for raw_event in events:
		var event: Dictionary = raw_event
		var event_id: int = int(event.get("id", 0))
		var card := _panel(_management_body, UI.CARD, 9, 14)
		var column := _vbox(card, 9)
		column.add_child(_label(str(event.get("title", "A park problem")), 18, UI.ORANGE))
		column.add_child(_paragraph(str(event.get("description", "")), 14, UI.INK))
		var choices: Array = event.get("choices", [])
		for index in range(choices.size()):
			var choice_index: int = index
			var choice: Dictionary = choices[index]
			var cost: float = float(choice.get("cost", 0))
			var caption: String = str(choice.get("label", "Respond"))
			if cost > 0.0:
				caption += " · " + _money(cost)
			elif cost < 0.0:
				caption += " · receive " + _money(-cost)
			var button := _button(caption, func(): Session.command("resolve_event", {"id": event_id, "choice": choice_index}))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			column.add_child(button)


func _build_approval_cards() -> void:
	if not Session.has_method("is_manager"):
		return
	var requests: Array = Session.get("pending_requests")
	if requests.is_empty():
		return
	_management_body.add_child(_label("SHARED SPENDING REQUESTS", 12, UI.MUTED))
	for raw_request in requests:
		var request: Dictionary = raw_request
		var request_id: int = int(request.get("id", 0))
		var card := _panel(_management_body, UI.LIGHT_MOSS, 8, 12)
		var column := _vbox(card, 7)
		column.add_child(_label("%s · %s" % [str(request.get("name", "A manager")), str(request.get("action", "purchase")).replace("_", " ").capitalize()], 15, UI.INK))
		column.add_child(_label("Requested spending: " + _money(float(request.get("cost", 0))), 13, UI.MUTED))
		if bool(Session.call("is_manager")):
			var actions := _hbox(column, 7)
			actions.add_child(_button("Approve", func(): Session.call("approve_request", request_id, true), "PrimaryButton"))
			actions.add_child(_button("Reject", func(): Session.call("approve_request", request_id, false), "DangerButton"))
		else:
			column.add_child(_label("Awaiting the session manager's approval", 12, UI.MUTED))
	_management_body.add_child(HSeparator.new())


func _on_approvals_changed() -> void:
	_refresh_top()
	if _management.visible and _management_tab == "events":
		_refresh_management()


func _build_goals() -> void:
	_management_title.text = "ROOM TO GROW"
	var metrics: Dictionary = Park.metrics()
	var level: int = int(metrics.get("level", 1))
	_management_body.add_child(_label("PARK LEVEL %d" % level, 22, UI.MOSS))
	_management_body.add_child(_paragraph("A thriving park takes more than a row of trailers. Grow occupancy, keep services reliable and leave enough cash for the next surprise.", 14, UI.MUTED))
	var goals: Array = [
		["A place to settle", "House 12 households", int(metrics.get("occupied", 0)) >= 12],
		["Word gets around", "Reach 70% resident satisfaction", float(metrics.get("happiness", 0)) >= 70.0],
		["Open for business", "Build a laundromat and convenience store", _has_building("laundry") and _has_building("store")],
		["A proper neighborhood", "Develop 24 trailer lots", int(metrics.get("lots", 0)) >= 24],
		["Breathing room", "Own four land parcels", int(metrics.get("land_owned", 0)) >= 4]
	]
	for goal in goals:
		var completed: bool = bool(goal[2])
		var row := _hbox(_management_body, 8)
		row.add_child(_label("✓" if completed else "○", 20, UI.MOSS if completed else UI.MUTED))
		var column := _vbox(row, 1)
		column.add_child(_label(goal[0], 15, UI.INK))
		column.add_child(_label(goal[1], 12, UI.MUTED))
	_management_body.add_child(HSeparator.new())
	_management_body.add_child(_label("EXPAND THE PARK", 12, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	_management_body.add_child(grid)
	var owned: Array = Park.state.get("owned", [])
	for parcel_value in range(6):
		var parcel: int = parcel_value
		var is_owned: bool = owned.has(parcel)
		var button := _button("Parcel %d\n%s" % [parcel + 1, "Owned" if is_owned else _money(Park.PARCEL_COST)], func(): Session.command("buy_land", {"parcel": parcel}), "ActiveButton" if is_owned else "Button")
		button.custom_minimum_size = Vector2(165, 58)
		button.disabled = is_owned
		grid.add_child(button)
	_management_body.add_child(_paragraph("Land parcels are arranged west to east, with parcels 1–3 in the north and 4–6 in the south. Select the Land parcels overlay to see the boundaries.", 12, UI.MUTED))
	_management_body.add_child(_button("Show land boundaries", func():
		overlay_selected.emit("land")
		_overlay_option.select(6)
		_management.hide()
	, "QuietButton"))


func _has_building(kind: String) -> bool:
	for raw_building in Park.state.get("buildings", []):
		var building: Dictionary = raw_building
		if str(building.get("kind", "")) == kind:
			return true
	return false


func _refresh_management_values() -> void:
	if not is_instance_valid(_management) or not _management.visible:
		return
	var metrics: Dictionary = Park.metrics()
	for key in _management_metric_labels:
		var label: Label = _management_metric_labels[key]
		if key == "debt":
			label.text = "Outstanding debt: " + _money(float(metrics.get("debt", Park.state.get("debt", 0))))
		elif key == "trash_coverage":
			label.text = "Trash coverage: %d%%" % _percent(float(metrics.get(key, 0)))
		elif key == "maintenance_coverage":
			label.text = "Maintenance coverage: %d%%" % _percent(float(metrics.get(key, 0)))
		else:
			var value: float = float(metrics.get(key, 0))
			label.text = _money(value)
			if key == "profit":
				label.add_theme_color_override("font_color", UI.MOSS if value >= 0 else UI.ORANGE)
	for kind in _service_bars:
		var capacity: Dictionary = metrics.get(kind, {"used": 0, "capacity": 0})
		var used: float = float(capacity.get("used", 0))
		var maximum: float = float(capacity.get("capacity", 0))
		var parts: Dictionary = _service_bars[kind]
		var bar: ProgressBar = parts["bar"]
		bar.max_value = maxf(1.0, maximum)
		bar.value = used
		var label: Label = parts["label"]
		label.text = "%d used / %d available capacity" % [int(used), int(maximum)]
		bar.add_theme_stylebox_override("background", UI.box(UI.LINE, 5, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", UI.box(UI.ORANGE if used >= maximum else UI.MOSS, 5, Color.TRANSPARENT, 0))


func _on_state_changed() -> void:
	_refresh_top()
	_refresh_management_values()
	var current_day: int = int(Park.state.get("day", 1))
	var event_hash: int = hash(Park.state.get("events", []))
	if _management.visible and (current_day != _last_day or event_hash != _last_event_hash):
		if _management_tab in ["households", "events", "goals"]:
			_refresh_management()
	_last_day = current_day
	_last_event_hash = event_hash
	if not _selection.is_empty():
		var selected_id: int = int(_selection.get("id", -1))
		for raw_building in Park.state.get("buildings", []):
			var building: Dictionary = raw_building
			if int(building.get("id", -2)) == selected_id:
				_selection = building.duplicate(true)
				return
		_selection = {}
		selected_building_id = -1
		_inspector.hide()


func _refresh_top() -> void:
	if not is_instance_valid(_cash_label):
		return
	var metrics: Dictionary = Park.metrics()
	_cash_label.text = _money(float(Park.state.get("cash", 0)))
	_people_label.text = "%d / %d" % [int(metrics.get("occupied", 0)), int(metrics.get("lots", 0))]
	_happy_label.text = "%d%%" % int(round(float(metrics.get("happiness", 0))))
	_cash_label.add_theme_color_override("font_color", UI.ORANGE if float(Park.state.get("cash", 0)) < 0 else UI.INK)
	var progress: float = float(Park.state.get("day_progress", 0))
	var hour: int = (8 + int(progress * 24.0)) % 24
	var minute: int = int(progress * 24.0 * 60.0) % 60
	var speed: int = int(Park.state.get("speed", 1))
	_clock_label.text = "DAY %02d · %02d:%02d%s" % [int(Park.state.get("day", 1)), hour, minute, " · PAUSED" if speed == 0 else ""]
	var mode: String = str(Session.mode)
	var event_count: int = Park.state.get("events", []).size()
	if Session.has_method("is_manager"):
		var requests: Array = Session.get("pending_requests")
		event_count += requests.size()
	_manage_button.text = "Manage · %d" % event_count if event_count > 0 else "Manage"
	var peers: int = Session.players.size()
	if mode == "solo":
		_session_button.text = "Solo · Menu"
	elif mode == "client" and not Session.connected:
		_session_button.text = "Connecting…" if Session.connecting else "Disconnected · Menu"
	else:
		_session_button.text = "%d / 4 · %s" % [peers, "Host" if mode in ["host", "server"] else "Online"]
	var name_value: String = str(Park.state.get("park_name", "TRAILER PARK"))
	_park_label.text = name_value.to_upper()


func _show_welcome() -> void:
	_open_modal()
	_modal_body.add_child(_label("TRAILER PARK", 34, UI.INK))
	_modal_body.add_child(_label("Build something worth complaining about.", 18, UI.MOSS))
	_modal_body.add_child(HSeparator.new())
	_modal_body.add_child(_paragraph("Lay roads, connect services and turn a few battered trailers into a thriving park. Keep the rent coming in, the water running and your neighbors reasonably happy.", 16, UI.INK))
	_modal_body.add_child(_button("Continue to the park", _close_modal, "PrimaryButton"))
	var multiplayer_row := _hbox(_modal_body, 9)
	var host := _button("Host with friends", func(): _show_session("host"))
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	multiplayer_row.add_child(host)
	var join := _button("Join a park", func(): _show_session("join"))
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	multiplayer_row.add_child(join)
	_modal_body.add_child(_paragraph("HOW TO PLAY\nInspect a building to see its condition and service needs. Pick a building below, preview its footprint, then tap to place. Start with road access and utilities before adding homes. Manage opens money, services, problems and expansion.", 13, UI.MUTED))
	_modal_body.add_child(_paragraph("Camera: drag to pan · pinch / scroll to zoom · two fingers / right drag to orbit · R rotates construction · Esc cancels", 12, UI.MUTED))


func _show_session(start_tab: String = "session") -> void:
	_open_modal()
	var heading := _hbox(_modal_body, 9)
	var title := _label("YOUR PARK, TOGETHER", 23, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("Close", _close_modal, "QuietButton"))
	var tabs := _hbox(_modal_body, 6)
	for entry in [["session", "Park & save"], ["host", "Host"], ["join", "Join"]]:
		var key: String = entry[0]
		tabs.add_child(_button(entry[1], func(): _show_session(key), "ActiveButton" if key == start_tab else "QuietButton"))
	_modal_body.add_child(HSeparator.new())
	if start_tab == "session":
		_build_session_overview()
	else:
		_build_connection_form(start_tab)


func _build_session_overview() -> void:
	var mode: String = str(Session.mode)
	_modal_body.add_child(_label("%s · %d manager%s" % [mode.capitalize(), maxi(1, Session.players.size()), "" if Session.players.size() == 1 else "s"], 17, UI.MOSS))
	if not Session.players.is_empty():
		var names: PackedStringArray = []
		for peer_id in Session.players:
			var player: Dictionary = Session.players[peer_id]
			names.append(str(player.get("name", "Manager")))
		_modal_body.add_child(_paragraph("At the park: " + ", ".join(names), 14, UI.INK))
	if mode in ["host", "server"]:
		_modal_body.add_child(_paragraph("Friends join using this computer's reachable address and the same port/access code. Internet play needs a reachable server or forwarded UDP port.", 13, UI.MUTED))
	if Session.is_authority():
		var save_row := _hbox(_modal_body, 9)
		var save_button := _button("Save park", func():
			var success: bool = Session.save_game()
			show_toast("Park saved." if success else "Could not save the park.", success)
		)
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save_row.add_child(save_button)
		var load_button := _button("Load saved park", func():
			_confirm("Load the saved park?", "Current unsaved progress will be replaced for everyone in this session.", "Load park", func():
				var success: bool = Session.load_game()
				show_toast("Saved park loaded." if success else "No valid saved park was found.", success)
			)
		)
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save_row.add_child(load_button)
		var rename_row := _hbox(_modal_body, 9)
		var park_name := LineEdit.new()
		park_name.text = str(Park.state.get("park_name", "Trailer Park"))
		park_name.max_length = 30
		park_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		park_name.custom_minimum_size.y = 42
		rename_row.add_child(park_name)
		rename_row.add_child(_button("Rename", func(): Session.command("rename", {"name": park_name.text})))
		_modal_body.add_child(_button("Start a fresh park", func():
			_confirm("Start over?", "This creates a fresh park for the current session. Save your existing park first if you want to keep it.", "Create new park", func():
				new_park_requested.emit()
			)
		, "DangerButton"))
	else:
		_modal_body.add_child(_paragraph("The host saves and loads the shared park. Your own camera and menus remain independent.", 14, UI.MUTED))
	if Session.has_method("is_manager") and bool(Session.call("is_manager")):
		var policy := _hbox(_modal_body, 9)
		var caption := _label("Spending approval above", 13, UI.INK)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		policy.add_child(caption)
		var limit := SpinBox.new()
		limit.min_value = 0
		limit.max_value = 100000
		limit.step = 500
		limit.value = float(Session.get("spending_limit"))
		limit.prefix = "$"
		limit.custom_minimum_size = Vector2(135, 42)
		policy.add_child(limit)
		policy.add_child(_button("Apply", func(): Session.call("set_spending_limit", limit.value)))
		_modal_body.add_child(_paragraph("Set $0 to let friends spend freely. Requests above this limit appear under Manage → Problems for the session manager to approve.", 12, UI.MUTED))
	if mode != "solo":
		_modal_body.add_child(_button("Leave multiplayer session", func():
			Session.disconnect_game()
			_show_session()
		, "DangerButton"))
	var audio := CheckButton.new()
	audio.text = "Interface sounds"
	audio.button_pressed = _sound_on
	audio.toggled.connect(func(value: bool): _sound_on = value)
	_modal_body.add_child(audio)


func _build_connection_form(tab: String) -> void:
	var hosting: bool = tab == "host"
	_modal_body.add_child(_paragraph("Open this park for up to three friends." if hosting else "Join a friend or a dedicated park server.", 15, UI.MUTED))
	var name_input := _field(_modal_body, "YOUR NAME", str(Session.player_name), "Manager", 24)
	var address_input: LineEdit
	if not hosting:
		address_input = _field(_modal_body, "SERVER ADDRESS", str(Session.server_address) if not str(Session.server_address).is_empty() else "127.0.0.1", "IP address or hostname", 253)
	var pair := _hbox(_modal_body, 10)
	var port_column := _vbox(pair, 4)
	port_column.custom_minimum_size.x = 140
	port_column.add_child(_label("UDP PORT", 11, UI.MUTED))
	var port_input := SpinBox.new()
	port_input.min_value = 1024
	port_input.max_value = 65535
	port_input.value = Session.server_port
	port_input.custom_minimum_size = Vector2(140, 43)
	port_column.add_child(port_input)
	var code_column := _vbox(pair, 4)
	code_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_column.add_child(_label("ACCESS CODE (OPTIONAL)", 11, UI.MUTED))
	var code_input := LineEdit.new()
	code_input.secret = true
	code_input.max_length = 64
	code_input.text = str(Session.access_code)
	code_input.placeholder_text = "A shared password"
	code_input.custom_minimum_size.y = 43
	code_column.add_child(code_input)
	_session_status = _paragraph("", 13, UI.ORANGE)
	_modal_body.add_child(_session_status)
	_modal_body.add_child(_button("Open park to friends" if hosting else "Join park", func():
		Session.player_name = name_input.text.strip_edges()
		Session.access_code = code_input.text
		var error: Error = Session.host_game(int(port_input.value)) if hosting else Session.join_game(address_input.text.strip_edges(), int(port_input.value))
		if error == OK:
			if hosting:
				_close_modal()
				show_toast("Park open. Share your reachable address, port and access code.")
			else:
				_session_status.text = "Connecting to the park…"
		else:
			_session_status.text = "Connection could not start: " + error_string(error)
	, "PrimaryButton"))
	_modal_body.add_child(_paragraph("Internet hosting requires a reachable UDP server. Joining by address is available now; automatic matchmaking and relay hosting are not configured.", 12, UI.MUTED))


func _on_session_status(message: String) -> void:
	_refresh_top()
	if is_instance_valid(_session_status) and _session_status.is_inside_tree():
		_session_status.text = message
	if Session.mode == "client" and Session.connected:
		_close_modal()
	show_toast(message, not message.to_lower().contains("failed"))


func _open_modal() -> void:
	_clear(_modal_body)
	_session_status = null
	_modal_scroll.scroll_vertical = 0
	_modal_shade.show()


func _close_modal() -> void:
	_modal_shade.hide()


func _confirm(title: String, explanation: String, action_label: String, action: Callable) -> void:
	_open_modal()
	_modal_body.add_child(_label(title, 24, UI.INK))
	_modal_body.add_child(_paragraph(explanation, 15, UI.MUTED))
	var row := _hbox(_modal_body, 9)
	var cancel := _button("Cancel", _close_modal)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var confirm := _button(action_label, func():
		_close_modal()
		action.call()
	, "DangerButton")
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(confirm)


func show_toast(message: String, ok: bool = true) -> void:
	if not is_instance_valid(_toast_panel) or message.is_empty():
		return
	_toast_version += 1
	var version: int = _toast_version
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", Color.WHITE if ok else Color("ffcf9e"))
	_toast_panel.show()
	if ok and _management.visible:
		_refresh_management_values()
		if _management_tab in ["events", "goals", "households"]:
			_refresh_management.call_deferred()
	if ok and _inspector.visible:
		_refresh_inspector.call_deferred()
	await get_tree().create_timer(4.2).timeout
	if version == _toast_version and is_instance_valid(_toast_panel):
		_toast_panel.hide()


func blocks_world_input(position: Vector2) -> bool:
	if is_instance_valid(_modal_shade) and _modal_shade.visible:
		return true
	for control in [_top, _bottom, _inspector, _management, _camera_panel, _overlay_option]:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(position):
			return true
	return false


func _stat(parent: Node, caption: String, value: String) -> Label:
	var column := _vbox(parent, 0)
	column.add_child(_label(caption, 9, UI.MUTED))
	var label := _label(value, 23, UI.INK)
	column.add_child(label)
	return label


func _panel(parent: Node, color: Color, radius: int = 9, padding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(color, radius, Color.TRANSPARENT, padding))
	parent.add_child(panel)
	return panel


func _hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", separation)
	parent.add_child(container)
	return container


func _vbox(parent: Node, separation: int = 8) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", separation)
	parent.add_child(container)
	return container


func _label(caption: String, font_size: int = 16, color: Color = UI.INK) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _paragraph(caption: String, font_size: int = 15, color: Color = UI.INK) -> Label:
	var label := _label(caption, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 260
	return label


func _button(caption: String, callback: Callable, variant: String = "Button") -> Button:
	var button := Button.new()
	button.text = caption
	button.theme_type_variation = variant
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func():
		_ping()
		callback.call()
	)
	return button


func _row(parent: Node, left: String, right: String, font_size: int = 14) -> void:
	var row := _hbox(parent, 10)
	var label := _label(left, font_size, UI.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	row.add_child(_label(right, font_size, UI.INK))


func _meter(parent: Node, caption: String, value: float, maximum: float) -> void:
	_row(parent, caption, "%d%%" % int(value))
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.add_theme_stylebox_override("background", UI.box(UI.LINE, 4, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.MOSS if value >= 55 else UI.ORANGE, 4, Color.TRANSPARENT, 0))
	parent.add_child(bar)


func _field(parent: Node, caption: String, value: String, placeholder: String, length: int) -> LineEdit:
	var column := _vbox(parent, 4)
	column.add_child(_label(caption, 11, UI.MUTED))
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.max_length = length
	field.custom_minimum_size.y = 43
	column.add_child(field)
	return field


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _money(value: float) -> String:
	var amount: int = int(round(value))
	var digits: String = str(absi(amount))
	var formatted: String = ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return ("−$" if amount < 0 else "$") + formatted


func _percent(value: float) -> int:
	return int(round(value * 100.0 if value <= 1.0 and value >= 0.0 else value))
