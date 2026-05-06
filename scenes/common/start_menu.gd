extends Control

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var save_panel = $SavePanel

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	continue_btn.disabled = not SaveManager.has_any_save()

func _on_start_pressed() -> void:
	start_btn.disabled = true
	continue_btn.disabled = true
	quit_btn.disabled = true

	if GameState.has_method("reset_game"):
		GameState.reset_game()

	print("MainMenu: 请求切图到第一关 ->chapter_1_alley.tscn")
	SceneManager.change_scene("res://scenes/chapter_1/chapter_1_alley.tscn", "SpawnPoint_Alley", 1.0)

func _on_continue_pressed() -> void:
	save_panel.open_load_mode()

func _on_quit_pressed() -> void:
	get_tree().quit()
