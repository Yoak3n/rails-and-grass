extends Area2D
class_name TeleportInteractableIso

@export var item_name: String = "未命名目的地"
@export var fade_time: float = 0.3
@export var label_y_offset: float = -50.0

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_point: String = ""
@export var confirm_title: String = "确认"
@export var confirm_text: String = "要前往下一个区域吗？"
@export var scene_fade_duration: float = 1.0

var name_label: Label
var fade_tween: Tween
var _confirm_dialog: ConfirmationDialog = null
var _confirm_player: Player = null
var _confirming: bool = false

func _ready() -> void:
	add_to_group("interactables")
	for child in get_children():
		if child is Label:
			name_label = child
			break

	if not name_label:
		name_label = Label.new()
		add_child(name_label)
		name_label.text = item_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		name_label.position.y = label_y_offset
		var unshaded_mat := CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		name_label.material = unshaded_mat
	else:
		name_label.text = item_name

	name_label.modulate = Color(1, 1, 1, 0)

func interact(player: Player) -> void:
	if _confirming:
		return
	if target_scene_path == "":
		return
	_confirm_player = player
	_confirm_player.can_move = false
	_confirming = true
	_ensure_confirm_dialog()
	_confirm_dialog.title = confirm_title
	_confirm_dialog.dialog_text = confirm_text
	_confirm_dialog.popup_centered()

func _ensure_confirm_dialog() -> void:
	if _confirm_dialog and is_instance_valid(_confirm_dialog):
		return
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_dialog.exclusive = true
	_confirm_dialog.visible = false
	get_tree().root.add_child(_confirm_dialog)
	_confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	_confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
	_confirm_dialog.popup_hide.connect(_on_confirm_dialog_popup_hide)

func _on_confirm_dialog_confirmed() -> void:
	_confirming = false
	SceneManager.change_scene(target_scene_path, target_spawn_point, scene_fade_duration)

func _on_confirm_dialog_canceled() -> void:
	_confirming = false
	var p := _confirm_player
	_confirm_player = null
	if p and is_instance_valid(p):
		p.can_move = true

func _on_confirm_dialog_popup_hide() -> void:
	if not _confirming:
		return
	_on_confirm_dialog_canceled()

func prepare_to_interact() -> void:
	_animate_label_alpha(1.0)

func leave_from_interact() -> void:
	_animate_label_alpha(0.0)

func _animate_label_alpha(target_alpha: float) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(name_label, "modulate:a", target_alpha, fade_time)
