extends Node

const SAVE_DIR := "user://saves/"
const MAX_MANUAL_SLOTS := 10
const MAX_AUTO_SLOTS := 3
const SAVE_VERSION := 1
const AUTO_SAVE_INTERVAL := 600.0

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, error: String)
signal load_failed(slot: int, error: String)

var _auto_save_index: int = 0
var _auto_save_timer: Timer
var _auto_save_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_dir()
	_load_auto_index()
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = false
	_auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	add_child(_auto_save_timer)

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# ── 手动存档 ──────────────────────────────────────────────

func _manual_save_path(slot: int) -> String:
	return SAVE_DIR + "manual_slot_%d.json" % slot

func _manual_thumb_path(slot: int) -> String:
	return SAVE_DIR + "manual_slot_%d.png" % slot

func has_manual_save(slot: int) -> bool:
	return FileAccess.file_exists(_manual_save_path(slot))

func get_manual_save_info(slot: int) -> Dictionary:
	return _read_json_file(_manual_save_path(slot))

func get_all_manual_save_infos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_MANUAL_SLOTS):
		result.append(get_manual_save_info(i))
	return result

func save_manual(slot: int) -> void:
	_ensure_save_dir()
	var save_data := _collect_save_data()
	save_data["slot"] = slot
	save_data["type"] = "manual"
	var json_str := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(_manual_save_path(slot), FileAccess.WRITE)
	if file == null:
		var err_msg := "无法写入存档文件: %s" % _manual_save_path(slot)
		push_error(err_msg)
		save_failed.emit(slot, err_msg)
		return
	file.store_string(json_str)
	file.close()
	await _save_thumbnail(_manual_thumb_path(slot))
	save_completed.emit(slot)
	print("SaveManager: 手动存档成功 -> 槽位 %d" % slot)

func load_manual(slot: int) -> void:
	var save_data := get_manual_save_info(slot)
	if save_data.is_empty():
		var err_msg := "存档槽位 %d 无数据" % slot
		push_error(err_msg)
		load_failed.emit(slot, err_msg)
		return
	_apply_save_data(save_data)
	load_completed.emit(slot)
	print("SaveManager: 读取手动存档 -> 槽位 %d" % slot)

func delete_manual_save(slot: int) -> void:
	_delete_file(_manual_save_path(slot))
	_delete_file(_manual_thumb_path(slot))
	print("SaveManager: 已删除手动存档 -> 槽位 %d" % slot)

func get_manual_thumbnail(slot: int) -> ImageTexture:
	return _load_texture(_manual_thumb_path(slot))

# ── 自动存档（滚动淘汰制） ─────────────────────────────────

func _auto_save_path(index: int) -> String:
	return SAVE_DIR + "auto_slot_%d.json" % index

func _auto_thumb_path(index: int) -> String:
	return SAVE_DIR + "auto_slot_%d.png" % index

func _auto_index_meta_path() -> String:
	return SAVE_DIR + "auto_index.meta"

func _load_auto_index() -> void:
	var path := _auto_index_meta_path()
	if not FileAccess.file_exists(path):
		_auto_save_index = 0
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_auto_save_index = 0
		return
	_auto_save_index = int(file.get_as_text().strip_edges())
	file.close()

func _save_auto_index() -> void:
	var file := FileAccess.open(_auto_index_meta_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(str(_auto_save_index))
	file.close()

func has_auto_save(index: int) -> bool:
	return FileAccess.file_exists(_auto_save_path(index))

func get_auto_save_info(index: int) -> Dictionary:
	return _read_json_file(_auto_save_path(index))

func get_all_auto_save_infos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_AUTO_SLOTS):
		result.append(get_auto_save_info(i))
	return result

func get_auto_thumbnail(index: int) -> ImageTexture:
	return _load_texture(_auto_thumb_path(index))

func start_auto_save() -> void:
	_auto_save_enabled = true
	_auto_save_timer.start()
	print("SaveManager: 自动存档已启用，间隔 %d 秒" % int(AUTO_SAVE_INTERVAL))

func stop_auto_save() -> void:
	_auto_save_enabled = false
	_auto_save_timer.stop()
	print("SaveManager: 自动存档已停止")

