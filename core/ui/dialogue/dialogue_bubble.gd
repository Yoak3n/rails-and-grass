extends Control
class_name DialogueBubble

var padding: Vector2 = Vector2(18.0, 12.0)
var min_width: float = 140.0
var min_height: float = 20.0
var max_width: float = 420.0
var max_height: float = 120.0
var anchor_offset: Vector2 = Vector2(0.0, -110.0)
var _bg_style: StyleBoxFlat = null
var _initialized: bool = false
var _measure: RichTextLabel = null
var _cached_full_text: String = ""
var _cached_wrap_width: float = 0.0
var _cached_wrap_height: float = 0.0
var _cached_visible_chars: int = -2

func _ready() -> void:
	visible = false
	_ensure_initialized()

func get_label() -> RichTextLabel:
	return get_node("BubbleLabel") as RichTextLabel

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := get_node_or_null("BubbleBg") as Panel
	var label := get_node_or_null("BubbleLabel") as RichTextLabel

	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_style = StyleBoxFlat.new()
		_bg_style.bg_color = Color(0, 0, 0, 0.55)
		_bg_style.border_width_left = 2
		_bg_style.border_width_top = 2
		_bg_style.border_width_right = 2
		_bg_style.border_width_bottom = 2
		_bg_style.border_color = Color(0, 0, 0, 0.75)
		_bg_style.corner_radius_top_left = 12
		_bg_style.corner_radius_top_right = 12
		_bg_style.corner_radius_bottom_left = 12
		_bg_style.corner_radius_bottom_right = 12
		bg.add_theme_stylebox_override("panel", _bg_style)

	if label:
		label.bbcode_enabled = true
		label.scroll_active = false
		label.fit_content = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size = Vector2(max_width, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var unshaded_mat := CanvasItemMaterial.new()
		unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		label.material = unshaded_mat
		label.install_effect(RichTextType.new())
		label.modulate = Color(1, 1, 1, 0.84)

	_measure = RichTextLabel.new()
	_measure.visible = false
	_measure.bbcode_enabled = false
	_measure.scroll_active = false
	_measure.fit_content = true
	_measure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure.process_mode = Node.PROCESS_MODE_DISABLED
	_measure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_measure.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_measure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_measure)

	request_sync()

func _get_bg() -> Panel:
	return get_node_or_null("BubbleBg") as Panel

func set_anchor_offset(offset: Vector2) -> void:
	anchor_offset = offset
	_apply_anchor_position()

func set_presentation(presentation: String) -> void:
	_ensure_initialized()
	var label := get_node_or_null("BubbleLabel") as RichTextLabel
	if not label:
		return
	match presentation:
		"monologue":
			label.add_theme_color_override("default_color", Color(0.98, 0.98, 0.98, 1.0))
			if _bg_style:
				_bg_style.bg_color = Color(0, 0, 0, 0.58)
		"ghost":
			label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 0.9))
			label.add_theme_constant_override("outline_size", 4)
			label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
			label.modulate = Color(1, 1, 1, 1.0)
			var bg_node := _get_bg()
			if bg_node:
				bg_node.visible = false
		_:
			label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
			if _bg_style:
				_bg_style.bg_color = Color(0, 0, 0, 0.55)

func request_sync() -> void:
	if not _initialized:
		return
	call_deferred("_sync_backing")

func _apply_anchor_position() -> void:
	position = Vector2(-size.x * 0.5 + anchor_offset.x, anchor_offset.y)

func _sync_backing() -> void:
	var bg := _get_bg()
	var label := get_node_or_null("BubbleLabel") as RichTextLabel
	if not bg or not label:
		return
	if not _measure or not is_instance_valid(_measure):
		return

	var full_text: String = label.get_parsed_text()
	var visible_chars: int = label.visible_characters
	if full_text == _cached_full_text and visible_chars == _cached_visible_chars:
		return

	var wrap_w: float = _cached_wrap_width
	var wrap_h: float = _cached_wrap_height
		
	if full_text != _cached_full_text or wrap_w <= 0.0:
		_measure.autowrap_mode = TextServer.AUTOWRAP_OFF
		_measure.text = full_text
		var unwrapped_w: float = _measure.get_minimum_size().x
		wrap_w = clampf(unwrapped_w, min_width, max_width)
		wrap_h = clampf(_measure.get_minimum_size().y, min_height, max_height)
		
		_cached_full_text = full_text
		_cached_wrap_width = wrap_w
		_cached_wrap_height = wrap_h

	label.size.x = wrap_w

	var total_chars: int = full_text.length()
	var show_chars: int = total_chars
	if visible_chars >= 0:
		show_chars = mini(visible_chars, total_chars)
	if show_chars == 0:
		visible = false
		_cached_visible_chars = visible_chars
		return
	visible = true
	var partial: String = ""
	if show_chars > 0:
		partial = full_text.substr(0, show_chars)

	_measure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_measure.size.x = wrap_w
	_measure.text = partial
	var content_h: float = maxf(_measure.get_minimum_size().y, 1.0)
	content_h = clampf(content_h, min_height, max_height)

	var bg_w: float = wrap_w + padding.x * 2.0
	var bg_h: float = content_h + padding.y * 2.0
	bg.position = Vector2.ZERO
	bg.size = Vector2(bg_w, bg_h)
	size = bg.size
	label.position = padding
	_apply_anchor_position()
	_cached_visible_chars = visible_chars
