extends RefCounted
class_name CutsceneEffectRunner

const Utils := preload("res://core/components/effects/cutscene/cutscene_utils.gd")

static func _resolve_at(effect: Dictionary, step_duration: float) -> float:
	var at_v: Variant = effect.get("at", 0.0)
	if at_v is String and String(at_v).strip_edges() == "end":
		return step_duration
	return maxf(Utils.get_float(at_v, 0.0), 0.0)

static func _resolve_duration(effect: Dictionary, step_duration: float, context: Dictionary) -> float:
	var d: Variant = effect.get("duration", null)
	if d == null:
		return step_duration
	if d is String and String(d).strip_edges() == "step":
		var end_before: float = Utils.resolve_number_ref(effect.get("end_before", null), context, 0.0)
		return maxf(step_duration - end_before, 0.01)
	if d is String:
		return maxf(Utils.resolve_number_ref(d, context, step_duration), 0.01)
	return maxf(Utils.get_float(d, step_duration), 0.01)

static func _set_actor_facing_x(actor: Node2D, face_right: bool, visual_node: String) -> void:
	var visual: Node2D = null
	if visual_node != "":
		visual = actor.get_node_or_null(NodePath(visual_node)) as Node2D
	if visual == null:
		visual = actor.get_node_or_null("Polygon2D") as Node2D
	if visual == null:
		visual = actor.get_node_or_null("Sprite2D") as Node2D
	if visual == null:
		return
	var sx: float = absf(visual.scale.x)
	visual.scale.x = sx if face_right else -sx

static func schedule_effects(scene: Node, actor: Node2D, player: Node2D, cut_cam: Camera2D, default_cam_offset: Vector2, step: Dictionary, step_duration: float, context: Dictionary, visual_node: String, held_props: Dictionary) -> void:
	var effects_v: Variant = step.get("effects", [])
	if not (effects_v is Array):
		return
	for raw in effects_v as Array:
		if not (raw is Dictionary):
			continue
		var effect: Dictionary = raw as Dictionary
		var t: String = String(effect.get("type", ""))
		var at: float = _resolve_at(effect, step_duration)
		var dur: float = _resolve_duration(effect, step_duration, context)
		match t:
			"move_node":
				var to_pos: Vector2 = Utils.vec2_from(effect.get("to_pos", null), actor.global_position)
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_property(actor, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			"move_camera":
				var to_pos: Vector2 = Utils.vec2_from(effect.get("to_pos", null), cut_cam.global_position)
				var step_cam_offset: Vector2 = Utils.vec2_from(effect.get("cam_offset", null), default_cam_offset)
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_property(cut_cam, "global_position", to_pos + step_cam_offset, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			"move_node_to_player":
				var off: Vector2 = Utils.vec2_from(effect.get("offset", null), Vector2.ZERO)
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_property(actor, "global_position", player.global_position + off, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			"move_camera_to_player":
				var step_cam_offset: Vector2 = Utils.vec2_from(effect.get("cam_offset", null), default_cam_offset)
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_property(cut_cam, "global_position", player.global_position + step_cam_offset, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			"face_to_player":
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_callback(func():
					_set_actor_facing_x(actor, player.global_position.x >= actor.global_position.x, visual_node)
				)
			"item_hold":
				var prop_id: String = String(effect.get("prop", ""))
				var tw := scene.create_tween()
				tw.tween_interval(at)
				tw.tween_callback(func():
					Utils.ensure_prop(held_props, actor, context, prop_id)
				)
			"item_transfer":
				var prop_id: String = String(effect.get("prop", ""))
				var prop_cfg: Dictionary = Utils.get_prop_config(context, prop_id)
				var prop_node: Node2D = Utils.ensure_prop(held_props, actor, context, prop_id)
				if prop_node == null:
					continue
				var item_duration: float = Utils.resolve_number_ref(effect.get("duration", prop_cfg.get("duration", 0.0)), context, 0.35)
				var from_offset: Vector2 = Utils.vec2_from(effect.get("from_offset", null), Utils.vec2_from(prop_cfg.get("hold_offset", null), Vector2.ZERO))
				var to_offset: Vector2 = Utils.vec2_from(effect.get("to_offset", null), Utils.vec2_from(prop_cfg.get("to_offset", null), Vector2.ZERO))
				var start_at: float = at
				if effect.get("at", null) is String and String(effect.get("at", "")).strip_edges() == "end":
					start_at = maxf(step_duration - item_duration, 0.0)
				var tw := scene.create_tween()
				tw.tween_interval(start_at)
				tw.tween_callback(func():
					prop_node.position = from_offset
					Utils.detach_to_scene(scene, prop_node)
				)
				tw.tween_property(prop_node, "global_position", player.global_position + to_offset, item_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_callback(func():
					if not is_instance_valid(prop_node):
						return
					Utils.attach_to_node(player, prop_node, to_offset)
				)
			"wait":
				var tw := scene.create_tween()
				tw.tween_interval(at + dur)
			_:
				var tw := scene.create_tween()
				tw.tween_interval(at + dur)
