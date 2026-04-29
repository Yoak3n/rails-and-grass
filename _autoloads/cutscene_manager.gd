extends Node

signal cutscene_started(id: String)
signal cutscene_finished(id: String)

var _queue: Array[Dictionary] = []
var _is_playing: bool = false
var _current_id: String = ""
var _player_lock_count: int = 0
var _registry: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_playing() -> bool:
	return _is_playing

func current_id() -> String:
	return _current_id

func clear_queue() -> void:
	_queue.clear()

func register_scene(id: String, scene: PackedScene) -> void:
	_registry[id] = {
		"kind": "scene",
		"scene": scene
	}

func register_callable(id: String, fn: Callable) -> void:
	_registry[id] = {
		"kind": "callable",
		"fn": fn
	}

func register_json(id: String, json_path: String) -> void:
	_registry[id] = {
		"kind": "json",
		"json_path": json_path
	}

func register_script(id: String, script_path: String) -> void:
	_registry[id] = {
		"kind": "script",
		"script_path": script_path
	}

func unregister(id: String) -> void:
	_registry.erase(id)

func play_registered(id: String, context: Dictionary = {}) -> void:
	if not _registry.has(id):
		push_error("CutsceneManager: Cutscene not registered -> ", id)
		return
	var item: Dictionary = _registry[id]
	var kind: String = String(item.get("kind", ""))
	match kind:
		"scene":
			play_scene(item.get("scene", null), context, id)
		"callable":
			var fn: Callable = item.get("fn", Callable())
			play_callable_args(fn, [context], id)
		"json":
			play_json(String(item.get("json_path", "")), context, id)
		"script":
			play_script(String(item.get("script_path", "")), context, id)
		_:
			push_error("CutsceneManager: Invalid registry entry kind: ", kind)

func play_dialogue(json_path: String, start_node: String = "start", presentation: String = "box", target: Node = null, id: String = "") -> void:
	var req: Dictionary = {
		"kind": "dialogue",
		"id": id,
		"json_path": json_path,
		"start_node": start_node,
		"presentation": presentation,
		"target": target
	}
	_enqueue(req)

func play_scene(scene: PackedScene, context: Dictionary = {}, id: String = "") -> void:
	var req: Dictionary = {
		"kind": "scene",
		"id": id,
		"scene": scene,
		"context": context
	}
	_enqueue(req)

func play_json(json_path: String, context: Dictionary = {}, id: String = "") -> void:
	var req: Dictionary = {
		"kind": "json",
		"id": id,
		"json_path": json_path,
		"context": context
	}
	_enqueue(req)

func play_script(script_path: String, context: Dictionary = {}, id: String = "") -> void:
	var req: Dictionary = {
		"kind": "script",
		"id": id,
		"script_path": script_path,
		"context": context
	}
	_enqueue(req)

func play_callable(fn: Callable, id: String = "") -> void:
	play_callable_args(fn, [], id)

func play_callable_args(fn: Callable, args: Array = [], id: String = "") -> void:
	var req: Dictionary = {
		"kind": "callable",
		"id": id,
		"fn": fn,
		"args": args
	}
	_enqueue(req)

func _enqueue(req: Dictionary) -> void:
	_queue.append(req)
	if not _is_playing:
		call_deferred("_drain_queue")

func _drain_queue() -> void:
	if _is_playing:
		return
	_is_playing = true
	_lock_player_movement()
	while not _queue.is_empty():
		var req: Dictionary = _queue.pop_front()
		_current_id = String(req.get("id", ""))
		cutscene_started.emit(_current_id)
		await _play_request(req)
		cutscene_finished.emit(_current_id)
		_current_id = ""
	_unlock_player_movement()
	_is_playing = false

func _play_request(req: Dictionary) -> void:
	var kind: String = String(req.get("kind", ""))
	match kind:
		"dialogue":
			await _play_dialogue(req)
		"scene":
			await _play_scene(req)
		"callable":
			await _play_callable(req)
		"json":
			await _play_json(req)
		"script":
			await _play_script(req)
		_:
			push_error("CutsceneManager: Unknown cutscene kind: ", kind)

