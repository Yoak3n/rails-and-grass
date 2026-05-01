extends CharacterBody2D
class_name Zhiyi
enum State { PLAYING, CUTSCENE }

var current_state = State.PLAYING

@export var npc_name: String = "未命名角色" 
@export var fade_time: float = 0.3  # 渐变时间
@export var label_y_offset: float = -50.0
@export var label_x_offset: float = -50

var fade_tween: Tween
var name_label: Label

func _ready() -> void:
	add_to_group("interactables")
	_ensure_label()

func _ensure_label() ->void:
	if not name_label :
		name_label = Label.new()
		add_child(name_label) # 把生成的 Label 挂载到自己名下
		
		# 自动配置文字属性
		name_label.text = npc_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# 自动计算居中，并向上偏移
		# 注意：因为 Label 的大小是根据文字动态变化的，我们要让它基于中心点对齐
		name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		name_label.position.y = label_y_offset
		name_label.position.x = label_x_offset
		
		# 自动生成无视夜间滤镜的材质
		var unshaded_mat = CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		name_label.material = unshaded_mat
	else:
		# 如果是手动放的，也把名字更新一下
		name_label.text = npc_name
		name_label.position.y = label_y_offset
		name_label.position.x = label_x_offset
	
	name_label.modulate = Color(1, 1, 1, 0)
	name_label.z_index = 1

func interact(_player: Player) -> void:
	if current_state == State.CUTSCENE:
		return
	pass 
	
func prepare_to_interact() -> void:
	if current_state == State.CUTSCENE:
		return
	_animate_label_alpha(1.0)

func leave_from_interact() -> void:
	_animate_label_alpha(0.0)

func _animate_label_alpha(target_alpha: float):
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	# 我们只渐变 modulate 里的 a (Alpha) 通道，不影响文字原本的颜色
	fade_tween.tween_property(name_label, "modulate:a", target_alpha, fade_time)