func do_auto_save() -> void:
	_ensure_save_dir()
	var save_data := _collect_save_data()
	save_data["slot"] = _auto_save_index
	save_data["type"] = "auto"
	var json_str := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(_auto_save_path(_auto_save_index), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入自动存档 -> 槽位 %d" % _auto_save_index)
		return
	file.store_string(json_str)
	file.close()
	await _save_thumbnail(_auto_thumb_path(_auto_save_index))
	print("SaveManager: 自动存档完成 -> 槽位 %d" % _auto_save_index)
	_auto_save_index = (_auto_save_index + 1) % MAX_AUTO_SLOTS
	_save_auto_index()

func load_auto(index: int) -> void:
	var save_data := get_auto_save_info(index)
	if save_data.is_empty():
		push_error("SaveManager: 自动存档 %d 无数据" % index)
		return
	_apply_save_data(save_data)
	load_completed.emit(-1 - index)
	print("SaveManager: 读取自动存档 -> 槽位 %d" % index)

func delete_auto_save(index: int) -> void:
	_delete_file(_auto_save_path(index))
	_delete_file(_auto_thumb_path(index))

func has_any_save() -> bool:
	for i in range(MAX_MANUAL_SLOTS):
		if has_manual_save(i):
			return true
	for i in range(MAX_AUTO_SLOTS):
		if has_auto_save(i):
			return true
	return false

func _on_auto_save_timer_timeout() -> void:
	if not _auto_save_enabled:
		return
	if get_tree().paused:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := current_scene.scene_file_path
	if scene_path == "res://scenes/common/start_menu.tscn":
		return
	do_auto_save()

# ── 数据收集与恢复 ────────────────────────────────────────

func _collect_save_data() -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"scene_path": "",
		"spawn_point": "",
		"game_state": {},
		"dialogue_history": [],
		"player_position": {"x": 0, "y": 0}
	}

	var current_scene := get_tree().current_scene
	if current_scene != null:
		data["scene_path"] = current_scene.scene_file_path

	data["spawn_point"] = SceneManager.next_spawn_point
	data["game_state"] = GameState.traces.duplicate(true)
	data["dialogue_history"] = DialogueManager.session_history.duplicate(true)

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p is Node2D:
			var pos: Vector2 = (p as Node2D).global_position
			data["player_position"] = {"x": pos.x, "y": pos.y}

	return data

func _apply_save_data(data: Dictionary) -> void:
	var game_state_data: Variant = data.get("game_state", {})
	if game_state_data is Dictionary:
		GameState.traces = (game_state_data as Dictionary).duplicate(true)

	var history_data: Variant = data.get("dialogue_history", [])
	if history_data is Array:
		DialogueManager.session_history.clear()
		for item in history_data:
			if item is Dictionary:
				DialogueManager.session_history.append(item as Dictionary)

	var scene_path: String = String(data.get("scene_path", ""))
	var spawn_point: String = String(data.get("spawn_point", ""))

	if scene_path == "":
		push_error("SaveManager: 存档中无场景路径，无法读档。")
		return

	var player_pos: Variant = data.get("player_position", null)
	if player_pos is Dictionary:
		var pos_dict: Dictionary = player_pos as Dictionary
		SceneManager.next_spawn_point = "__saved_pos__"
		SceneManager._saved_load_position = Vector2(float(pos_dict.get("x", 0)), float(pos_dict.get("y", 0)))
	else:
		SceneManager.next_spawn_point = spawn_point
		SceneManager._saved_load_position = Vector2.ZERO

	SceneManager.change_scene(scene_path, SceneManager.next_spawn_point, 1.0)
	stop_auto_save()

# ── 文件工具 ──────────────────────────────────────────────

func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	return {}

func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _save_thumbnail(path: String) -> void:
	var img: Image = await _capture_viewport_image()
	if img == null:
		return
	img.save_png(path)

func _load_texture(path: String) -> ImageTexture:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

func _capture_viewport_image() -> Image:
	await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	if viewport == null:
		return null
	var image := viewport.get_texture().get_image()
	if image == null:
		return null
	image.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	return image

func format_timestamp(iso_string: String) -> String:
	if iso_string == "":
		return ""
	var parts := iso_string.split("T")
	if parts.size() < 2:
		return iso_string
	var date_part := parts[0]
	var time_part := parts[1]
	var date_splits := date_part.split("-")
	var time_splits := time_part.split(":")
	if date_splits.size() >= 3 and time_splits.size() >= 2:
		return "%s/%s/%s %s:%s" % [date_splits[0], date_splits[1], date_splits[2], time_splits[0], time_splits[1]]
	return iso_string
