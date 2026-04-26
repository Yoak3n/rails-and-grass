extends Control

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# 连接按钮信号
	start_btn.pressed.connect(_on_start_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	# 如果你在主菜单放了一首 BGM，可以在这里播放
	# AudioManager.play_music("res://assets/audio/bgm/menu_theme.ogg")

func _on_start_pressed() -> void:
	# 1. 禁用所有按钮，防止玩家手抖狂点多次
	start_btn.disabled = true
	quit_btn.disabled = true
	
	# 2. 如果你有全局进度，现在是时候清空它，准备新游戏
	if GameState.has_method("reset_game"):
		GameState.reset_game()
		
	# 3. 将接力棒交给全局管家 SceneManager
	# 这里的意思是：用 2.0 秒慢慢变黑，然后加载 main_iso.tscn，把玩家传送到 "SpawnPoint_Alley"
	print("MainMenu: 请求切图到第一关 -> main.tscn")
	SceneManager.change_scene("res://scenes/chapter_1/chapter1_alley.tscn", "SpawnPoint_Alley", 2.0)

func _on_quit_pressed() -> void:
	# 优雅退出游戏
	get_tree().quit()
