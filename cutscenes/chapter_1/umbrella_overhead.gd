extends Node

signal finished

var _held_props: Dictionary = {}

const Utils := preload("res://core/components/effects/cutscene/cutscene_utils.gd")
const Runner := preload("res://core/components/effects/cutscene/cutscene_effect_runner.gd")

func start(context: Dictionary) -> void:
	call_deferred("_run", context)

func _get_step_duration(step: Dictionary, dialogue_seq: Array[Dictionary]) -> float:
	var d: float = CutsceneUtils.get_float(step.get("duration", 0.0), 0.0)
	if d > 0.0:
		return d
	var raw_dialogue: Variant = step.get("dialogue", null)
	if raw_dialogue is Dictionary:
		var duration_from_dialogue: float = CutsceneUtils.get_float((raw_dialogue as Dictionary).get("duration", 0.0), 0.0)
		if duration_from_dialogue > 0.0:
			return duration_from_dialogue
	var dialogue_index: int = int(step.get("dialogue_index", -1))
	if dialogue_index >= 0 and dialogue_index < dialogue_seq.size():
		return maxf(CutsceneUtils.get_float(dialogue_seq[dialogue_index].get("duration", 0.01), 0.01), 0.01)
	return 0.01

func _run(context: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		finished.emit()
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		finished.emit()
		return
	var umbrella_name: String = String(context.get("umbrella_name", "UmbrellaOverhead"))
	if player.get_node_or_null(umbrella_name) != null:
		finished.emit()
		return
	var girl_node: String = String(context.get("girl_node", "Zhiyi"))
	var girl :Zhiyi= scene.get_node_or_null(NodePath(girl_node)) as Node2D
	if girl == null:
		finished.emit()
		return
	
	var visual_node: String = String(context.get("girl_visual_node", "Polygon2D"))
	var player_cam := player.get_node_or_null("Camera2D") as Camera2D
	var cut_cam := Camera2D.new()
	scene.add_child(cut_cam)
	if player_cam != null:
		cut_cam.zoom = player_cam.zoom
		cut_cam.global_position = player_cam.global_position
	cut_cam.make_current()

	var cam_offset: Vector2 = Utils.vec2_from(context.get("cam_offset", null), Vector2(0.0, -116.0))

	var raw_dialogue: Variant = context.get("dialogue", [])
	var dialogue_seq: Array[Dictionary] = []
	if raw_dialogue is Array:
		for item in raw_dialogue as Array:
			if item is Dictionary:
				dialogue_seq.append(item as Dictionary)
	girl.current_state = Zhiyi.State.CUTSCENE
	var steps: Array = []
	var raw_steps: Variant = context.get("steps", [])
	if raw_steps is Array:
		steps = raw_steps as Array

	if not steps.is_empty():
		for raw_step in steps:
			if not (raw_step is Dictionary):
				continue
			var step: Dictionary = raw_step as Dictionary
			var step_duration: float = _get_step_duration(step, dialogue_seq)
			var raw_step_dialogue: Variant = step.get("dialogue", null)
			var has_dialogue: bool = raw_step_dialogue is Dictionary
			Runner.schedule_effects(scene, girl, player, cut_cam, cam_offset, step, step_duration, context, visual_node, _held_props)
			if has_dialogue:
				var entry: Dictionary = raw_step_dialogue as Dictionary
				var json_path: String = String(entry.get("json_path", "")).strip_edges()
				var start_node: String = String(entry.get("start_node", "start")).strip_edges()
				var pres: String = String(entry.get("presentation", "")).strip_edges()
				if json_path != "":
					if DialogueManager.load_dialogue(json_path):
						DialogueManager.start_dialogue(start_node, pres if pres != "" else "box", girl)
						await DialogueManager.dialogue_ended
					else:
						await get_tree().create_timer(step_duration).timeout
				else:
					var seq: Array[Dictionary] = [entry]
					var seq_pres: String = pres if pres != "" else String(entry.get("presentation", "ghost"))
					DialogueManager.start_sequence(seq, seq_pres, girl)
					await DialogueManager.dialogue_ended
			else:
				await get_tree().create_timer(step_duration).timeout
	else:
		var fallback_step: Dictionary = {
			"duration": 0.01,
			"effects": []
		}
		Runner.schedule_effects(scene, girl, player, cut_cam, cam_offset, fallback_step, 0.01, context, visual_node, _held_props)

	if player_cam != null:
		player_cam.make_current()
	if is_instance_valid(cut_cam):
		cut_cam.queue_free()
	finished.emit()
	girl.current_state = Zhiyi.State.PLAYING
	CutsceneManager.unregister("1")
