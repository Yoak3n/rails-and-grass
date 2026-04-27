extends Node


var session_history: Array[Dictionary] = []
var _history_bbcode_strip_regex: RegEx = null

# （可选）添加一个清理历史的方法，可以在 SceneManager 切换场景时调用
func clear_history() -> void:
	session_history.clear()

func _filter_history_text(raw_text: String) -> String:
	if raw_text == "":
		return ""
	if _history_bbcode_strip_regex == null:
		_history_bbcode_strip_regex = RegEx.new()
		_history_bbcode_strip_regex.compile("\\[\\/?[A-Za-z][^\\]]*\\]")
	var filtered: String = _history_bbcode_strip_regex.sub(raw_text, "", true)
	# 替换换行符为逗号，确保在气泡中显示正常
	filtered = filtered.replace("\n", ",")
	return filtered.strip_edges()

# =================== 信号 ========================
# presentation 参数，告诉 UI 层用什么形式展示（比如弹窗还是头顶气泡）
signal text_ready(speaker: String, text: String, presentation: String, target: Node, next_node_id: String, duration: float)
# 当选项准备就绪时发送，UI 层监听并生成按钮
signal options_ready(options: Array)
# 触发特殊视觉/声音效果的信号
signal taboo_triggered(original_text: String, replacement_text: String, presentation: String)
# 隐藏数值变动（例如：增加沉默次数、痛感值等）
signal state_changed(state_key: String, value_change: int)
# 对话树结束时发送
signal dialogue_ended

# 核心状态
var _current_dialogue: Dictionary = {}
var _current_node_id: String = ""

# 表现形式常量
const PRESENTATION_BOX := "box"
const PRESENTATION_MONOLOGUE := "monologue"
const PRESENTATION_GHOST := "ghost"

# 当前默认的表现形式与目标节点
var _default_presentation: String = PRESENTATION_BOX
var _default_target: Node = null
var _active_presentation: String = PRESENTATION_BOX

func _ready() -> void:
	add_to_group("dialogue_manager")

# 加载指定路径的 JSON 对话文件
func load_dialogue(json_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		push_error("Dialogue file not found: ", json_path)
		return false
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return false
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error == OK:
		var result = json.data
		if typeof(result) == TYPE_DICTIONARY:
			_current_dialogue = result
			return true
	push_error("Failed to parse JSON dialogue: ", json.get_error_message())
	return false

# 启动对话，可以指定全局默认的展示形式和目标
func start_dialogue(start_node: String = "start", presentation: String = PRESENTATION_BOX, target: Node = null) -> void:
	if _current_dialogue.is_empty():
		push_error("No dialogue loaded.")
		return
	
	_default_presentation = presentation
	_default_target = target
	_go_to_node(start_node)

# 处理玩家的选项选择（由 UI 层调用）
func select_option(option_data: Dictionary) -> void:
	# 1. 处理数值变动
	if option_data.has("effect"):
		_handle_effect(option_data["effect"])
	# 2. 检查是否为“禁忌选项”
	var opt_type = option_data.get("type", "normal")
	if opt_type == "taboo":
		var orig_text = option_data.get("original_text", "???")
		var repl_text = option_data.get("text", "...")
		# 保存 next 节点，UI 演出结束后由 UI 调用 proceed_after_taboo()
		_current_node_id = option_data.get("next", "") 
		taboo_triggered.emit(orig_text, repl_text, _active_presentation)
		if repl_text != "":
			session_history.append({
				"speaker": "程砚",
				"text": _filter_history_text(String(repl_text))
			})
		return

	# 3. 正常跳转
	var choice = option_data.get("text","...")
	if choice != "":
		session_history.append({
			"speaker": "程砚",
			"text": _filter_history_text(String(choice))
		})
	var next_node = option_data.get("next", "")
	if next_node == "":
		dialogue_ended.emit()
	else:
		_go_to_node(next_node)

# UI 层完成禁忌演出后，调用此方法继续对话流程
func proceed_after_taboo() -> void:
	if _current_node_id == "":
		dialogue_ended.emit()
	else:
		_go_to_node(_current_node_id)

# 动态改变默认表现形式
func set_presentation(presentation: String, target: Node = null) -> void:
	_default_presentation = presentation
	_default_target = target

# =========  内部方法 ===========
# 跳转到指定节点并解析数据
func _go_to_node(node_id: String) -> void:
	if not _current_dialogue.has(node_id):
		push_error("Node ID not found: ", node_id)
		dialogue_ended.emit()
		return
		
	_current_node_id = node_id
	var node_data = _current_dialogue[node_id]
	
	# 优先使用节点指定的表现形式，否则使用默认
	_active_presentation = String(node_data.get("presentation", _default_presentation))
	
	var speaker = node_data.get("speaker", "")
	var text = node_data.get("text", "")
	var next_node_id = node_data.get("next_node", "")
	var duration: float = float(node_data.get("duration", 3))
	# 发射信号，把文本、说话人、表现形式、目标节点统统交给 UI 层去烦恼
	text_ready.emit(speaker, text, _active_presentation, _default_target, next_node_id, duration)
	if text != "":
		session_history.append({
			"speaker": speaker,
			"text": _filter_history_text(String(text))
		})
	# 如果节点本身带有效果
	if node_data.has("effect"):
		var o = node_data["effect"].split("|",false,1)
		if o.size()== 2:
			_handle_effect(o[0],o[1])
		else:
			_handle_effect(o[0])
		
	var options = node_data.get("options", [])
	if options.size() == 0:
		options_ready.emit([])
		 
	else:
		options_ready.emit(options)
		
# 处理隐藏数值变化
func _handle_effect(effect_name: String,value :int = 0) -> void:
	match effect_name:
		"increase_silence":
			state_changed.emit("silence_count", 1)
			print("【隐藏属性变动】沉默次数 + 1")
		"increase_pain":
			state_changed.emit("pain_value", 1)
			print("【隐藏属性变动】系统排斥痛感 + 1")
		_:
			state_changed.emit(effect_name, value)
