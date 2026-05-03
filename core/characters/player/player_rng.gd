extends CharacterBody2D
class_name Player

enum State { PLAYING, CUTSCENE }
@export var current_state = State.PLAYING
var _can_move_base: bool = true
var _can_move_effective: bool = true
var _movement_locks: Dictionary = {}
var _dialogue_lock_active: bool = false
var _cutscene_collisions_disabled: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0
var _saved_detector_monitoring: bool = true
var can_move: bool:
	get:
		return _can_move_effective
	set(value):
		_can_move_base = value
		_recompute_can_move()
@export var speed: float = 150.0 # 移动速度
@export var animation_direction_override: Vector2 = Vector2.ZERO
@onready var interact_detector: Area2D = $InteractDetector
@onready var visuals = $CollisionShape2D/Visuals
@onready var player_camera = $Camera2D
@onready var anim_player = $CollisionShape2D/Visuals/Mesh/AnimationPlayer
@onready var pause_menu = $PauseMenu
var current_interactable: Node = null
var _overlapping_interactables: Array[Node] = []
var last_anim_dir = "idle"
var move_right: bool = false

func _ready() -> void:
	add_to_group("player")
	pause_menu.visible = true
	interact_detector.area_entered.connect(_on_interact_area_entered)
	interact_detector.area_exited.connect(_on_interact_area_exited)
	interact_detector.body_entered.connect(_on_interact_area_entered)
	interact_detector.body_exited.connect(_on_interact_area_exited)
	DialogueManager.text_ready.connect(_on_dialogue_text_ready)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if not CutsceneManager.cutscene_started.is_connected(_on_cutscene_started):
		CutsceneManager.cutscene_started.connect(_on_cutscene_started)
	if not CutsceneManager.cutscene_finished.is_connected(_on_cutscene_finished):
		CutsceneManager.cutscene_finished.connect(_on_cutscene_finished)
	_recompute_can_move()
	
func play_animaiton(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		var snap_dir = direction.sign()
		match snap_dir:
			Vector2(1,0):
				last_anim_dir = "right"
				visuals.scale.x = 1
			Vector2(-1, 0):  # 纯左
				last_anim_dir = "right" # 复用右边素材
				visuals.scale.x = -1    # 镜像翻转
			Vector2(0, 1):   # 纯下
				last_anim_dir = "down"
				visuals.scale.y = 1
			Vector2(0, -1):  # 纯上
				last_anim_dir = "up"
				visuals.scale.y = 1
			Vector2(1, 1):   # 右下
				last_anim_dir = "down_right"
				visuals.scale.x = 1
			Vector2(-1, 1):  # 左下
				last_anim_dir = "down_right" # 复用右下素材
				visuals.scale.x = -1        # 镜像翻转
			Vector2(1, -1):  # 右上
				last_anim_dir = "up_right"
				visuals.scale.x = 1 
			Vector2(-1, -1): # 左上
				last_anim_dir = "up_right"   # 复用右上素材
				visuals.scale.x = -1         # 镜像翻转
		anim_player.play(last_anim_dir)
	else:
		anim_player.play("idle")
	velocity = direction * speed
	velocity.y *= 0.5
	move_and_slide()


func _physics_process(_delta: float) -> void:
	if can_move:
		var input_dir = Input.get_vector("left","right","up","down")
		play_animaiton(input_dir)
	else:
		play_animaiton(animation_direction_override)

func _input(event: InputEvent)-> void:
	if not can_move:
		return
	if event.is_action_pressed("interact") and current_interactable:
		# 如果有可交互的物品，触发它的 interact() 方法
		if current_interactable.has_method("interact"):
			current_interactable.interact(self)

func _on_interact_area_entered(target: Node) -> void:
	if not target.is_in_group("interactables"):
		return
	if not target.has_method("prepare_to_interact"):
		return
	if not _overlapping_interactables.has(target):
		_overlapping_interactables.append(target)
	_sync_current_interactable()

func _on_interact_area_exited(target: Node) -> void:
	_overlapping_interactables.erase(target)
	_sync_current_interactable()

func lock_movement(reason: String) -> void:
	var c: int = int(_movement_locks.get(reason, 0))
	_movement_locks[reason] = c + 1
	_recompute_can_move()

func unlock_movement(reason: String) -> void:
	var c: int = int(_movement_locks.get(reason, 0))
	c = maxi(c - 1, 0)
	if c == 0:
		_movement_locks.erase(reason)
	else:
		_movement_locks[reason] = c
	_recompute_can_move()

func _recompute_can_move() -> void:
	var is_locked: bool = not _movement_locks.is_empty()
	var next_effective: bool = _can_move_base and not is_locked
	if next_effective == _can_move_effective:
		return
	_can_move_effective = next_effective
	current_state = State.PLAYING if _can_move_effective else State.CUTSCENE
	if not _can_move_effective:
		velocity = Vector2.ZERO
	_sync_current_interactable()

func _sync_current_interactable() -> void:
	if not can_move:
		if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("leave_from_interact"):
			current_interactable.leave_from_interact()
		current_interactable = null
		return
	for i in range(_overlapping_interactables.size() - 1, -1, -1):
		var n := _overlapping_interactables[i]
		if n == null or not is_instance_valid(n):
			_overlapping_interactables.remove_at(i)
	var new_target: Node = null
	var best_dist: float = INF
	for n in _overlapping_interactables:
		if n == null or not is_instance_valid(n):
			continue
		if n is Node2D:
			var d := (n as Node2D).global_position.distance_squared_to(global_position)
			if d < best_dist:
				best_dist = d
				new_target = n
		else:
			if new_target == null:
				new_target = n
	if new_target == current_interactable:
		return
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("leave_from_interact"):
		current_interactable.leave_from_interact()
	current_interactable = new_target
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.has_method("prepare_to_interact"):
		current_interactable.prepare_to_interact()

func _on_dialogue_text_ready(_speaker: String, _text: String, _presentation: String, _target: Node, _next_node_id: String, _duration: float) -> void:
	if _dialogue_lock_active:
		return
	_dialogue_lock_active = true
	lock_movement("dialogue")

func _on_dialogue_ended() -> void:
	if not _dialogue_lock_active:
		return
	_dialogue_lock_active = false
	unlock_movement("dialogue")

func _on_cutscene_started(_id: String) -> void:
	_set_collisions_enabled(false)

func _on_cutscene_finished(_id: String) -> void:
	call_deferred("_maybe_restore_collisions_after_cutscene")

func _maybe_restore_collisions_after_cutscene() -> void:
	if CutsceneManager.is_playing():
		return
	_set_collisions_enabled(true)

func _set_collisions_enabled(enabled: bool) -> void:
	if enabled:
		if not _cutscene_collisions_disabled:
			return
		_cutscene_collisions_disabled = false
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		interact_detector.monitoring = _saved_detector_monitoring
		_sync_current_interactable()
		return
	if _cutscene_collisions_disabled:
		return
	_cutscene_collisions_disabled = true
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	_saved_detector_monitoring = interact_detector.monitoring
	collision_layer = 0
	collision_mask = 0
	interact_detector.monitoring = false
	_overlapping_interactables.clear()
	_sync_current_interactable()
