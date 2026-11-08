extends Node3D
class_name ParkWorld

const CELL: float = 6.0
const TRAILER_PATH: String = "res://assets/trailers/weathered_singlewide/trailer_singlewide_a.glb"
const GRASS: Color = Color("879368")
const GRAVEL: Color = Color("b0a187")
var buildings_root: Node3D
var roads_root: Node3D
var plans_root: Node3D
var decoration_root: Node3D
var parcels_root: Node3D
var overlays_root: Node3D
var ghost: Node3D
var grid: MeshInstance3D
var selection: MeshInstance3D
var trailer_mesh: ArrayMesh
var building_nodes: Dictionary = {}
var road_nodes: Dictionary = {}
var materials: Dictionary = {}
var geometry_cache: Dictionary = {}
var _roads_signature: String = ""
var overlay_mode: String = "normal"
var selected_id: int = -1
var owned_key: String = ""
var world_revision: int = -1
var _rebuild_queued: bool = false

func _ready() -> void:
	_build_environment()
	_load_trailer_mesh()
	buildings_root = _root("Buildings")
	roads_root = _root("Roads")
	parcels_root = _root("Parcels")
	overlays_root = _root("ServiceOverlay")
	plans_root = _root("CollaboratorPlans")
	_build_grid()
	ghost = _root("PlacementPreview")
	selection = _outline(Vector2(18, 12), Color("f5d396"), 0.19)
	selection.visible = false
	add_child(selection)
	Park.changed.connect(_queue_refresh)
	Session.plans_changed.connect(_refresh_plans)
	_refresh()

