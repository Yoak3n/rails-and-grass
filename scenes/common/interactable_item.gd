extends Area2D

@export var data_json_path: String = ""
@export var data_node: String = ""

var item_name: String = "未命名物品"
var fade_time: float = 0.3
var label_x_offset: float = 0.0
var label_y_offset: float = -50.0
var bubble_target: NodePath = NodePath()
var dialogue_presentation: String = "box"
var counter_key: String = ""

var _interaction_count: int = 0
var _dialogues: Array[Dictionary] = []
var _visual_cfg: Dictionary = {}

var _name_label: Label = null
var _fade_tween: Tween = null

func _ready() -> void:
	add_to_group("interactables")
	_load_and_apply()
	_ensure_name_label()
	_apply_visual()

func interact(player: Player) -> void:
	var picked := _pick_dialogue()
	var json_path: String = String(picked.get("json_path", ""))
	var start_node: String = String(picked.get("start_node", "start"))
	var target_node: Node = _resolve_bubble_target(picked.get("bubble_target", null), player)
	if json_path == "":
		return
	print("交互触发: ", self.name, " 读取: ", json_path)
	if DialogueManager.load_dialogue(json_path):
		DialogueManager.start_dialogue(start_node, "box", target_node)
	else:
		push_error("InteractableItem: Failed to load dialogue JSON.")
	_increment_counter()

func prepare_to_interact() -> void:
	_animate_label_alpha(1.0)

func leave_from_interact() -> void:
	_animate_label_alpha(0.0)

func _ensure_name_label() -> void:
	for child in get_children():
		if child is Label:
			_name_label = child as Label
			break
	if _name_label == null:
		_name_label = Label.new()
		_name_label.name = "NameLabel"
		add_child(_name_label)
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		var unshaded_mat := CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_name_label.material = unshaded_mat
	_name_label.text = item_name
	_name_label.position.x = label_x_offset
	_name_label.position.y = label_y_offset
	_name_label.modulate = Color(1, 1, 1, 0)

func _animate_label_alpha(target_alpha: float) -> void:
	if _name_label == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_name_label, "modulate:a", target_alpha, fade_time)

func _load_json_dict(json_path: String) -> Dictionary:
	if json_path == "":
		return {}
	if not FileAccess.file_exists(json_path):
		return {}
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	return {}

func _get_config_node(db: Dictionary, node_path: String) -> Dictionary:
	var p: String = node_path.strip_edges()
	if p == "":
		return {}
	var cur: Variant = db
	for part in p.split(".", false):
		if cur is Dictionary:
			var d: Dictionary = cur as Dictionary
			if not d.has(part):
				return {}
			cur = d[part]
		else:
			return {}
	if cur is Dictionary:
		return cur as Dictionary
	return {}

func _load_and_apply() -> void:
	item_name = "未命名物品"
	fade_time = 0.3
	label_x_offset = 0.0
	label_y_offset = -50.0
	bubble_target = NodePath()
	dialogue_presentation = "box"
	counter_key = ""
	_dialogues.clear()
	_visual_cfg.clear()
	_interaction_count = 0
	if data_json_path == "" or data_node == "":
		return
	var db: Dictionary = _load_json_dict(data_json_path)
	if db.is_empty():
		return
	var cfg: Dictionary = _get_config_node(db, data_node)
	if cfg.is_empty():
		return
	_apply_config(cfg)
	_load_counter()

func _apply_config(cfg: Dictionary) -> void:
	if cfg.has("item_name"):
		item_name = String(cfg.get("item_name", item_name))
	if cfg.has("fade_time"):
		fade_time = float(cfg.get("fade_time", fade_time))
	var label_cfg_v: Variant = cfg.get("label_offset", null)
	if label_cfg_v is Dictionary:
		var label_cfg: Dictionary = label_cfg_v as Dictionary
		if label_cfg.has("x"):
			label_x_offset = float(label_cfg.get("x", label_x_offset))
		if label_cfg.has("y"):
			label_y_offset = float(label_cfg.get("y", label_y_offset))
	if cfg.has("label_x_offset"):
		label_x_offset = float(cfg.get("label_x_offset", label_x_offset))
	if cfg.has("label_y_offset"):
		label_y_offset = float(cfg.get("label_y_offset", label_y_offset))
	if cfg.has("bubble_target"):
		bubble_target = NodePath(String(cfg.get("bubble_target", "")))
	if cfg.has("counter_key"):
		counter_key = String(cfg.get("counter_key", ""))
	if counter_key == "":
		counter_key = data_node
	var dialogues_v: Variant = cfg.get("dialogues", null)
	if dialogues_v is Array:
		for raw in dialogues_v as Array:
			if raw is Dictionary:
				var d: Dictionary = raw as Dictionary
				_dialogues.append({
					"json_path": String(d.get("json_path", d.get("json", ""))),
					"start_node": String(d.get("start_node", d.get("start", "start"))),
					"bubble_target": d.get("bubble_target", null)
				})
	var visual_v: Variant = cfg.get("visual", null)
	if visual_v is Dictionary:
		_visual_cfg = visual_v as Dictionary

