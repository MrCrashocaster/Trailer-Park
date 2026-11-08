extends Node
## Headless integration checks for the approved mesh, world placement and live HUD.
## This does not measure GPU performance or replace device/screenshot inspection.

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const TRAILER_PATH: String = "res://assets/trailers/weathered_singlewide/trailer_singlewide_a.glb"
var checks: int = 0
var failures: Array[String] = []
var main: Node3D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Park.reset(31415)
	Park.apply_command("speed",{"value":0})
	main=MainScene.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.hud._close_modal()
	_test_batched_mesh()
	_test_world_rotations()
	await _test_hud_and_world()
	await _test_release_cleanup()
	await _test_stationary_pointer_preview()
	if failures.is_empty():
		print("WORLD_TESTS_PASSED: %d checks" % checks)
	else:
		for failure: String in failures: push_error(failure)
		print("WORLD_TESTS_FAILED: %d of %d checks" % [failures.size(),checks])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message)

func _test_batched_mesh() -> void:
	var packed: PackedScene=load(TRAILER_PATH) as PackedScene
	_check(packed!=null,"The approved trailer imports as a usable PackedScene")
	if packed==null: return
	var source: Node=packed.instantiate()
	var source_nodes: int=_node_count(source)
	var source_meshes: int=_mesh_count(source)
	var batch: ArrayMesh=main.world.trailer_mesh
	_check(batch!=null and batch.get_surface_count()==1,"Park exterior batches into one shared mesh surface")
	if batch==null:
		source.free()
		return
	var bounds: AABB=batch.get_aabb()
	print("TRAILER_BATCH_METRICS: source_nodes=",source_nodes," source_meshes=",source_meshes," surfaces=",batch.get_surface_count()," bounds=",bounds)
	_check(_finite_vector(bounds.position) and _finite_vector(bounds.size),"Batched approved-trailer bounds are finite")
	_check(bounds.size.x>10.0 and bounds.size.x<18.0 and bounds.size.y>2.0 and bounds.size.y<8.0 and bounds.size.z>3.0 and bounds.size.z<12.0,"Imported trailer keeps believable meter-scale bounds and fits the lot")
	var arrays: Array=batch.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	_check(vertices.size()>100 and normals.size()==vertices.size() and colors.size()==vertices.size(),"Batched geometry retains vertices, normals and material colors")
	var white_vertices: int=0
	var sage_vertices: int=0
	for color: Color in colors:
		if color.r>0.95 and color.g>0.95 and color.b>0.95: white_vertices+=1
		if color.g>color.r+0.06 and color.g>color.b+0.03: sage_vertices+=1
	_check(white_vertices<colors.size()/20,"Procedural source materials recover their authored colors instead of exporting white")
	_check(sage_vertices>colors.size()/30,"Approved faded-sage siding remains present in the game mesh palette")
	var finite: bool=true
	for vertex: Vector3 in vertices:
		if not _finite_vector(vertex): finite=false; break
	for normal: Vector3 in normals:
		if not _finite_vector(normal): finite=false; break
	_check(finite,"Batched mesh vertex and normal data contain no NaN or infinity")
	var copies: int=0
	var largest_visual: int=0
	var shared_variants: Dictionary={}
	for building_id: Variant in main.world.building_nodes:
		var visual: Node=main.world.building_nodes[building_id]
		largest_visual=maxi(largest_visual,_node_count(visual))
	for building: Dictionary in Park.state.buildings:
		if str(building.kind)!="trailer": continue
		var visual: Node=main.world.building_nodes[int(building.id)]
		var geometry: MeshInstance3D=visual.get_node_or_null("BatchedGeometry") as MeshInstance3D
		if geometry!=null:
			copies+=1
			shared_variants[geometry.mesh.get_instance_id()]=true
			var cache_key: String="trailer_%s_%s" % [int(building.id)%3,int(building.level)]
			_check(geometry.mesh==main.world.geometry_cache.get(cache_key),"Each lot reuses its cached approved-trailer-and-yard mesh")
	print("TRAILER_INSTANCE_METRICS: shared_mesh_instances=",copies," park_homes=",Park.metrics().lots," world_building_nodes=",main.world.building_nodes.size()," largest_visual_nodes=",largest_visual)
	_check(copies==8 and shared_variants.size()==3,"All eight starting trailers reuse three cached approved-mesh yard variants")
	_check(source_nodes>largest_visual*2 and source_meshes>1,"Park instances substantially reduce the approved master scene's node count")
	source.free()

