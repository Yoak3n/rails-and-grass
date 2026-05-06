extends PanelContainer

enum Mode { SAVE, LOAD }

var _mode: Mode = Mode.LOAD

@onready var _title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var _close_btn: Button = $MarginContainer/VBoxContainer/Header/CloseButton
@onready var _slot_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SlotContainer
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog

var _pending_action_id: String = ""

func _ready() -> void:
	_close_btn.pressed.connect(hide_panel)
	_setup_confirm_dialog()
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)

func _setup_confirm_dialog() -> void:
	_confirm_dialog.dialog_text = ""
	_confirm_dialog.confirmed.connect(_on_confirm_action)
	_confirm_dialog.get_ok_button().text = "确定"
	_confirm_dialog.add_cancel_button("取消")

func open_save_mode() -> void:
	_mode = Mode.SAVE
	_title_label.text = "保存游戏"
	_refresh_slots()
	show()

func open_load_mode() -> void:
	_mode = Mode.LOAD
	_title_label.text = "读取存档"
	_refresh_slots()
	show()

func hide_panel() -> void:
	hide()

func _refresh_slots() -> void:
	for child in _slot_container.get_children():
		child.queue_free()

	if _mode == Mode.LOAD:
		_build_auto_save_section()

	_build_manual_save_section()

func _build_auto_save_section() -> void:
	var has_any := false
	for i in range(SaveManager.MAX_AUTO_SLOTS):
		if SaveManager.has_auto_save(i):
			has_any = true
			break
	if not has_any:
		return

	var header := Label.new()
	header.text = "── 自动存档 ──"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	_slot_container.add_child(header)

	for i in range(SaveManager.MAX_AUTO_SLOTS - 1, -1, -1):
		if not SaveManager.has_auto_save(i):
			continue
		var info := SaveManager.get_auto_save_info(i)
		var item := _create_slot_item("auto_%d" % i, info, "auto")
		_slot_container.add_child(item)

func _build_manual_save_section() -> void:
	var header := Label.new()
	header.text = "── 手动存档 ──"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	_slot_container.add_child(header)

	var all_saves := SaveManager.get_all_manual_save_infos()
	for i in range(SaveManager.MAX_MANUAL_SLOTS):
		var item := _create_slot_item("manual_%d" % i, all_saves[i], "manual")
		_slot_container.add_child(item)

func _create_slot_item(id: String, data: Dictionary, save_type: String) -> Control:
	var item := PanelContainer.new()
	item.custom_minimum_size = Vector2(0, 80)

	var h_box := HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 10)
	item.add_child(h_box)

	var thumb_rect := _create_thumb_rect(id, save_type)
	h_box.add_child(thumb_rect)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	h_box.add_child(info_vbox)

	var slot_label := Label.new()
	slot_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(slot_label)

	var time_label := Label.new()
	time_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(time_label)

	var scene_label := Label.new()
	scene_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(scene_label)

	var slot_index := _get_index_from_id(id)

	if data.is_empty():
		if save_type == "manual":
			slot_label.text = "存档 %d —— 空" % (slot_index + 1)
		else:
			slot_label.text = "自动存档 %d —— 空" % (slot_index + 1)
		time_label.text = ""
		scene_label.text = ""
	else:
		if save_type == "manual":
			slot_label.text = "存档 %d" % (slot_index + 1)
		else:
			slot_label.text = "自动存档 %d" % (slot_index + 1)
		var ts: String = String(data.get("timestamp", ""))
		time_label.text = SaveManager.format_timestamp(ts)
		scene_label.text = _get_scene_display_name(String(data.get("scene_path", "")))

	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 4)
	h_box.add_child(btn_container)

	if save_type == "manual" and _mode == Mode.SAVE:
		var save_btn := Button.new()
		save_btn.custom_minimum_size = Vector2(80, 0)
		save_btn.text = "保存" if data.is_empty() else "覆盖"
		save_btn.pressed.connect(_on_action_pressed.bind(id, "save"))
		btn_container.add_child(save_btn)

	if not data.is_empty():
		if _mode == Mode.LOAD or save_type == "auto":
			var load_btn := Button.new()
			load_btn.custom_minimum_size = Vector2(80, 0)
			load_btn.text = "读取"
			load_btn.pressed.connect(_on_action_pressed.bind(id, "load"))
			btn_container.add_child(load_btn)

	if not data.is_empty():
		var del_btn := Button.new()
		del_btn.custom_minimum_size = Vector2(80, 0)
		del_btn.text = "删除"
		del_btn.pressed.connect(_on_action_pressed.bind(id, "delete"))
		btn_container.add_child(del_btn)

	return item

