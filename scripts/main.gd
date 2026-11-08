extends Node3D

const WorldScript: Script = preload("res://scripts/world/park_world.gd")
const CameraScript: Script = preload("res://scripts/world/park_camera.gd")
const HUDScript: Script = preload("res://scripts/ui/park_hud.gd")
var world: Node3D
var camera_rig: Node3D
var hud: CanvasLayer
var tool: String = "select"
var rotation_value: int = 0
var selected_id: int = -1
var _press_position: Vector2 = Vector2.ZERO
var _last_pointer: Vector2 = Vector2(-1000,-1000)
var _mouse_down: bool = false
var _dragged: bool = false
var _touches: Dictionary = {}
var _gesture: bool = false
var _preview_signature: String = ""
var _last_plan_time: float = 0.0
var _road_start: Vector2i = Vector2i(-999,-999)

func _ready() -> void:
	if Session.mode == "server": return
	var developed_fixture: bool=OS.is_debug_build() and Session.is_authority() and "--developed" in OS.get_cmdline_user_args() and ResourceLoader.exists("res://tests/populated_park.gd")
	if developed_fixture:
		# Explicit development fixture for testing the entire park, never a network command.
		var fixture: Script=load("res://tests/populated_park.gd")
		fixture.build(Park,30)
		Session.save_slot="developed_test"
	world = WorldScript.new()
	world.name = "ParkWorld"
	add_child(world)
	camera_rig = CameraScript.new()
	camera_rig.name = "ParkCamera"
	add_child(camera_rig)
	camera_rig.focus_at(Vector3(70,0,106))
	if developed_fixture:
		camera_rig.focus_at(Vector3(144,0,108))
		camera_rig.desired_zoom=215.0
		camera_rig.zoom=215.0
	hud = HUDScript.new()
	hud.name = "ParkHUD"
	add_child(hud)
	hud.tool_selected.connect(_set_tool)
	hud.rotation_requested.connect(_rotate_tool)
	hud.overlay_selected.connect(world.set_overlay)
	hud.camera_requested.connect(_camera_action)
	hud.new_park_requested.connect(_new_park)
	hud.inspect_requested.connect(_inspect_building)
	Park.changed.connect(_state_changed)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_later(argument.trim_prefix("--capture="))
		elif argument.begins_with("--focus-id="):
			_inspect_building(int(argument.trim_prefix("--focus-id=")))
			camera_rig.desired_zoom=48.0
			camera_rig.zoom=48.0

func _process(_delta: float) -> void:
	if not is_instance_valid(hud): return
	var pointer: Vector2 = get_viewport().get_mouse_position()
	# Keyboard camera movement pauses while a text field or modal owns input.
	var focused: Control = get_viewport().gui_get_focus_owner()
	camera_rig.input_enabled = not (focused is LineEdit or focused is TextEdit)
	if not _touches.is_empty(): pointer = _touches.values()[0]
	_last_pointer=pointer
	# The camera can move beneath a stationary cursor; refresh projected placement too.
	if tool!="select": _update_preview(pointer)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(hud): return
	# GUI controls consume releases before _unhandled_input. Never retain a drag
	# after a pointer is released over a toolbar, inspector or modal.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if hud.blocks_world_input(event.position):
			_mouse_down=false
			_road_start=Vector2i(-999,-999)
	if event is InputEventScreenTouch and not event.pressed and hud.blocks_world_input(event.position):
		_touches.erase(event.index)
		_road_start=Vector2i(-999,-999)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_mouse_down=false
		_dragged=false
		_touches.clear()
		_gesture=false
		_road_start=Vector2i(-999,-999)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(hud): return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:
				_set_tool("select")
				get_viewport().set_input_as_handled()
			elif event.keycode==KEY_R:
				_rotate_tool()
			elif event.keycode==KEY_F:
				_camera_action("home")
		return
	if event is InputEventMouseButton:
		if hud.blocks_world_input(event.position): return
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: camera_rig.zoom_by(0.9)
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera_rig.zoom_by(1.1)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_down=true
				_dragged=false
				_press_position=event.position
				if tool=="road": _road_start=_cell_at(event.position)
			else:
				if _mouse_down and not _dragged: _activate_point(event.position)
				_mouse_down=false
				_road_start=Vector2i(-999,-999)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			camera_rig.pan_screen(event.relative)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera_rig.rotate_by(-event.relative.x*0.005)
		elif _mouse_down and tool=="select":
			if event.position.distance_to(_press_position)>8: _dragged=true
			if _dragged: camera_rig.pan_screen(event.relative)
	elif event is InputEventMagnifyGesture:
		if not hud.blocks_world_input(event.position): camera_rig.zoom_by(1.0/event.factor)
	elif event is InputEventPanGesture:
		if not hud.blocks_world_input(event.position): camera_rig.pan_screen(event.delta*8)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if hud.blocks_world_input(event.position): return
			_touches[event.index]=event.position
			if _touches.size()==1:
				_press_position=event.position
				_dragged=false
				_gesture=false
				if tool=="road": _road_start=_cell_at(event.position)
			else:
				_gesture=true
				_road_start=Vector2i(-999,-999)
		else:
			if _touches.has(event.index):
				if _touches.size()==1 and not _gesture and not _dragged and not hud.blocks_world_input(event.position): _activate_point(event.position)
				_touches.erase(event.index)
				_road_start=Vector2i(-999,-999)
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index): return
		var previous: Vector2=_touches[event.index]
		_touches[event.index]=event.position
		if _touches.size()>=2:
			var keys: Array=_touches.keys()
			var other_key: int=int(keys[1] if int(keys[0])==event.index else keys[0])
			var other: Vector2=_touches[other_key]
			var old_vector: Vector2=previous-other
			var new_vector: Vector2=event.position-other
			if old_vector.length()>15 and new_vector.length()>15:
				camera_rig.zoom_by(old_vector.length()/new_vector.length())
				camera_rig.rotate_by(old_vector.angle_to(new_vector)*0.65)
			camera_rig.pan_screen(event.relative*0.5)
		elif tool=="select":
			if event.position.distance_to(_press_position)>12: _dragged=true
			if _dragged: camera_rig.pan_screen(event.relative)
		_update_preview(event.position)

