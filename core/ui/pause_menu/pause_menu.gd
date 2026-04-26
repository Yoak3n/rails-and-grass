extends Control

@onready var quit = $HBoxContainer/Quit
@onready var resume_btn = $HBoxContainer/Continue


func _ready() -> void:
	hide()
	quit.pressed.connect(_on_quit_pressed)
	resume_btn.pressed.connect(_on_continue_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func _on_quit_pressed()->void:
	#get_tree().quit()
   # 如果你想退回到主菜单场景，可以改成：
	# get_tree().paused = false # 记得切场景前解除暂停！
	get_tree().change_scene_to_file("res://scenes/common/start_menu.tscn")

func _on_continue_pressed()-> void:
	toggle_pause()

func toggle_pause():
	# 1. 切换引擎的暂停状态（如果是 true 就变 false，反之亦然）
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	# 2. 根据暂停状态，显示或隐藏 UI 界面
	visible = new_pause_state
