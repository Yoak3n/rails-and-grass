extends Area2D

@export var auto_start: bool = true
@export var speed: float = 240.0
@export var direction: Vector2 = Vector2(-1, 1)
@export var iso_y_scale: float = 0.5

@export var collision_pause_seconds: float = 5.0
@export var collision_pause_jitter: float = 1.0
@export var collision_cooldown_seconds: float = 0.25
@export var reset_after_offscreen_seconds: float = 2.0
@export var offscreen_padding: float = 48.0

var _moving: bool = true
var _paused: bool = false
var _pause_event_id: int = 0
var _cooldown: float = 0.0
var _spawn_position: Vector2 = Vector2.ZERO
var _offscreen_timer: float = 0.0

func _ready() -> void:
	_moving = auto_start
	_spawn_position = global_position
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_update_offscreen_and_maybe_reset(delta)
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	if not _moving or _paused:
		return
	var d := direction
	if d == Vector2.ZERO:
		return
	d = Vector2(d.x, d.y * iso_y_scale)
	if d == Vector2.ZERO:
		return
	d = d.normalized()
	global_position += d * speed * delta

func reset_to_spawn() -> void:
	_pause_event_id += 1
	_paused = false
	_cooldown = maxf(collision_cooldown_seconds, 0.0)
	_offscreen_timer = 0.0
	global_position = _spawn_position

func start_move() -> void:
	_moving = true

func stop_move() -> void:
	_moving = false

func set_direction(dir: Vector2) -> void:
	direction = dir

func pause_for(seconds: float) -> void:
	_pause_event_id += 1
	var my_id := _pause_event_id
	_paused = true
	var t := get_tree().create_timer(maxf(seconds, 0.0))
	t.timeout.connect(func():
		if my_id != _pause_event_id:
			return
		_paused = false
		_cooldown = maxf(collision_cooldown_seconds, 0.0)
	, CONNECT_ONE_SHOT)

func pause_for_collision() -> void:
	var jitter := randf_range(-collision_pause_jitter, collision_pause_jitter)
	pause_for(maxf(collision_pause_seconds + jitter, 0.0))

func _update_offscreen_and_maybe_reset(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp_size := get_viewport_rect().size
	var z := cam.zoom
	if z.x == 0.0 or z.y == 0.0:
		return
	var half := Vector2(vp_size.x * 0.5 / z.x, vp_size.y * 0.5 / z.y)
	var rect := Rect2(cam.get_screen_center_position() - half, half * 2.0)
	rect = rect.grow(offscreen_padding)
	if rect.has_point(global_position):
		_offscreen_timer = 0.0
		return
	_offscreen_timer += delta
	if _offscreen_timer >= maxf(reset_after_offscreen_seconds, 0.0):
		reset_to_spawn()

func _on_area_entered(_a: Area2D) -> void:
	_handle_collision_pause()

func _on_body_entered(_b: Node) -> void:
	_handle_collision_pause()

func _handle_collision_pause() -> void:
	if not _moving:
		return
	if _paused:
		return
	if _cooldown > 0.0:
		return
	pause_for_collision()
