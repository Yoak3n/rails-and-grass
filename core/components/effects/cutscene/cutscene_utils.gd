extends RefCounted
class_name CutsceneUtils

static func vec2_from(v: Variant, default_value: Vector2) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is Array:
		var a: Array = v as Array
		if a.size() >= 2:
			return Vector2(float(a[0]), float(a[1]))
	return default_value

static func get_float(v: Variant, default_value: float) -> float:
	match typeof(v):
		TYPE_INT:
			return float(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_STRING:
			var s: String = String(v).strip_edges()
			if s == "":
				return default_value
			return float(s)
		_:
			return default_value

static func get_by_path(root: Variant, path: String) -> Variant:
	var p: String = path.strip_edges()
	if p == "":
		return null
	var cur: Variant = root
	for part in p.split(".", false):
		if cur is Dictionary:
			var d: Dictionary = cur as Dictionary
			if not d.has(part):
				return null
			cur = d[part]
		else:
			return null
	return cur

static func resolve_number_ref(ref: Variant, context: Dictionary, default_value: float) -> float:
	match typeof(ref):
		TYPE_INT, TYPE_FLOAT:
			return float(ref)
		TYPE_STRING:
			var k: String = String(ref).strip_edges()
			if k == "":
				return default_value
			if context.has(k):
				return get_float(context.get(k, default_value), default_value)
			if k.find(".") != -1:
				var v: Variant = get_by_path(context, k)
				if v != null:
					return get_float(v, default_value)
			return get_float(k, default_value)
		_:
			return default_value

static func get_prop_config(context: Dictionary, prop_id: String) -> Dictionary:
	var props_v: Variant = context.get("props", {})
	if props_v is Dictionary:
		var props: Dictionary = props_v as Dictionary
		var v: Variant = props.get(prop_id, {})
		if v is Dictionary:
			return v as Dictionary
	return {}

static func get_prop_name(context: Dictionary, prop_id: String, fallback_name: String) -> String:
	var cfg: Dictionary = get_prop_config(context, prop_id)
	var n: String = String(cfg.get("name", "")).strip_edges()
	if n != "":
		return n
	var legacy_name_key: String = "%s_name" % prop_id
	var legacy: String = String(context.get(legacy_name_key, "")).strip_edges()
	if legacy != "":
		return legacy
	if prop_id == "umbrella":
		var umbrella_legacy: String = String(context.get("umbrella_name", "")).strip_edges()
		if umbrella_legacy != "":
			return umbrella_legacy
	return fallback_name

static func ensure_prop(held_props: Dictionary, holder: Node2D, context: Dictionary, prop_id: String) -> Node2D:
	if held_props.has(prop_id):
		var existing: Variant = held_props[prop_id]
		if existing is Node2D and is_instance_valid(existing):
			return existing as Node2D
		held_props.erase(prop_id)
	var cfg: Dictionary = get_prop_config(context, prop_id)
	var scene_path: String = String(cfg.get("scene", "")).strip_edges()
	if scene_path == "":
		scene_path = String(context.get("%s_scene" % prop_id, "")).strip_edges()
	if scene_path == "" and prop_id == "umbrella":
		scene_path = String(context.get("umbrella_scene", "")).strip_edges()
	if scene_path == "":
		return null
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var node: Node2D = packed.instantiate() as Node2D
	if node == null:
		return null
	node.name = get_prop_name(context, prop_id, prop_id)
	var z_off: float = resolve_number_ref(cfg.get("z_offset", context.get("%s_z_offset" % prop_id, 0)), context, 0.0)
	if prop_id == "umbrella" and not cfg.has("z_offset") and not context.has("%s_z_offset" % prop_id):
		z_off = resolve_number_ref(context.get("umbrella_z_offset", 0), context, 0.0)
	node.z_index = int(holder.get("z_index")) + int(z_off)
	holder.add_child(node)
	var hold_off: Vector2 = vec2_from(cfg.get("hold_offset", context.get("%s_hold_offset" % prop_id, null)), Vector2.ZERO)
	if hold_off == Vector2.ZERO and prop_id == "umbrella":
		hold_off = vec2_from(context.get("umbrella_from_offset", null), Vector2(10.0, -40.0))
	node.position = hold_off
	held_props[prop_id] = node
	return node

static func detach_to_scene(scene: Node, node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var gp: Vector2 = node.global_position
	var gr: float = node.global_rotation
	var gs: Vector2 = node.global_scale
	var p: Node = node.get_parent()
	if p != null:
		p.remove_child(node)
	scene.add_child(node)
	node.global_position = gp
	node.global_rotation = gr
	node.global_scale = gs

static func attach_to_node(target: Node2D, node: Node2D, local_pos: Vector2) -> void:
	if target == null or node == null:
		return
	var gp: Vector2 = node.global_position
	var gr: float = node.global_rotation
	var gs: Vector2 = node.global_scale
	var p: Node = node.get_parent()
	if p != null:
		p.remove_child(node)
	target.add_child(node)
	node.global_position = gp
	node.global_rotation = gr
	node.global_scale = gs
	node.position = local_pos
