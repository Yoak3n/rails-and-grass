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
	var spawn_name = SceneManager.next_spawn_point
	print("Level Ready: 尝试寻找出生点 -> ", spawn_name)

	if spawn_name == "__saved_pos__":
		player.global_position = SceneManager._saved_load_position
		SceneManager.next_spawn_point = ""
		SceneManager._saved_load_position = Vector2.ZERO
		print("Level Ready: 玩家已从存档位置恢复 -> ", player.global_position)
	elif spawn_name != "":
		var spawn_node = find_child(spawn_name, true, false)
		if spawn_node and spawn_node is Node2D:
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