func _create_thumb_rect(id: String, save_type: String) -> TextureRect:
	var thumb_rect := TextureRect.new()
	thumb_rect.custom_minimum_size = Vector2(128, 72)
	thumb_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	var tex: ImageTexture = null
	if save_type == "auto":
		var idx := _get_index_from_id(id)
		tex = SaveManager.get_auto_thumbnail(idx)
	else:
		var idx := _get_index_from_id(id)
		tex = SaveManager.get_manual_thumbnail(idx)

	if tex != null:
		thumb_rect.texture = tex
	else:
		var placeholder := ColorRect.new()
		thumb_rect.add_child(placeholder)
		placeholder.color = Color(0.15, 0.15, 0.2, 1)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return thumb_rect

func _get_index_from_id(id: String) -> int:
	var parts := id.split("_")
	if parts.size() >= 2:
		return int(parts[1])
	return 0

func _get_save_type_from_id(id: String) -> String:
	return id.split("_")[0]

func _get_scene_display_name(scene_path: String) -> String:
	if scene_path == "":
		return ""
	var file_name := scene_path.get_file().get_basename()
	var display_map := {
		"chapter_1_alley": "第一章 · 小巷",
		"chapter_1_street": "第一章 · 街道",
		"chapter_1_end": "第一章 · 终章",
		"start_menu": "主菜单"
	}
	if display_map.has(file_name):
		return display_map[file_name]
	return file_name

func _on_action_pressed(id: String, action: String) -> void:
	var save_type := _get_save_type_from_id(id)
	var slot_index := _get_index_from_id(id)

	match action:
		"save":
			if save_type == "manual" and SaveManager.has_manual_save(slot_index):
				_pending_action_id = id + ":overwrite"
				_confirm_dialog.dialog_text = "存档 %d 已有数据，确定要覆盖吗？" % (slot_index + 1)
				_confirm_dialog.popup_centered()
			else:
				SaveManager.save_manual(slot_index)
				_refresh_slots()
		"load":
			_pending_action_id = id + ":load"
			var label := "自动存档 %d" % (slot_index + 1) if save_type == "auto" else "存档 %d" % (slot_index + 1)
			_confirm_dialog.dialog_text = "确定要读取%s吗？\n当前未保存的进度将会丢失。" % label
			_confirm_dialog.popup_centered()
		"delete":
			_pending_action_id = id + ":delete"
			var label := "自动存档 %d" % (slot_index + 1) if save_type == "auto" else "存档 %d" % (slot_index + 1)
			_confirm_dialog.dialog_text = "确定要删除%s吗？\n此操作不可撤销。" % label
			_confirm_dialog.popup_centered()

func _on_confirm_action() -> void:
	var id := _pending_action_id
	_pending_action_id = ""
	if id == "":
		return

	var parts := id.split(":")
	if parts.size() < 2:
		return
	var slot_id := parts[0]
	var action := parts[1]
	var save_type := _get_save_type_from_id(slot_id)
	var slot_index := _get_index_from_id(slot_id)

	match action:
		"overwrite":
			SaveManager.save_manual(slot_index)
			_refresh_slots()
		"load":
			if save_type == "auto":
				SaveManager.load_auto(slot_index)
			else:
				SaveManager.load_manual(slot_index)
		"delete":
			if save_type == "auto":
				SaveManager.delete_auto_save(slot_index)
			else:
				SaveManager.delete_manual_save(slot_index)
			_refresh_slots()

func _on_save_completed(_slot: int) -> void:
	_refresh_slots()

func _on_load_completed(_slot: int) -> void:
	hide_panel()
