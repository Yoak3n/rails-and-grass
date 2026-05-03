extends Node
## 图片闪回演出效果
##
## 演出流程: 淡入 → 闪白 → 停留展示 → 淡出 → 自动清理
##
## ---- 调用方式 ----
##
## 方式一: CutsceneManager 注册调用 (推荐)
##   CutsceneManager.register_script("flashback_01", "res://core/components/effects/cutscene/image_flashback.gd")
##   CutsceneManager.play_registered("flashback_01", {
##       "image": "res://assets/flashbacks/memory_01.png"
##   })
##
## 方式二: 通过 JSON 配置调用
##   JSON 文件示例:
##   {
##       "script": "res://core/components/effects/cutscene/image_flashback.gd",
##       "params": {
##           "image": "res://assets/flashbacks/memory_01.png",
##           "hold": 2.0,
##           "shake": 3.0
##       }
##   }
##   CutsceneManager.play_json("res://cutscenes/chapter_1/flashback_01.json")
##
## 方式三: 直接调用
##   CutsceneManager.play_script(
##       "res://core/components/effects/cutscene/image_flashback.gd",
##       {"image": "res://assets/flashbacks/scene.png", "hold": 3.0}
##   )
##
## 方式四: 在其他演出脚本中 await
##   var fb = preload("res://core/components/effects/cutscene/image_flashback.gd").new()
##   add_child(fb)
##   fb.start({"image": "res://assets/flashbacks/scene.png", "hold": 3.0})
##   await fb.finished
##
## ---- context 参数 ----
##
## image          : String  [必填] 图片资源路径, 例 "res://assets/flashbacks/scene.png"
## fade_in        : float   [可选] 淡入时间, 默认 0.15
## hold           : float   [可选] 图片停留时间, 默认 1.5
## fade_out       : float   [可选] 淡出时间, 默认 0.8
## bg_color       : Color   [可选] 背景颜色, 支持 [r,g,b,a] 数组或 Color, 默认黑色
## flash_color    : Color   [可选] 闪白瞬间颜色, 支持 [r,g,b,a] 数组或 Color, 默认白色
## flash_duration : float   [可选] 闪白持续时间, 默认 0.1
## shake          : float   [可选] 镜头震动强度, 0 表示不震动, 默认 0.0
## layer          : int     [可选] CanvasLayer 层级, 默认 300
## modulate       : Color   [可选] 图片最终色调, 支持 [r,g,b,a] 数组或 Color, 默认白色

signal finished


var _layer: CanvasLayer = null
var _bg_rect: ColorRect = null
var _image_rect: TextureRect = null

func start(context: Dictionary) -> void:
	call_deferred("_run", context)

func _run(context: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		finished.emit()
		return

	var image_path: String = String(context.get("image", "")).strip_edges()
	if image_path == "":
		push_error("ImageFlashback: 'image' path is required in context.")
		finished.emit()
		return

	var fade_in: float = _get_float(context.get("fade_in", 0.15), 0.15)
	var hold: float = _get_float(context.get("hold", 1.5), 1.5)
	var fade_out: float = _get_float(context.get("fade_out", 0.8), 0.8)
	var bg_color: Color = _resolve_color(context.get("bg_color", null), Color(0, 0, 0, 1))
	var flash_color: Color = _resolve_color(context.get("flash_color", null), Color(1, 1, 1, 1))
	var flash_duration: float = _get_float(context.get("flash_duration", 0.1), 0.1)
	var shake: float = _get_float(context.get("shake", 0.0), 0.0)
	var layer_value: int = int(context.get("layer", 300))
	var modulate_color: Color = _resolve_color(context.get("modulate", null), Color(1, 1, 1, 1))

	_create_overlay(scene, layer_value, bg_color)

	var tex: Texture2D = load(image_path) as Texture2D
	if tex == null:
		push_error("ImageFlashback: Failed to load image -> ", image_path)
		_cleanup()
		finished.emit()
		return

	_image_rect.texture = tex
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.modulate = Color(1, 1, 1, 0)
	_bg_rect.modulate = Color(1, 1, 1, 0)

	var tw := scene.create_tween()
	tw.set_parallel(false)

	tw.tween_property(_bg_rect, "modulate:a", 1.0, fade_in)
	tw.parallel().tween_property(_image_rect, "modulate:a", 1.0, fade_in)

	tw.tween_property(_bg_rect, "modulate", flash_color, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_image_rect, "modulate", flash_color, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_property(_bg_rect, "modulate", Color(1, 1, 1, 1), flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_image_rect, "modulate", modulate_color, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if shake > 0.0:
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			var original_offset: Vector2 = cam.offset
			tw.tween_callback(func():
				if is_instance_valid(cam):
					cam.offset = original_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
			)
			tw.tween_interval(hold * 0.5)
			tw.tween_callback(func():
				if is_instance_valid(cam):
					cam.offset = original_offset
			)
		else:
			tw.tween_interval(hold)
	else:
		tw.tween_interval(hold)

	tw.tween_property(_image_rect, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_bg_rect, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.tween_callback(func():
		_cleanup()
		finished.emit()
	)

func _create_overlay(host: Node, layer_value: int, bg_color: Color) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = layer_value
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(_layer)

	_bg_rect = ColorRect.new()
	_bg_rect.name = "FlashbackBg"
	_bg_rect.color = bg_color
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_bg_rect)

	_image_rect = TextureRect.new()
	_image_rect.name = "FlashbackImage"
	_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_image_rect)

func _cleanup() -> void:
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_bg_rect = null
	_image_rect = null

func _get_float(v: Variant, default_value: float) -> float:
	if v is float or v is int:
		return float(v)
	if v is String:
		var s: String = String(v).strip_edges()
		if s != "":
			return float(s)
	return default_value

func _resolve_color(v: Variant, default_color: Color) -> Color:
	if v is Color:
		return v as Color
	if v is Array:
		var a: Array = v as Array
		if a.size() >= 4:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		elif a.size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]), 1.0)
	return default_color