func _apply_visual() -> void:
	if _visual_cfg.is_empty():
		return
	var t: String = String(_visual_cfg.get("type", "sprite2d")).to_lower()
	var node_path_str: String = String(_visual_cfg.get("node_path", ""))
	var node_name: String = String(_visual_cfg.get("node", ""))
	var node: Node = null
	if node_path_str != "":
		node = get_node_or_null(NodePath(node_path_str))
	elif node_name != "":
		node = get_node_or_null(NodePath(node_name))
	if t == "sprite2d":
		var sprite: Sprite2D = null
		if node is Sprite2D:
			sprite = node as Sprite2D
		elif bool(_visual_cfg.get("create_if_missing", true)):
			sprite = Sprite2D.new()
			sprite.name = "Sprite2D"
			add_child(sprite)
		if sprite == null:
			return
		var texture_path: String = String(_visual_cfg.get("texture", ""))
		if texture_path != "":
			var tex := load(texture_path)
			if tex is Texture2D:
				sprite.texture = tex as Texture2D
		var mod_v: Variant = _visual_cfg.get("modulate", null)
		if mod_v is Array:
			var a: Array = mod_v as Array
			if a.size() >= 4:
				sprite.modulate = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	elif t == "polygon2d":
		var poly: Polygon2D = null
		if node is Polygon2D:
			poly = node as Polygon2D
		elif bool(_visual_cfg.get("create_if_missing", true)):
			poly = Polygon2D.new()
			poly.name = "Polygon2D"
			add_child(poly)
		if poly == null:
			return
		var color_v: Variant = _visual_cfg.get("color", null)
		if color_v is Array:
			var c: Array = color_v as Array
			if c.size() >= 4:
				poly.color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		var texture_path: String = String(_visual_cfg.get("texture", ""))
		if texture_path != "":
			var tex := load(texture_path)
			if tex is Texture2D:
				poly.texture = tex as Texture2D
		var points_v: Variant = _visual_cfg.get("polygon", null)
		if points_v is Array:
			var pts: Array = points_v as Array
			var arr := PackedVector2Array()
			for p in pts:
				if p is Array:
					var pa: Array = p as Array
					if pa.size() >= 2:
						arr.append(Vector2(float(pa[0]), float(pa[1])))
			if arr.size() > 0:
				poly.polygon = arr

func _resolve_bubble_target(raw_target: Variant, player: Player) -> Node:
	if raw_target is String:
		var s: String = String(raw_target).strip_edges()
		if s != "":
			var n := get_node_or_null(NodePath(s))
			if n != null:
				return n
	if bubble_target != NodePath():
		var n2 := get_node_or_null(bubble_target)
		if n2 != null:
			return n2
	if player != null:
		return player
	return null

func _pick_dialogue() -> Dictionary:
	if _dialogues.size() > 0:
		var idx: int = _interaction_count
		if idx >= _dialogues.size():
			idx = _dialogues.size() - 1
		return _dialogues[idx]
	return {"json_path": "", "start_node": "start", "bubble_target": null}

func _counter_trace_key() -> String:
	if counter_key == "":
		return ""
	return "interactable_count:" + counter_key

func _load_counter() -> void:
	_interaction_count = 0
	var k: String = _counter_trace_key()
	if k == "":
		return
	var v: Variant = GameState.get_trace(k)
	if typeof(v) == TYPE_INT:
		_interaction_count = int(v)
	elif typeof(v) == TYPE_FLOAT:
		_interaction_count = int(v)

func _increment_counter() -> void:
	_interaction_count += 1
	var k: String = _counter_trace_key()
	if k == "":
		return
	GameState.set_trace(k, _interaction_count)
