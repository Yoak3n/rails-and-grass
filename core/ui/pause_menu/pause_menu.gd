extends Control

@onready var quit = $HBoxContainer/Quit
@onready var resume_btn = $HBoxContainer/Continue
@onready var save_btn = $HBoxContainer/SaveButton
@onready var load_btn = $HBoxContainer/LoadButton
@onready var save_panel = $SavePanel

var _save_panel_open: bool = false

func _ready() -> void:
	hide()
	quit.pressed.connect(_on_quit_pressed)
	resume_btn.pressed.connect(_on_continue_pressed)
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	save_panel.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _save_panel_open:
			_close_save_panel()
			get_viewport().set_input_as_handled()
		else:
			toggle_pause()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	SceneManager.change_scene("res://scenes/common/start_menu.tscn", "", 0.0)

func _on_continue_pressed() -> void:
	toggle_pause()

func _on_save_pressed() -> void:
	save_panel.open_save_mode()
	_save_panel_open = true

func _on_load_pressed() -> void:
	save_panel.open_load_mode()
	_save_panel_open = true

func _close_save_panel() -> void:
	save_panel.hide_panel()
	_save_panel_open = false

func toggle_pause() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	if not new_pause_state:
		_save_panel_open = false
		save_panel.hide_panel()