func _test_world_rotations() -> void:
	var base: Dictionary=Park.state.buildings[0].duplicate(true)
	base.id=999
	base.x=11
	base.z=21
	for turn: int in range(4):
		base.rotation=turn
		var visual: Node3D=main.world._make_building(base)
		var footprint: Vector2i=Park.footprint("trailer",turn)
		var expected: Vector3=Vector3((11.0+float(footprint.x)*0.5)*6.0,0.12,(21.0+float(footprint.y)*0.5)*6.0)
		_check(visual.position.is_equal_approx(expected),"Quarter-turn %d places the model at the logical footprint center" % turn)
		_check(is_equal_approx(visual.rotation.y,-float(turn)*PI/2.0),"Quarter-turn %d uses the correct model orientation" % turn)
		var geometry: AABB=_mesh_bounds(visual,Transform3D.IDENTITY)
		_check(_finite_vector(geometry.position) and _finite_vector(geometry.size),"Rotated lot %d keeps finite geometry bounds" % turn)
		var origin: Vector2=Vector2(11.0*6.0,21.0*6.0)
		var end: Vector2=origin+Vector2(footprint)*6.0
		_check(geometry.position.x>=origin.x-0.5 and geometry.end.x<=end.x+0.5 and geometry.position.z>=origin.y-0.5 and geometry.end.z<=end.y+0.5,"Rotated trailer and yard fit the corresponding grid footprint")
		visual.free()

func _test_hud_and_world() -> void:
	var hud: CanvasLayer=main.hud
	for tab: String in ["finance","services","households","events","goals"]:
		hud._open_management(tab)
		_check(hud._management.visible and hud._management_body.get_child_count()>0,"Management tab %s builds against the real simulation" % tab)
	for tab: String in ["session","host","join"]:
		hud._show_session(tab)
		_check(hud._modal_body.get_child_count()>0,"Session tab %s builds against the real network API" % tab)
	hud._close_modal()
	hud._open_management("finance")
	var borrow: Button=_find_button(hud._management_body,"Borrow $10,000")
	var cash: float=float(Park.state.cash)
	_check(borrow!=null,"Finance UI exposes the actual loan command")
	if borrow!=null:
		borrow.pressed.emit()
		_check(float(Park.state.cash)==cash+10000.0 and float(Park.state.debt)==10000.0,"A HUD action reaches Session and changes authoritative simulation state")
	hud._management.hide()
	main._inspect_building(1)
	_check(int(hud.selected_building_id)==1 and main.world.selection.visible,"Inspector and world selection agree on the selected building")
	var repair: Button=_find_button(hud._inspector_body,"Arrange repairs",true)
	_check(repair!=null,"Inspector exposes condition-based repair action")
	if repair!=null:
		repair.pressed.emit()
		_check(float(Park.building_at(3,3).condition)==100.0,"Inspector repair action applies to the selected building")
	for mode: String in ["power","water","sewage","condition","happiness","land","normal"]:
		main.world.set_overlay(mode)
		_check(str(main.world.overlay_mode)==mode,"World accepts %s overlay" % mode)
	main._set_tool("tree")
	_check(main.tool=="tree","HUD tool selection integrates with the world controller")
	main._rotate_tool()
	_check(int(main.rotation_value)==1,"Construction rotation request reaches the controller")
	main._set_tool("select")
	hud._inspector.hide()
	# Create and then delete an eligible selected object, exercising all changed
	# signal handlers and the world's deferred visual refresh.
	var result: Dictionary=Park.apply_command("place",{"kind":"tree","x":12,"z":4})
	_check(bool(result.ok),"Selection lifecycle fixture places successfully")
	var selected: Dictionary=Park.building_at(12,4)
	var selected_id: int=int(selected.id)
	main._inspect_building(selected_id)
	Park.apply_command("demolish",{"id":selected_id})
	await get_tree().process_frame
	_check(int(main.selected_id)==-1 and int(main.world.selected_id)==-1 and int(hud.selected_building_id)==-1,"Deleting a selected object clears controller, world and HUD selection")
	_check(not main.world.selection.visible,"Deleted-object selection outline is hidden")
	hud._inspector.hide()

