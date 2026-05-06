extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var cheng_yan: Player = $ChengYan
@onready var camera_2d: Camera2D = $Camera2D
@onready var dialogue_ui = $CanvasLayer/DialogueUI

var flashback = preload("res://core/components/effects/cutscene/image_flashback.gd").new()
func _ready() -> void:
	add_child(flashback)
	camera_2d.make_current()
	animation_player.play("chapter1_end")
	dialogue_ui.visible = true
	cheng_yan.can_move = false

func show_monolgue():
	DialogueManager.load_dialogue("res://dialogues/chapter_1/day2_end.json")
	DialogueManager.start_dialogue("monologue")

func play_flashback():
	flashback.start({"image": "res://assets/pictures/moon_night/orig.png", "hold": 0.5,"shake": 0.5})
	await flashback.finished
	SceneManager.change_scene("res://scenes/chapter_1/chapter_1_street.tscn")
