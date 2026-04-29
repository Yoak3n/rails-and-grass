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
var _confirm_player: Player = null
var _confirming: bool = false
var _confirm_layer: CanvasLayer = null
var _confirm_root: Control = null
var _confirm_title_label: Label = null
var _confirm_text_label: Label = null
var _confirm_measure_label: Label = null
var _confirm_ok_btn: Button = null
var _confirm_cancel_btn: Button = null

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
	_confirm_player = player
	_confirm_player.can_move = false
	_confirming = true
	_ensure_confirm_ui()
	_show_confirm_ui()

func _on_confirm_dialog_confirmed() -> void:
	if target_scene_path == "":
		return
	_hide_confirm_ui()
	_confirming = false
	var p := _confirm_player
	_confirm_player = null
	if p and is_instance_valid(p):
		p.can_move = true
	SceneManager.change_scene(target_scene_path, target_spawn_point, scene_fade_duration)

func _on_confirm_dialog_canceled() -> void:
	_hide_confirm_ui()
	_confirming = false
	var p := _confirm_player
	_confirm_player = null
	if p and is_instance_valid(p):
		p.can_move = true

func _ensure_confirm_ui() -> void:
	if _confirm_layer and is_instance_valid(_confirm_layer):
		return
	_confirm_layer = CanvasLayer.new()
	_confirm_layer.layer = 200
	_confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.call_deferred("add_child", _confirm_layer)

	var root := Control.new()
	root.name = "TeleportConfirmRoot"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_layer.add_child(root)
	_confirm_root = root

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0, 0, 0, 0.45)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(520, 260)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var title_area := Control.new()
	title_area.name = "TitleArea"
	title_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_area)

	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_area.add_child(title_lbl)
	title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_title_label = title_lbl

	var text_area := Control.new()
	text_area.name = "TextArea"
	text_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_area)

	var text_lbl := Label.new()
	text_lbl.name = "Text"
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_lbl.add_theme_font_size_override("font_size", 20)
	text_area.add_child(text_lbl)
	text_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_text_label = text_lbl

	var measure_lbl := Label.new()
	measure_lbl.name = "Measure"
	measure_lbl.visible = false
	measure_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	measure_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	measure_lbl.add_theme_font_size_override("font_size", 20)
	root.add_child(measure_lbl)
	_confirm_measure_label = measure_lbl

	var button_area := CenterContainer.new()
	button_area.name = "ButtonArea"
	button_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(button_area)

	var hbox := HBoxContainer.new()
	hbox.name = "Buttons"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 14)
	button_area.add_child(hbox)

	var ok := Button.new()
	ok.text = "确认"
	ok.custom_minimum_size = Vector2(120, 40)
	ok.pressed.connect(_on_confirm_dialog_confirmed)
	hbox.add_child(ok)
	_confirm_ok_btn = ok

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.pressed.connect(_on_confirm_dialog_canceled)
	hbox.add_child(cancel)
	_confirm_cancel_btn = cancel

	root.visible = false

func _show_confirm_ui() -> void:
	if not _confirm_root or not is_instance_valid(_confirm_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_confirm_root.position = Vector2.ZERO
	_confirm_root.size = viewport_size
	var dim := _confirm_root.get_node_or_null("Dim") as ColorRect
	if dim:
		dim.position = Vector2.ZERO
		dim.size = viewport_size
	var panel := _confirm_root.get_node_or_null("Panel") as PanelContainer
	if panel:
		var panel_padding_x: float = 48.0
		var panel_min_w: float = 340.0
		var panel_max_w: float = 520.0
		var panel_h: float = 200.0

		var title_w: float = 0.0
		if _confirm_title_label and is_instance_valid(_confirm_title_label):
			_confirm_title_label.text = confirm_title
			title_w = _confirm_title_label.get_minimum_size().x

		var has_target := target_scene_path != ""
		var text_value := confirm_text if has_target else "未配置 target_scene_path，无法传送。"
		if _confirm_text_label:
			_confirm_text_label.text = text_value

		var text_w: float = 0.0
		if _confirm_measure_label and is_instance_valid(_confirm_measure_label):
			_confirm_measure_label.text = text_value
			text_w = _confirm_measure_label.get_minimum_size().x

		var buttons_w: float = 120.0 * 2.0 + 14.0
		var inner_min_w: float = maxf(panel_min_w - panel_padding_x, 0.0)
		var inner_max_w: float = maxf(panel_max_w - panel_padding_x, 0.0)
		var inner_w: float = clampf(maxf(maxf(title_w, text_w), buttons_w), inner_min_w, inner_max_w)
		var panel_w: float = inner_w + panel_padding_x

		panel.size = Vector2(panel_w, panel_h)
		panel.position = viewport_size * 0.5 - panel.size * 0.5

		if _confirm_ok_btn:
			_confirm_ok_btn.disabled = not has_target
	_confirm_root.show()

func _hide_confirm_ui() -> void:
	if _confirm_root and is_instance_valid(_confirm_root):
		_confirm_root.visible = false

func prepare_to_interact() -> void:
	_animate_label_alpha(1.0)

func leave_from_interact() -> void:
	_animate_label_alpha(0.0)

func _animate_label_alpha(target_alpha: float) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(name_label, "modulate:a", target_alpha, fade_time)
