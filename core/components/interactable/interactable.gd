extends Area2D
class_name InteractableIso

@export var item_name: String = "未命名物品" 
@export var fade_time: float = 0.3  # 渐变时间
@export var label_y_offset: float = -50.0
@export var label_x_offset: float = 0.0

var name_label: Label
var fade_tween: Tween


@export var counter_key: String = ""
@export var dialogues: Array[Resource] = []

var _interaction_count: int = 0
var _resolved_counter_key: String = ""

func interact(player: Player) -> void:
	var picked := _pick_dialogue()
	var json_path: String = String(picked.get("json_path", ""))
	if json_path == "":
		return
	var start_node: String = String(picked.get("start_node", "start"))
	var picked_bubble_target: NodePath = picked.get("bubble_target", NodePath()) as NodePath
	var target_node: Node = _resolve_bubble_target_for(picked_bubble_target, player)
	print("交互触发: ", self.name, " 读取: ", json_path)
	if DialogueManager.load_dialogue(json_path):
		DialogueManager.start_dialogue(start_node, "box", target_node)
	else:
		push_error("Interactable: Failed to load dialogue JSON.")
	_increment_counter()

func prepare_to_interact() -> void:
	_animate_label_alpha(1.0)

func leave_from_interact() -> void:
	_animate_label_alpha(0.0)

# func _on_body_entered(body):
# 	if body.is_in_group("player") and name_label:
# 		_animate_label_alpha(1.0)

# func _on_body_exited(body):
# 	if body.is_in_group("player") and name_label:
# 		_animate_label_alpha(0.0)
		
		
func _animate_label_alpha(target_alpha: float):
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	# 我们只渐变 modulate 里的 a (Alpha) 通道，不影响文字原本的颜色
	fade_tween.tween_property(name_label, "modulate:a", target_alpha, fade_time)

func _ready() -> void:
	add_to_group("interactables")
	_resolved_counter_key = counter_key.strip_edges()
	if _resolved_counter_key == "":
		_resolved_counter_key = self.name
	_load_counter()
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
		name_label.position.x = label_x_offset
		
		# 自动生成无视夜间滤镜的材质
		var unshaded_mat = CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		name_label.material = unshaded_mat
	else:
		# 如果是手动放的，也把名字更新一下
		name_label.text = item_name
		name_label.position.y = label_y_offset
		name_label.position.x = label_x_offset
	
	name_label.modulate = Color(1, 1, 1, 0)

func _resolve_bubble_target_for(path: NodePath, player: Player) -> Node:
	if path != NodePath():
		var n := get_node_or_null(path)
		if n != null:
			return n
	if player != null:
		return player
	return null

func _pick_dialogue() -> Dictionary:
	if dialogues.is_empty():
		return {}
	var idx: int = _interaction_count
	if idx >= dialogues.size():
		idx = dialogues.size() - 1
	var entry: Resource = dialogues[idx]
	if entry == null:
		return {}
	return {
		"json_path": String(entry.get("json_path")),
		"start_node": String(entry.get("start_node")),
		"bubble_target": entry.get("bubble_target")
	}

func _counter_trace_key() -> String:
	if _resolved_counter_key == "":
		return ""
	return "interactable_count:" + _resolved_counter_key

func _load_counter() -> void:
	_interaction_count = 0
	var k: String = _counter_trace_key()
	if k == "":
		return
	var v: Variant = GameState.get_trace(k)
	if typeof(v) == TYPE_INT:
		_interaction_count = int(v)
	elif typeof(v) == TYPE_FLOAT:
		_interaction_count = int(v)

func _increment_counter() -> void:
	_interaction_count += 1
	var k: String = _counter_trace_key()
	if k == "":
		return
	GameState.set_trace(k, _interaction_count)
