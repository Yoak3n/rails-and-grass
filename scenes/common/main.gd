extends Node2D
class_name MainIso

# 引用玩家，方便传送
@onready var player: Player = $PlayerRng
@onready var camera = $PlayerRng/Camera2D
@onready var dialogue_ui = $CanvasLayer/DialogueUI

func _ready() -> void:
	# 【核心切图逻辑：读取出生点并传送】
	_setup_spawn_point()
	
	# 【开场动画或强制剧情】
	# 监听 SceneManager 的淡入完成信号，画面一亮起，我们就播放一段开场
	if SceneManager.transition_finished.is_connected(_on_level_entered):
		SceneManager.transition_finished.disconnect(_on_level_entered)
	SceneManager.transition_finished.connect(_on_level_entered, CONNECT_ONE_SHOT)
	
	# 监听禁忌选项的触发信号（这里只保留【特定于当前关卡】的演出，比如屏幕震动）
	# 如果所有关卡的震动逻辑都一样，你甚至可以把它移到 DialogueUI 里，或者写个通用的相机组件
	DialogueManager.taboo_triggered.connect(_on_taboo_triggered)

# --- 关卡流初始化 ---

func _setup_spawn_point() -> void:
	# 检查 SceneManager 是否携带了目的地指令
	var spawn_name = SceneManager.next_spawn_point
	print("Level Ready: 尝试寻找出生点 -> ", spawn_name)
	
	if spawn_name != "":
		# 在场景树中寻找名叫这个字符串的节点（通常是一个空的 Marker2D）
		var spawn_node = find_child(spawn_name, true, false)
		if spawn_node and spawn_node is Node2D:
			# 找到出生点，瞬间把玩家传送过去！
			player.global_position = spawn_node.global_position
			print("Level Ready: 玩家已传送到 -> ", spawn_node.global_position)
		else:
			print("Level Ready: 未找到该出生点节点，玩家保持默认位置。")

func _on_level_entered() -> void:
	print("Level Entered: 黑屏淡入结束，画面亮起。游戏正式开始！")
	
	# 关卡开场逻辑，比如自动触发一段内心独白
	# DialogueManager.load_dialogue("res://dialogues/day1_intro.json")
	# DialogueManager.start_dialogue("start", "monologue", player)

# --- 关卡特有演出 ---

func _on_taboo_triggered(_orig: String, _repl: String, _pres: String) -> void:
	
	# 禁忌触发时，本关卡相机特有的剧烈震动表现
	# （文字碎裂和红屏闪烁已经由 dialogue_ui 负责了）
	var orig_pos = camera.position
	var tween_shake = create_tween().set_loops(10)
	tween_shake.tween_property(camera, "position", orig_pos + Vector2(10, -10), 0.05)
	tween_shake.tween_property(camera, "position", orig_pos + Vector2(-10, 10), 0.05)
	tween_shake.finished.connect(func(): camera.position = orig_pos)