func _test_release_cleanup() -> void:
	main.hud._close_modal()
	main.hud._management.hide()
	main.hud._inspector.hide()
	main._set_tool("select")
	await get_tree().process_frame
	var press: InputEventMouseButton=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=Vector2(640,400)
	press.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(press)
	await get_tree().process_frame
	_check(bool(main._mouse_down),"World mouse press begins an interaction")
	var release: InputEventMouseButton=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT
	release.pressed=false
	release.position=Vector2(40,40)
	Input.parse_input_event(release)
	await get_tree().process_frame
	_check(not bool(main._mouse_down),"Releasing over the GUI cannot leave stale world mouse-down state")
	var touch: InputEventScreenTouch=InputEventScreenTouch.new()
	touch.index=5
	touch.pressed=true
	touch.position=Vector2(640,400)
	Input.parse_input_event(touch)
	await get_tree().process_frame
	_check(main._touches.has(5),"World touch press begins a tracked touch")
	var touch_release: InputEventScreenTouch=InputEventScreenTouch.new()
	touch_release.index=5
	touch_release.pressed=false
	touch_release.position=Vector2(40,40)
	Input.parse_input_event(touch_release)
	await get_tree().process_frame
	_check(not main._touches.has(5),"Releasing a touch above GUI clears the tracked contact")

func _test_stationary_pointer_preview() -> void:
	main.hud._close_modal()
	main.hud._management.hide()
	main.hud._inspector.hide()
	main.camera_rig.focus_at(Vector3(70,0,106))
	main.camera_rig._update_camera()
	var pointer: Vector2=Vector2(640,400)
	var motion: InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=pointer
	Input.parse_input_event(motion)
	main._set_tool("tree")
	await get_tree().process_frame
	await get_tree().process_frame
	var before: String=str(main._preview_signature)
	main.camera_rig.focus_at(Vector3(106,0,106))
	main.camera_rig._update_camera()
	await get_tree().process_frame
	await get_tree().process_frame
	var after: String=str(main._preview_signature)
	_check(not before.is_empty() and not after.is_empty() and before!=after,"Camera movement refreshes placement beneath a stationary pointer")
	main._set_tool("select")
	_check(main.world.ghost.get_child_count()==0 and not main.world.grid.visible,"Returning to selection clears construction preview and grid")

func _node_count(node: Node) -> int:
	var result: int=1
	for child: Node in node.get_children(): result+=_node_count(child)
	return result

func _mesh_count(node: Node) -> int:
	var result: int=1 if node is MeshInstance3D else 0
	for child: Node in node.get_children(): result+=_mesh_count(child)
	return result

func _mesh_bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var transform_value: Transform3D=parent_transform
	if node is Node3D: transform_value=parent_transform*node.transform
	var result: AABB=AABB()
	var found: bool=false
	if node is MeshInstance3D and node.mesh!=null:
		result=transform_value*node.mesh.get_aabb()
		found=true
	for child: Node in node.get_children():
		var child_bounds: AABB=_mesh_bounds(child,transform_value)
		if child_bounds.size!=Vector3.ZERO:
			result=result.merge(child_bounds) if found else child_bounds
			found=true
	return result

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _find_button(node: Node, text_value: String, prefix: bool = false) -> Button:
	if node is Button and (node.text.begins_with(text_value) if prefix else node.text==text_value): return node
	for child: Node in node.get_children():
		var found: Button=_find_button(child,text_value,prefix)
		if found!=null: return found
	return null