func _set_tool(value: String) -> void:
	_road_start=Vector2i(-999,-999)
	if value=="move" and hud.selected_building_id>=0:
		selected_id=hud.selected_building_id
		world.set_selection(selected_id)
		var moving: Dictionary=_selected_building()
		if not moving.is_empty(): rotation_value=int(moving.rotation)
	tool=value
	_preview_signature=""
	hud.set_active_tool(value)
	if value not in Park.CATALOG and value!="move":
		world.show_preview("",Vector2i.ZERO,0,false)
		Session.publish_plan("",0,0,0)
	else:
		_update_preview(_last_pointer)

func _rotate_tool() -> void:
	rotation_value=(rotation_value+1)%4
	_preview_signature=""
	_update_preview(_last_pointer)

func _cell_at(position_value: Vector2) -> Vector2i:
	var hit: Variant=camera_rig.ground_at(position_value)
	if hit==null: return Vector2i(-999,-999)
	var point: Vector3=hit
	return Vector2i(floori(point.x/6.0),floori(point.z/6.0))

func _update_preview(position_value: Vector2) -> void:
	if not is_instance_valid(world): return
	if hud.blocks_world_input(position_value):
		world.show_preview("",Vector2i.ZERO,0,false)
		_preview_signature=""
		return
	var kind: String=tool
	if kind=="move":
		var selected: Dictionary=_selected_building()
		if selected.is_empty():
			hud.set_placement_status("Select a building to relocate first",false)
			return
		kind=str(selected.kind)
	if not Park.CATALOG.has(kind): return
	var cell: Vector2i=_cell_at(position_value)
	var signature: String=str([kind,cell,rotation_value,Park.state.get("revision",0),_road_start])
	if signature==_preview_signature: return
	_preview_signature=signature
	if Time.get_ticks_msec()*0.001-_last_plan_time>0.15:
		_last_plan_time=Time.get_ticks_msec()*0.001
		Session.publish_plan(kind,cell.x,cell.y,rotation_value)
	if kind=="road":
		var points: Array=_road_points(cell)
		var road_valid: Dictionary=Park.validate_road_path(points)
		world.show_road_preview(points,bool(road_valid.get("ok",false)))
		var message: String=str(road_valid.get("message","Drag to build a road"))
		if bool(road_valid.get("ok",false)): message="%d new road cells · $%d · Release to build" % [int(road_valid.get("count",points.size())),int(road_valid.get("cost",0))]
		hud.set_placement_status(message,bool(road_valid.get("ok",false)))
		return
	var valid: Dictionary=Park.validate_move(selected_id,cell.x,cell.y,rotation_value) if tool=="move" else Park.validate_placement(kind,cell.x,cell.y,rotation_value)
	world.show_preview(kind,cell,rotation_value,bool(valid.get("ok",false)))
	var status: String=str(valid.get("message","Tap to build"))
	if bool(valid.get("ok",false)):
		status="%s · $%d · Tap to %s" % [str(Park.CATALOG[kind].name),int(valid.get("cost",Park.CATALOG[kind].cost)),"relocate" if tool=="move" else "place"]
		if kind not in ["tree","lamp","fence"] and not bool(valid.get("connected",true)):
			status+=" · Needs a connected road to operate"
	hud.set_placement_status(status,bool(valid.get("ok",false)))

