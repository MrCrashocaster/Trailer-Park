extends Node3D
class_name ParkCamera

var camera: Camera3D
var target: Vector3 = Vector3(100.0, 0.0, 102.0)
var yaw: float = -0.48
var pitch: float = 0.89
var distance: float = 190.0
var zoom: float = 155.0
var desired_zoom: float = 155.0
var input_enabled: bool = true

func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 900.0
	camera.current = true
	add_child(camera)
	_update_camera()

func _process(delta: float) -> void:
	zoom = lerpf(zoom, desired_zoom, minf(delta * 10.0, 1.0))
	if input_enabled:
		var direction: Vector2 = Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1.0
		if Input.is_physical_key_pressed(KEY_Q): yaw -= delta * 0.7
		if Input.is_physical_key_pressed(KEY_E): yaw += delta * 0.7
		if direction.length_squared() > 0.0:
			pan_screen(direction.normalized() * delta * -350.0)
	_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	target.x = clampf(target.x, -10.0, 298.0)
	target.z = clampf(target.z, -10.0, 226.0)
	camera.size = zoom
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.position = target + offset
	camera.look_at(target)

func pan_screen(relative: Vector2) -> void:
	if not is_instance_valid(camera): return
	var scale_factor: float = zoom / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var right: Vector3 = camera.global_basis.x
	var forward: Vector3 = Vector3(camera.global_basis.z.x, 0.0, camera.global_basis.z.z).normalized()
	target -= right * relative.x * scale_factor
	target -= forward * relative.y * scale_factor / sin(pitch)

func zoom_by(factor: float) -> void:
	desired_zoom = clampf(desired_zoom * factor, 32.0, 260.0)

func rotate_by(amount: float) -> void:
	yaw += amount

func focus_at(world_position: Vector3) -> void:
	target = Vector3(world_position.x, 0.0, world_position.z)

func ground_at(screen_position: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
