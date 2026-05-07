extends GPUParticles2D

@export var rain_amount: int = 300
@export var rain_speed: float = 600.0
@export var rain_spread: float = 5.0
@export var rain_direction: Vector2 = Vector2(0.2, 1.0)
@export var rain_lifetime: float = 1.5
@export var rain_scale_min: float = 0.3
@export var rain_scale_max: float = 0.8
@export var rain_color: Color = Color(0.6, 0.7, 0.85, 0.5)

@export var follow_camera: bool = true
@export var follow_offset: Vector2 = Vector2(0,-350)

var _camera: Camera2D

func _ready() -> void:
	emitting = true
	_setup_particles()
	_find_camera()

func _process(_delta: float) -> void:
	if follow_camera and _camera:
		global_position = _camera.global_position + follow_offset

func _setup_particles() -> void:
	amount = rain_amount
	lifetime = rain_lifetime
	texture = _generate_raindrop_texture()
	_apply_material()

func _generate_raindrop_texture() -> ImageTexture:
	var img := Image.create(4, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		var t: float = float(y) / 15.0
		var alpha: float = 1.0 - t * 0.6
		var half_w: int = int(2.0 * (1.0 - t * 0.5))
		for x in range(4):
			var dist: float = absf(float(x) - 1.5)
			if dist <= float(half_w):
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			else:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
	return ImageTexture.create_from_image(img)

func _apply_material() -> void:
	var mat := process_material as ParticleProcessMaterial
	if not mat:
		return
	mat.direction = Vector3(rain_direction.x, rain_direction.y, 0)
	mat.spread = rain_spread
	mat.initial_velocity_min = rain_speed * 0.8
	mat.initial_velocity_max = rain_speed
	mat.gravity = Vector3(0, 400, 0)
	mat.scale_min = rain_scale_min
	mat.scale_max = rain_scale_max
	mat.color = rain_color
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 0, 0)

func _find_camera() -> void:
	await get_tree().process_frame
	var cameras := get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		_camera = cameras[0]
		return
	var root := get_tree().current_scene
	if root:
		_camera = _find_camera_recursive(root)

func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node as Camera2D
	for child in node.get_children():
		var result := _find_camera_recursive(child)
		if result:
			return result
	return null