func _await_if_awaitable(value) -> void:
	if value is Signal:
		await value
		return
	if typeof(value) == TYPE_OBJECT and value != null and value.has_method("_await"):
		await value

func _play_dialogue(req: Dictionary) -> void:
	var json_path: String = String(req.get("json_path", ""))
	if json_path == "":
		push_error("CutsceneManager: Dialogue json_path is empty.")
		return
	if not DialogueManager.load_dialogue(json_path):
		push_error("CutsceneManager: Failed to load dialogue JSON: ", json_path)
		return
	var start_node: String = String(req.get("start_node", "start"))
	var presentation: String = String(req.get("presentation", "box"))
	var target: Node = req.get("target", null)
	DialogueManager.start_dialogue(start_node, presentation, target)
	await DialogueManager.dialogue_ended

func _play_scene(req: Dictionary) -> void:
	var scene: PackedScene = req.get("scene", null)
	if scene == null:
		push_error("CutsceneManager: scene is null.")
		return
	var instance := scene.instantiate()
	if instance == null:
		push_error("CutsceneManager: Failed to instantiate scene.")
		return
	add_child(instance)
	var context: Dictionary = req.get("context", {})
	if instance.has_method("start"):
		instance.call("start", context)
	if instance.has_signal("finished"):
		await instance.finished
	else:
		push_error("CutsceneManager: Cutscene scene must implement start(context) or emit finished.")
	if is_instance_valid(instance):
		instance.queue_free()

func _play_callable(req: Dictionary) -> void:
	var fn: Callable = req.get("fn", Callable())
	if fn.is_null():
		push_error("CutsceneManager: callable is null.")
		return
	var args: Array = req.get("args", [])
	var result = fn.callv(args)
	await _await_if_awaitable(result)

func _load_json_dict(json_path: String) -> Dictionary:
	if json_path == "":
		return {}
	if not FileAccess.file_exists(json_path):
		push_error("CutsceneManager: JSON file not found: ", json_path)
		return {}
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("CutsceneManager: Failed to open JSON file: ", json_path)
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("CutsceneManager: Failed to parse JSON: ", json.get_error_message())
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	return {}

func _play_json(req: Dictionary) -> void:
	var json_path: String = String(req.get("json_path", ""))
	var context: Dictionary = req.get("context", {})
	var cfg := _load_json_dict(json_path)
	if cfg.is_empty():
		return
	var script_path: String = String(cfg.get("script", ""))
	var params: Dictionary = {}
	var raw_params: Variant = cfg.get("params", {})
	if raw_params is Dictionary:
		params = raw_params as Dictionary
	var combined: Dictionary = {}
	combined.merge(params, true)
	combined.merge(context, true)
	await _play_script_internal(script_path, combined)

func _play_script(req: Dictionary) -> void:
	var script_path: String = String(req.get("script_path", ""))
	var context: Dictionary = req.get("context", {})
	await _play_script_internal(script_path, context)

func _play_script_internal(script_path: String, context: Dictionary) -> void:
	if script_path == "":
		push_error("CutsceneManager: script_path is empty.")
		return
	var script := load(script_path)
	if not (script is Script):
		push_error("CutsceneManager: Failed to load script: ", script_path)
		return
	var node = (script as Script).new()
	if not (node is Node):
		push_error("CutsceneManager: Script must extend Node: ", script_path)
		return
	var inst := node as Node
	var host := get_tree().current_scene
	if host == null:
		host = self
	host.add_child(inst)
	if inst.has_method("start"):
		inst.call("start", context)
	if inst.has_signal("finished"):
		await inst.finished
	else:
		push_error("CutsceneManager: Cutscene script must emit finished.")
	if is_instance_valid(inst):
		inst.queue_free()

func _lock_player_movement() -> void:
	_player_lock_count += 1
	if _player_lock_count != 1:
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p:
			p.set("can_move", false)

func _unlock_player_movement() -> void:
	_player_lock_count = maxi(_player_lock_count - 1, 0)
	if _player_lock_count != 0:
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p:
			p.set("can_move", true)
