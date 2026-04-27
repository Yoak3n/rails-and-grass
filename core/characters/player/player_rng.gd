extends CharacterBody2D
class_name Player

enum State { PLAYING, CUTSCENE }
var current_state = State.PLAYING
var _can_move: bool = true
var can_move: bool:
	get:
		return _can_move
	set(value):
		_can_move = value
		current_state = State.PLAYING if value else State.CUTSCENE
		if not value:
			velocity = Vector2.ZERO
@export var speed: float = 150.0 # 移动速度
@onready var interact_detector: Area2D = $InteractDetector
@onready var visuals = $CollisionShape2D/Visuals
@onready var player_camera = $Camera2D
@onready var anim_player = $CollisionShape2D/Visuals/Mesh/AnimationPlayer
var current_interactable: Area2D = null
var last_anim_dir = "idle"
var move_right: bool = false
func _ready() -> void:
	add_to_group("player")
	interact_detector.area_entered.connect(_on_interact_area_entered)
	interact_detector.area_exited.connect(_on_interact_area_exited)
	
func _physics_process(_delta: float) -> void:
	if not can_move:
		anim_player.play("idle")
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var input_dir = Input.get_vector("left","right","up","down")
	if input_dir != Vector2.ZERO:
		var snap_dir = input_dir.sign()
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
	velocity = input_dir * speed
	velocity.y *= 0.5
	move_and_slide()

func _input(event: InputEvent)-> void:
	if not can_move:
		return
	if event.is_action_pressed("interact") and current_interactable:
		# 如果有可交互的物品，触发它的 interact() 方法
		current_interactable.interact(self)

func _on_interact_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactables"):
		area.prepare_to_interact()
		current_interactable = area
		# 可选：在头顶显示一个小提示（如 "[E] 调查"）

func _on_interact_area_exited(area: Area2D) -> void:
	if area == current_interactable:
		current_interactable.leave_from_interact()
		current_interactable = null