func _root(label: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = label
	add_child(n)
	return n

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(unshaded)
	if materials.has(key): return materials[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[key] = m
	return m

func _box(parent: Node3D, dimensions: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var n: MeshInstance3D = MeshInstance3D.new()
	var m: BoxMesh = BoxMesh.new()
	m.size = dimensions
	n.mesh = m
	n.material_override = _material(color)
	n.position = position_value
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, radius: float, height: float, position_value: Vector3, color: Color, top: float = -1.0) -> MeshInstance3D:
	var n: MeshInstance3D = MeshInstance3D.new()
	var m: CylinderMesh = CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top < 0.0 else top
	m.height = height
	m.radial_segments = 10
	n.mesh = m
	n.material_override = _material(color)
	n.position = position_value
	parent.add_child(n)
	return n

func _label(parent: Node3D, text_value: String, position_value: Vector3, font_size: int = 48, color: Color = Color("eee9da")) -> Label3D:
	var n: Label3D = Label3D.new()
	n.text = text_value
	n.position = position_value
	n.font_size = font_size
	n.pixel_size = 0.035
	n.modulate = color
	n.outline_size = 6
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = false
	parent.add_child(n)
	return n

func _build_environment() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b8c3b6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5ddd0")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = env
	add_child(environment_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53.0, -35.0, 0)
	sun.light_color = Color("fff7e7")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(530, 460)
	ground.mesh = plane
	ground.position = Vector3(144, -0.05, 108)
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world_position.xz; float n=noise(p*0.055)*0.65+noise(p*0.4)*0.25+noise(p*3.0)*0.1; ALBEDO=mix(vec3(0.24,0.29,0.14),vec3(0.38,0.41,0.25),smoothstep(0.1,0.9,n)); ROUGHNESS=1.0;}
"""
	var ground_material: ShaderMaterial = ShaderMaterial.new()
	ground_material.shader = shader
	ground.material_override = ground_material
	add_child(ground)
	decoration_root = _root("Landscape")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73281
	for i in range(150):
		var p: Vector3 = Vector3(rng.randf_range(-65, 355), 0, rng.randf_range(-62, 278))
		if p.x > -7 and p.x < 295 and p.z > -8 and p.z < 224: continue
		_tree(decoration_root, p, rng.randf_range(0.8, 1.8))
	for i in range(36):
		_box(decoration_root, Vector3(0.18, 1.5, 0.18), Vector3(-3, 0.75, i * CELL), Color("776e54"))
		if i < 35 and i!=18:
			_box(decoration_root, Vector3(0.13, 0.13, CELL), Vector3(-3, 0.6, i * CELL + 3), Color("8c8165"))
			_box(decoration_root, Vector3(0.13, 0.13, CELL), Vector3(-3, 1.2, i * CELL + 3), Color("8c8165"))
	# A boundary road and entrance sign anchor the otherwise expandable park.
	_box(decoration_root, Vector3(11, 0.1, 400), Vector3(-12, 0, 108), Color("77766c"))
	for i in range(28):
		_box(decoration_root, Vector3(0.18, 0.02, 5), Vector3(-12, 0.07, -80 + i * 14), Color("e1cf95"))
	_box(decoration_root, Vector3(17, 0.1, 6), Vector3(-0.5, 0.01, 111), GRAVEL)
	_box(decoration_root, Vector3(0.3, 3.5, 0.3), Vector3(-2, 1.7, 96), Color("746448"))
	_box(decoration_root, Vector3(0.3, 3.5, 0.3), Vector3(10, 1.7, 96), Color("746448"))
	_box(decoration_root, Vector3(13.5, 3.0, 0.35), Vector3(4, 3.2, 96), Color("30483d"))
	_label(decoration_root, "TRAILER PARK\nA LITTLE ROOM TO GROW", Vector3(4, 3.4, 96.25), 46)
	_batch_geometry(decoration_root,"landscape")

func _tree(parent: Node3D, p: Vector3, scale_value: float = 1.0) -> void:
	_cylinder(parent, 0.23 * scale_value, 3.7 * scale_value, p + Vector3(0, 1.8 * scale_value, 0), Color("786248"))
	_cylinder(parent, 2.2 * scale_value, 5.0 * scale_value, p + Vector3(0, 5.2 * scale_value, 0), Color("556b47"), 0.2)
	_cylinder(parent, 1.7 * scale_value, 3.5 * scale_value, p + Vector3(0, 7.0 * scale_value, 0), Color("657a50"), 0.1)

func _load_trailer_mesh() -> void:
	var packed: PackedScene = load(TRAILER_PATH) as PackedScene
	if packed == null:
		push_error("Approved trailer GLB could not be loaded: " + TRAILER_PATH)
		return
	var source: Node = packed.instantiate()
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_meshes(source, Transform3D.IDENTITY, surface)
	surface.index()
	trailer_mesh = surface.commit()
	if trailer_mesh != null:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88
		trailer_mesh.surface_set_material(0, material)
	source.free()

func _append_meshes(node: Node, parent_transform: Transform3D, surface: SurfaceTool) -> void:
	var transform_value: Transform3D = parent_transform
	if node is Node3D: transform_value = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			for s in range(instance.mesh.get_surface_count()):
				var material: Material = instance.get_active_material(s)
				# Park view batches exterior geometry into one shared mesh. The furnished master remains intact.
				if material != null and material.resource_name.begins_with("Interior"): continue
				var color: Color = Color("dad8c9")
				if material is BaseMaterial3D:
					# Material uniforms use sRGB colors; mesh vertex colors are linear.
					color = (material as BaseMaterial3D).albedo_color.srgb_to_linear()
					# Blender's procedural ramps export without baseColorFactor. Recover
					# those authored colors from build_asset.py rather than rendering white.
					color = _authored_trailer_color(material.resource_name, color)
				var arrays: Array = instance.mesh.surface_get_arrays(s)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var normal_basis: Basis = transform_value.basis.inverse().transposed()
				var count: int = indices.size() if not indices.is_empty() else vertices.size()
				for j in range(count):
					var index: int = indices[j] if not indices.is_empty() else j
					var vertex_color: Color=colors[index] if index < colors.size() else Color.WHITE
					if material is BaseMaterial3D and (material as BaseMaterial3D).vertex_color_is_srgb:
						vertex_color=vertex_color.srgb_to_linear()
					surface.set_color(color * vertex_color)
					surface.set_normal((normal_basis * normals[index]).normalized() if index < normals.size() else Vector3.UP)
					surface.add_vertex(transform_value * vertices[index])
	for child in node.get_children(): _append_meshes(child, transform_value, surface)

func _authored_trailer_color(material_name: String, fallback: Color) -> Color:
	# Linear base-color values from the approved source builder. Procedural
	# Blender wear remains a separate, unbaked effect; no baked textures are claimed.
	if material_name.begins_with("Chalked aluminum "):
		var i: int=material_name.trim_prefix("Chalked aluminum ").to_int()
		return Color(0.61+i*0.012,0.59+i*0.011,0.49+i*0.009)
	if material_name.begins_with("Faded sage "):
		var i: int=material_name.trim_prefix("Faded sage ").to_int()
		return Color(0.29+i*0.012,0.39+i*0.013,0.33+i*0.011)
	var palette: Dictionary={
		"Dirty warm white trim":Color(0.73,0.71,0.62),
		"Dry aged porch timber":Color(0.29,0.24,0.18),
		"Oxidized galvanized roof":Color(0.42,0.44,0.42),
		"Oxidized steel":Color(0.24,0.115,0.055),
		"Yellowed curtains":Color(0.57,0.49,0.34),
		"Weathered skirting":Color(0.35,0.38,0.34)
	}
	return palette.get(material_name,fallback)

func _batch_geometry(parent: Node3D, cache_key: String) -> void:
	var combined: ArrayMesh
	if geometry_cache.has(cache_key):
		combined=geometry_cache[cache_key]
	else:
		var surface: SurfaceTool=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in parent.get_children():
			if child is MeshInstance3D: _append_meshes(child,Transform3D.IDENTITY,surface)
		surface.index()
		combined=surface.commit()
		if combined==null: return
		var material: StandardMaterial3D=StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=0.9
		combined.surface_set_material(0,material)
		geometry_cache[cache_key]=combined
	for child in parent.get_children():
		if child is MeshInstance3D: child.free()
	var batched: MeshInstance3D=MeshInstance3D.new()
	batched.mesh=combined
	batched.name="BatchedGeometry"
	parent.add_child(batched)

func _build_grid() -> void:
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(49):
		lines.surface_add_vertex(Vector3(x * CELL, 0.08, 0))
		lines.surface_add_vertex(Vector3(x * CELL, 0.08, 36 * CELL))
	for z in range(37):
		lines.surface_add_vertex(Vector3(0, 0.08, z * CELL))
		lines.surface_add_vertex(Vector3(48 * CELL, 0.08, z * CELL))
	lines.surface_end()
	grid = MeshInstance3D.new()
	grid.mesh = lines
	grid.material_override = _material(Color(0.94, 0.92, 0.78, 0.21), true)
	grid.visible = false
	add_child(grid)

func _outline(size_value: Vector2, color: Color, elevation: float = 0.15) -> MeshInstance3D:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var points: Array[Vector3] = [Vector3(-size_value.x/2, elevation, -size_value.y/2), Vector3(size_value.x/2, elevation, -size_value.y/2), Vector3(size_value.x/2, elevation, size_value.y/2), Vector3(-size_value.x/2, elevation, size_value.y/2)]
	for i in range(4):
		mesh.surface_add_vertex(points[i])
		mesh.surface_add_vertex(points[(i + 1) % 4])
	mesh.surface_end()
	var result: MeshInstance3D = MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = _material(color, true)
	return result

func _queue_refresh() -> void:
	if _rebuild_queued: return
	_rebuild_queued = true
	call_deferred("_refresh")

func _refresh() -> void:
	_rebuild_queued = false
	if not is_instance_valid(buildings_root): return
	var live: Dictionary = {}
	for entry in Park.state.get("buildings", []):
		var data: Dictionary = entry
		var id: int = int(data.id)
		live[id] = true
		var signature: String = str([data.kind, data.x, data.z, data.rotation, data.get("level",1)])
		if building_nodes.has(id) and building_nodes[id].get_meta("signature", "") != signature:
			building_nodes[id].free()
			building_nodes.erase(id)
		if not building_nodes.has(id):
			var visual: Node3D = _make_building(data)
			visual.set_meta("signature", signature)
			building_nodes[id] = visual
	for id in building_nodes.keys():
		if not live.has(id):
			building_nodes[id].free()
			building_nodes.erase(id)
	_refresh_roads()
	var new_owned_key: String = str(Park.state.get("owned", []))
	if new_owned_key != owned_key:
		owned_key = new_owned_key
		_refresh_parcels()
	_refresh_overlay()
	set_selection(selected_id)

func _refresh_roads() -> void:
	var roads: Array=Park.state.get("roads",[])
	var signature: String=str(roads)
	if signature==_roads_signature: return
	_roads_signature=signature
	for child in roads_root.get_children(): child.free()
	var mesh: BoxMesh=BoxMesh.new()
	mesh.size=Vector3(CELL+0.02,0.1,CELL+0.02)
	var instances: MultiMesh=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=mesh
	instances.instance_count=roads.size()
	for i in range(roads.size()):
		instances.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((float(roads[i].x)+0.5)*CELL,0.02,(float(roads[i].z)+0.5)*CELL)))
	var road_mesh: MultiMeshInstance3D=MultiMeshInstance3D.new()
	road_mesh.multimesh=instances
	road_mesh.material_override=_material(GRAVEL)
	roads_root.add_child(road_mesh)

func _make_building(data: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Building_%s" % data.id
	buildings_root.add_child(root)
	var footprint: Vector2i = Park.footprint(str(data.kind), int(data.rotation))
	root.position = Vector3((float(data.x)+footprint.x*0.5)*CELL, 0.12, (float(data.z)+footprint.y*0.5)*CELL)
	root.rotation.y = -int(data.rotation) * PI / 2.0
	var kind: String = str(data.kind)
	var base_footprint: Vector2i = Park.footprint(kind, 0)
	var width: float = base_footprint.x * CELL
	var depth: float = base_footprint.y * CELL
	_box(root, Vector3(width-0.3, 0.06, depth-0.3), Vector3(0, -0.03, 0), Color("9b9b72") if kind == "trailer" else Color("aaa48e"))
	if kind == "trailer":
		if trailer_mesh != null:
			var trailer: MeshInstance3D = MeshInstance3D.new()
			trailer.mesh = trailer_mesh
			trailer.position = Vector3(-0.3, 0, -1.2)
			root.add_child(trailer)
		else:
			_box(root, Vector3(12, 3, 3.5), Vector3(0, 1.8, -1.2), Color("a3ad8b"))
		# Small repeated yard props retain the approved trailer as the focal asset.
		_box(root, Vector3(3.6, 0.06, 2.6), Vector3(-1.8, 0.05, 3.3), Color("c1b69a"))
		_box(root, Vector3(1.6, 0.25, 0.9), Vector3(2.7, 0.65, 3.2), Color("927956"))
		for x in [2.1, 3.3]: _box(root, Vector3(0.13, 0.65, 0.6), Vector3(x, 0.3, 3.2), Color("675942"))
		_cylinder(root, 0.36, 0.95, Vector3(-6.8, 0.5, 2.7), Color("4b5c4a"))
		_cylinder(root, 0.4, 0.08, Vector3(-6.8, 1.0, 2.7), Color("394b3c"))
		var variant: int = int(data.id) % 3
		if variant == 0: _tree(root, Vector3(6.8, 0, 3.3), 0.55)
		if variant == 1:
			_box(root, Vector3(2.5, 0.8, 1.2), Vector3(5.3, 0.45, 3.2), Color("a99b7b"))
			_box(root, Vector3(1.9, 0.5, 0.65), Vector3(5.3, 1.05, 3.2), Color("586052"))
		_label(root, "%02d" % int(data.id), Vector3(-6.8, 1.8, 4.3), 28)
	elif kind == "tree":
		_tree(root, Vector3.ZERO, 1.0)
	elif kind == "lamp":
		_cylinder(root, 0.11, 5.0, Vector3(0, 2.5, 0), Color("60655c"))
		_box(root, Vector3(1.8, 0.15, 0.2), Vector3(0.75, 5, 0), Color("60655c"))
		_box(root, Vector3(1.0, 0.18, 0.6), Vector3(1.3, 4.9, 0), Color("edd99f"))
	elif kind == "fence":
		for x in [-2.6, 2.6]: _box(root, Vector3(0.18, 1.6, 0.18), Vector3(x, 0.8, 0), Color("8c7f61"))
		for y in [0.5, 1.1]: _box(root, Vector3(5.4, 0.16, 0.16), Vector3(0, y, 0), Color("9c8e70"))
	elif kind == "water":
		for x in [-1.5,1.5]:
			for z in [-1.5,1.5]: _cylinder(root, 0.13, 6, Vector3(x,3,z), Color("8a8f81"))
		_cylinder(root, 2.6, 3.4, Vector3(0, 6.8, 0), Color("b6c4bd"))
		_cylinder(root, 2.7, 0.7, Vector3(0, 8.8, 0), Color("d2d7c6"), 0.2)
		_label(root, "WATER", Vector3(0,7,2.7),28,Color("2c4d4a"))
	elif kind == "power":
		_box(root, Vector3(width-1.6, 1.1, depth-1.8), Vector3(0,0.55,0), Color("8c9584"))
		for x in [-1.5,1.5]:
			_box(root, Vector3(1.5,2,2), Vector3(x,1.8,0),Color("68776b"))
			for z in [-0.5,0.5]: _cylinder(root,0.16,0.8,Vector3(x,3.1,z),Color("b0b6a7"))
		_label(root,"POWER",Vector3(0,4,0),32,Color("f0d386"))
	elif kind == "sewage":
		for x in [-1.7,1.7]:
			_cylinder(root,1.4,0.8,Vector3(x,0.4,0),Color("9a9d87"))
			_cylinder(root,1.2,0.05,Vector3(x,0.83,0),Color("52665b"))
		_box(root,Vector3(3,2,2.3),Vector3(0,1.0,-3),Color("8b9981"))
		_label(root,"SEWAGE",Vector3(0,3.3,0),30)
	else:
		var color: Color = Color("c6bda0")
		if kind == "maintenance": color=Color("9b9d80")
		if kind == "store": color=Color("b4ba93")
		if kind == "trash": color=Color("7e8a72")
		if kind == "laundry": color=Color("b4c3bd")
		var bw: float = minf(width-1.6, 10.5)
		var bd: float = minf(depth-1.8, 7.5)
		_box(root,Vector3(bw,3.4,bd),Vector3(0,1.7,0),color)
		_box(root,Vector3(bw+0.7,0.3,bd+0.6),Vector3(0,3.55,0),Color("636d61"))
		_box(root,Vector3(1.2,2.4,0.12),Vector3(0,1.2,bd/2+0.08),Color("526258"))
		for x in [-bw*0.3,bw*0.3]:
			_box(root,Vector3(1.7,1.2,0.16),Vector3(x,2.1,bd/2+0.1),Color("d9d8bf"))
			_box(root,Vector3(1.4,0.9,0.18),Vector3(x,2.1,bd/2+0.14),Color("657b79"))
		var title: String = str(Park.CATALOG.get(kind,{}).get("name",kind)).to_upper()
		_label(root,title,Vector3(0,4.5,0),34)
		if kind == "trash":
			for x in [-2,0,2]: _box(root,Vector3(1.6,1.3,1.5),Vector3(x,0.7,bd/2+2),Color("52684c"))
	var variant_key: String="%s_%s_%s" % [kind,int(data.id)%3 if kind=="trailer" else 0,int(data.get("level",1))]
	_batch_geometry(root,variant_key)
	return root

func _refresh_parcels() -> void:
	for child in parcels_root.get_children(): child.free()
	for parcel in range(6):
		var owned: bool = Park.state.get("owned",[]).has(parcel)
		var center: Vector3 = Vector3((parcel%3)*96+48,0.11,(parcel/3)*108+54)
		var border: MeshInstance3D = _outline(Vector2(95.5,107.5), Color(0.95,0.87,0.64,0.65) if owned else Color(0.88,0.8,0.65,0.3))
		border.position = center
		parcels_root.add_child(border)
		if not owned:
			var label: Label3D = _label(parcels_root,"EXPANSION %s\nPURCHASE IN LAND & GOALS" % (parcel+1),center+Vector3(0,1.0,0),32,Color("e9dbb5"))
			label.modulate.a=0.75

func _refresh_overlay() -> void:
	for child in overlays_root.get_children(): child.free()
	if overlay_mode == "normal": return
	for entry in Park.state.get("buildings",[]):
		var b: Dictionary = entry
		var color: Color = Color(0.3,0.7,0.55,0.5)
		if overlay_mode in ["power","water","sewage"]:
			if str(b.kind)!="trailer" and str(b.kind)!=overlay_mode: continue
			var supplied: bool = bool(b.get("services",{}).get(overlay_mode,false))
			if str(b.kind)==overlay_mode:
				supplied=bool(b.get("connected",false)) and float(b.get("condition",0))>=25.0
				if overlay_mode in ["water","sewage"]: supplied=supplied and int(Park.metrics().get("power",{}).get("capacity",0))>0
			color=Color(0.22,0.65,0.52,0.55) if supplied else Color(0.86,0.32,0.23,0.65)
		elif overlay_mode == "happiness":
			color=Color("bc6149").lerp(Color("81bd89"),clampf(float(b.get("happiness",50))/100,0,1))
			color.a=0.6
		elif overlay_mode == "condition":
			color=Color("b74e36").lerp(Color("95bd89"),clampf(float(b.get("condition",100))/100,0,1))
			color.a=0.6
		elif overlay_mode == "land": continue
		var fp: Vector2i = Park.footprint(str(b.kind),int(b.rotation))
		var tile: MeshInstance3D = _box(overlays_root,Vector3(fp.x*CELL-0.1,0.03,fp.y*CELL-0.1),Vector3((float(b.x)+fp.x*0.5)*CELL,0.22,(float(b.z)+fp.y*0.5)*CELL),color)
		tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_overlay(mode: String) -> void:
	overlay_mode=mode
	_refresh_overlay()

func set_selection(id: int) -> void:
	selected_id=id
	if not is_instance_valid(selection): return
	selection.visible=false
	for entry in Park.state.get("buildings",[]):
		var b: Dictionary=entry
		if int(b.id)!=id: continue
		var fp: Vector2i=Park.footprint(str(b.kind),int(b.rotation))
		var shape: MeshInstance3D=_outline(Vector2(fp.x*CELL,fp.y*CELL),Color("f5d396"))
		selection.mesh=shape.mesh
		shape.free()
		selection.position=Vector3((float(b.x)+fp.x*0.5)*CELL,0.15,(float(b.z)+fp.y*0.5)*CELL)
		selection.visible=true
		break

func show_preview(kind: String, cell: Vector2i, rotation_value: int, valid: bool) -> void:
	for child in ghost.get_children(): child.free()
	grid.visible=not kind.is_empty()
	if kind.is_empty(): return
	var fp: Vector2i=Park.footprint(kind,rotation_value)
	var color: Color=Color(0.44,0.86,0.66,0.48) if valid else Color(0.92,0.33,0.24,0.55)
	var center: Vector3=Vector3((cell.x+fp.x*0.5)*CELL,0.2,(cell.y+fp.y*0.5)*CELL)
	_box(ghost,Vector3(fp.x*CELL-0.15,0.1,fp.y*CELL-0.15),center,color)
	var border: MeshInstance3D=_outline(Vector2(fp.x*CELL,fp.y*CELL),Color("e9f2d8") if valid else Color("ffb89a"))
	border.position=center
	ghost.add_child(border)

func show_road_preview(points: Array, valid: bool) -> void:
	for child in ghost.get_children(): child.free()
	grid.visible=true
	if points.is_empty(): return
	var box: BoxMesh=BoxMesh.new()
	box.size=Vector3(CELL-0.12,0.12,CELL-0.12)
	var multi: MultiMesh=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=box
	multi.instance_count=points.size()
	for i in range(points.size()):
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3((float(points[i].x)+0.5)*CELL,0.25,(float(points[i].z)+0.5)*CELL)))
	var preview: MultiMeshInstance3D=MultiMeshInstance3D.new()
	preview.multimesh=multi
	preview.material_override=_material(Color(0.44,0.86,0.66,0.55) if valid else Color(0.92,0.33,0.24,0.55),true)
	preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.add_child(preview)

func _refresh_plans() -> void:
	if not is_instance_valid(plans_root): return
	for child in plans_root.get_children(): child.free()
	for peer in Session.plans.keys():
		var plan: Dictionary=Session.plans[peer]
		var kind: String=str(plan.get("kind",""))
		if not Park.CATALOG.has(kind): continue
		var fp: Vector2i=Park.footprint(kind,int(plan.get("rotation",0)))
		var center: Vector3=Vector3((float(plan.get("x",0))+fp.x*0.5)*CELL,0.35,(float(plan.get("z",0))+fp.y*0.5)*CELL)
		var border: MeshInstance3D=_outline(Vector2(fp.x*CELL,fp.y*CELL),Color("e6b478"))
		border.position=center
		plans_root.add_child(border)
		_label(plans_root,str(plan.get("name","Manager"))+" is planning",center+Vector3(0,4,0),28,Color("f2d5a2"))