func _activate_point(position_value: Vector2) -> void:
	var cell: Vector2i=_cell_at(position_value)
	if tool=="road":
		Session.command("road_path",{"points":_road_points(cell)})
	elif tool=="select":
		var b: Dictionary=Park.building_at(cell.x,cell.y)
		selected_id=int(b.get("id",-1))
		world.set_selection(selected_id)
		hud.set_selection(b)
	elif tool=="demolish":
		var b: Dictionary=Park.building_at(cell.x,cell.y)
		if not b.is_empty(): Session.command("demolish",{"id":int(b.id)})
		else: Session.command("demolish",{"x":cell.x,"z":cell.y})
	elif tool=="move":
		if selected_id<0:
			hud.show_toast("Select a building before choosing Move",false)
			return
		Session.command("move",{"id":selected_id,"x":cell.x,"z":cell.y,"rotation":rotation_value})
	elif Park.CATALOG.has(tool):
		Session.command("place",{"kind":tool,"x":cell.x,"z":cell.y,"rotation":rotation_value})
	_preview_signature=""
	_update_preview(position_value)

func _road_points(end: Vector2i) -> Array:
	var start: Vector2i=_road_start if _road_start.x!=-999 else end
	var length: int=absi(end.x-start.x)+absi(end.y-start.y)+1
	if length>96: return []
	var points: Array=[]
	var cursor: Vector2i=start
	points.append({"x":cursor.x,"z":cursor.y})
	while cursor.x!=end.x:
		cursor.x+=1 if end.x>cursor.x else -1
		points.append({"x":cursor.x,"z":cursor.y})
	while cursor.y!=end.y:
		cursor.y+=1 if end.y>cursor.y else -1
		points.append({"x":cursor.x,"z":cursor.y})
	return points

func _selected_building() -> Dictionary:
	for entry in Park.state.get("buildings",[]):
		if int(entry.get("id",-1))==selected_id: return entry
	return {}

func _inspect_building(id: int) -> void:
	selected_id=id
	var building: Dictionary=_selected_building()
	world.set_selection(id)
	if not building.is_empty():
		hud.set_selection(building)
		var fp: Vector2i=Park.footprint(str(building.kind),int(building.rotation))
		camera_rig.focus_at(Vector3((float(building.x)+fp.x*0.5)*6,0,(float(building.z)+fp.y*0.5)*6))
		camera_rig.desired_zoom=minf(camera_rig.desired_zoom,80.0)

func _state_changed() -> void:
	if not is_instance_valid(hud): return
	if selected_id>=0:
		var selected: Dictionary=_selected_building()
		hud.set_selection(selected)
		if selected.is_empty():
			selected_id=-1
			world.set_selection(-1)
			if tool=="move": _set_tool("select")
	_preview_signature=""
	_update_preview(_last_pointer)

func _camera_action(action: String) -> void:
	match action:
		"zoom_in": camera_rig.zoom_by(0.85)
		"zoom_out": camera_rig.zoom_by(1.18)
		"rotate_left": camera_rig.rotate_by(-PI/8)
		"rotate_right": camera_rig.rotate_by(PI/8)
		"home":
			camera_rig.focus_at(Vector3(65,0,107))
			camera_rig.desired_zoom=155.0

func _new_park() -> void:
	Session.new_game()
	selected_id=-1
	_set_tool("select")
	_camera_action("home")

func _capture_later(path: String) -> void:
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image=get_viewport().get_texture().get_image()
	var error: Error=screenshot.save_png(path)
	print("CAPTURE_RESULT ",error," ",path)
	print("RENDER_SAMPLE ",JSON.stringify({"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"homes":Park.metrics().get("lots",0),"note":"Local desktop sample, not a mobile-device benchmark."}))
	if "--capture-quit" in OS.get_cmdline_user_args(): get_tree().quit()
