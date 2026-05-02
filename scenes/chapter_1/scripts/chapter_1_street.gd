extends Node

@onready var player: Player = $PlayerRng
@onready var camera = $PlayerRng/Camera2D
@onready var dialogue_ui = $CanvasLayer/DialogueUI
func _ready() -> void:
	GameUI.show_ui()
	dialogue_ui.visible = true
	if SceneManager.transition_finished.is_connected(_on_level_entered):
		SceneManager.transition_finished.disconnect(_on_level_entered)
	SceneManager.transition_finished.connect(_on_level_entered, CONNECT_ONE_SHOT)
	SceneManager.before_leave.connect(_before_level_leave, CONNECT_ONE_SHOT)
	CutsceneManager.register_json("1", "res://cutscenes/chapter_1/umbrella_overhead.json")
	

func _on_level_entered() -> void:
	print("Level Entered: 黑屏淡入结束，画面亮起。游戏正式开始！")
	GameUI.show_ui()
	# 关卡开场逻辑，比如自动触发一段内心独白
	# DialogueManager.load_dialogue("res://dialogues/day1_intro.json")
	# DialogueManager.start_dialogue("start", "monologue", player)

func _before_level_leave() -> void:
	GameUI.hide_ui()
