extends Area2D
class_name InteractableIso

@export var item_name: String = "未命名物品" 
@export var fade_time: float = 0.3  # 渐变时间
@export var label_y_offset: float = -50.0

var name_label: Label
var fade_tween: Tween

func _ready() -> void:
	add_to_group("interactables")
	for child in get_children():
		if child is Label:
			name_label = child
			break
	
	if not name_label :
		name_label = Label.new()
		add_child(name_label) # 把生成的 Label 挂载到自己名下
		
		# 自动配置文字属性
		name_label.text = item_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# 自动计算居中，并向上偏移
		# 注意：因为 Label 的大小是根据文字动态变化的，我们要让它基于中心点对齐
		name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		name_label.position.y = label_y_offset
		
		# 自动生成无视夜间滤镜的材质
		var unshaded_mat = CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		name_label.material = unshaded_mat
	else:
		# 如果是手动放的，也把名字更新一下
		name_label.text = item_name
	
	name_label.modulate = Color(1, 1, 1, 0)
	
	# 3. 确保初始状态文字是完全透明的（隐藏）
	# Color(1, 1, 1, 0) 代表纯白色，但透明度为 0
	name_label.modulate = Color(1, 1, 1, 0) 
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


@export var dialogue_json_path: String = ""
@export var start_node_id: String = "start"

# 气泡模式下的目标节点（如果为空且是 monologue，UI 层会自动找玩家）
@export var bubble_target: NodePath
func interact(player: Player) -> void:
	print("交互触发: ", self.name, " 读取: ", dialogue_json_path)
	
	if dialogue_json_path == "":
		return
		
	# 锁定玩家移动
	player.can_move = false
	if DialogueManager.load_dialogue(dialogue_json_path):
		
		# 监听对话结束信号（如果还没连上的话），用于恢复玩家移动
		# 这里使用 bind 将 player 传给回调函数
		if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended.bind(player)):
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended.bind(player))
			
		DialogueManager.start_dialogue(start_node_id)
	else:
		# 加载失败时，别忘了恢复玩家移动
		player.can_move = true
		push_error("Interactable: Failed to load dialogue JSON.")

# 对话结束时的回调
func _on_dialogue_ended(player: Player) -> void:
	player.can_move = true
	
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

func _on_body_entered(body):
	if body.is_in_group("player") and name_label:
		_animate_label_alpha(1.0)

func _on_body_exited(body):
	if body.is_in_group("player") and name_label:
		_animate_label_alpha(0.0)
		
		
func _animate_label_alpha(target_alpha: float):
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	# 我们只渐变 modulate 里的 a (Alpha) 通道，不影响文字原本的颜色
	fade_tween.tween_property(name_label, "modulate:a", target_alpha, fade_time)
