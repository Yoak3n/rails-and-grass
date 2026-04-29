extends Node2D

@onready var player: Player = $PlayerRng
@onready var camera = $PlayerRng/Camera2D
@onready var dialogue_ui = $CanvasLayer/DialogueUI

func _ready() -> void:
	if SceneManager.transition_finished.is_connected(_on_level_entered):
		SceneManager.transition_finished.disconnect(_on_level_entered)
	SceneManager.transition_finished.connect(_on_level_entered, CONNECT_ONE_SHOT)
	SceneManager.before_leave.connect(_before_level_leave, CONNECT_ONE_SHOT)
	

func _on_level_entered() -> void:
	print("Level Entered: 黑屏淡入结束，画面亮起。游戏正式开始！")
	GameUI.show_ui()
	# 关卡开场逻辑，比如自动触发一段内心独白
	# DialogueManager.load_dialogue("res://dialogues/day1_intro.json")
	# DialogueManager.start_dialogue("start", "monologue", player)

func _before_level_leave() -> void:
	GameUI.hide_ui()

# --- 关卡特有演出 ---

func _on_taboo_triggered(_orig: String, _repl: String, _pres: String) -> void:
	
	# 禁忌触发时，本关卡相机特有的剧烈震动表现
	# （文字碎裂和红屏闪烁已经由 dialogue_ui 负责了）
	var orig_pos = camera.position
	var tween_shake = create_tween().set_loops(10)
	tween_shake.tween_property(camera, "position", orig_pos + Vector2(10, -10), 0.05)
	tween_shake.tween_property(camera, "position", orig_pos + Vector2(-10, 10), 0.05)
	tween_shake.finished.connect(func(): camera.position = orig_pos)
