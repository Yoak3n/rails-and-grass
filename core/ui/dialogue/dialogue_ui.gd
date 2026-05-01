extends Control
class_name DialogueUI

const _BUBBLE_SCENE: PackedScene = preload("res://core/ui/dialogue/dialogue_bubble.tscn")
const _BUBBLE_STACK_Y_START: float = -110.0
const _BUBBLE_STACK_Y_STEP: float = 56.0
const _TABOO_BOX_SHATTER_SECONDS: float = 1.0
const _TABOO_BOX_REVEAL_SECONDS: float = 1.2
const _TABOO_BUBBLE_SHATTER_SECONDS: float = 1.0
const _TABOO_BUBBLE_REVEAL_SECONDS: float = 1.6

@onready var _ui_panel: PanelContainer = $PanelContainer
@onready var _ui_text_label: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/RichTextLabel
@onready var _ui_options_container: VBoxContainer = $OptionsContainer
@onready var _taboo_flash_rect: ColorRect = $TabooFlashRect

var _is_taboo_triggering: bool = false
var _active_presentation: String = "box"

var _bubble_targets: Array[Node] = []
var _bubbles_by_key: Dictionary = {}
var _last_bubble_target: Node = null

# --- 打字机与状态控制 ---
var _is_typing: bool = false
var _is_waiting_for_click: bool = false
var _is_next_node_advance: bool = false
var _pending_taboo_continue: bool = false
var _current_options: Array = []
var _current_next_node: String = ""
var _current_duration: float = 0.0
var _type_speed_base: float = 30.0 # 默认打字速度（每秒字数）
var _type_timer: float = 0.0
var _auto_advance_event_id: int = 0
var _type_plan_active: bool = false
var _type_plan_prefix_chars: int = 0
var _type_plan_segment_chars: int = 0
var _type_plan_delay: float = 0.0
var _type_plan_segment_speed: float = 0.0
var _type_plan_total_chars: int = 0
var _bbcode_measure: RichTextLabel = null

func _ready() -> void:
	visible = true
	_ui_panel.visible = false
	_taboo_flash_rect.visible = false
	_taboo_flash_rect.modulate.a = 0.0 # 初始透明度设为 0
	if _ui_text_label:
		_ui_text_label.bbcode_enabled = true
		var has_type_effect := false
		for eff in _ui_text_label.custom_effects:
			if eff != null and eff is RichTextEffect and String(eff.get("bbcode")) == "type":
				has_type_effect = true
				break
		if not has_type_effect:
			_ui_text_label.install_effect(RichTextType.new())
	_init_bbcode_measure()
	# 监听全局对话管理器的信号
	DialogueManager.text_ready.connect(_on_text_ready)
	DialogueManager.options_ready.connect(_on_options_ready)
	DialogueManager.taboo_triggered.connect(_on_taboo_triggered)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _process(delta: float) -> void:
	if not _is_typing: return
	
	_type_timer += delta
	var target_chars := 0
	if _type_plan_active:
		target_chars = _compute_type_plan_visible_chars(_type_timer)
	else:
		target_chars = int(_type_timer * _type_speed_base)
	if _active_presentation == "box" and _ui_text_label:
		_ui_text_label.visible_characters = target_chars
		if _ui_text_label.visible_characters >= _ui_text_label.get_total_character_count():
			_finish_typing()

func _input(event: InputEvent) -> void:
	if _active_presentation != "box":
		return
	var is_click = event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not is_click: return
	# 状态 1：正在打字时点击 -> 跳过打字瞬间显示全部
	if _is_typing :
		if _active_presentation == "box" and _ui_text_label:
			_ui_text_label.visible_characters = -1
		_finish_typing()
		return
		# 状态 2：打字完毕，正在等待玩家点击继续 -> 推进到下一句或结束
	if _is_waiting_for_click:
		_is_waiting_for_click = false
		if _pending_taboo_continue:
			_pending_taboo_continue = false
			_is_taboo_triggering = false
			DialogueManager.proceed_after_taboo()
			return
		if _current_next_node != "":
			# 有 next_node，通知 Manager 直接跳过去
			_is_next_node_advance = true
			DialogueManager._go_to_node(_current_next_node)
		else:
			# 没有 next_node 也没有 options，说明是真结束了
			DialogueManager.dialogue_ended.emit()

func _init_bbcode_measure() -> void:
	if _bbcode_measure and is_instance_valid(_bbcode_measure):
		return
	_bbcode_measure = RichTextLabel.new()
	_bbcode_measure.bbcode_enabled = true
	_bbcode_measure.scroll_active = false
	_bbcode_measure.fit_content = true
	_bbcode_measure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bbcode_measure.visible = false
	_bbcode_measure.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_bbcode_measure)

func _finish_typing() -> void:
	_is_typing = false
	_render_options_or_wait()

# --- 信号响应 ---
func _on_text_ready(speaker: String, text: String, presentation: String, target: Node, next_node_id: String, duration: float) -> void:
	var was_auto_advance := _is_next_node_advance
	_is_next_node_advance = false
	# cache
	_active_presentation = presentation
	_current_next_node = next_node_id
	_current_duration = maxf(duration, 0.0)
	_auto_advance_event_id += 1
	_type_plan_active = false

	# 每次收到新文字，重置打字机状态
	_is_typing = true
	_is_waiting_for_click = false
	_type_timer = 0.0
	_current_options.clear()
	var full_text = ""
	if speaker != "": full_text = speaker + "：" + text
	else: full_text = text

	match _active_presentation:
		"box":
			if _ui_panel:
				_ui_panel.visible = true
			if was_auto_advance:
				_clear_bubbles_immediately(_bubble_key(target, "monologue"))
				_clear_bubbles_immediately(_bubble_key(target, "ghost"))
			_apply_text_with_type_plan(_ui_text_label, full_text)
			_ui_text_label.visible_characters = 0 # 隐藏文字，准备开始打字
				
		"monologue":
			if _ui_panel:
				_ui_panel.visible = false
			if not target:
				target = get_tree().get_first_node_in_group("player")
			if was_auto_advance:
				_clear_bubbles_immediately(_bubble_key(target, "monologue"))
			_spawn_bubble(text, target, "monologue", _current_duration)
			_last_bubble_target = target
			_is_typing = false
			_finish_typing()
		"ghost":
			if _ui_panel:
				_ui_panel.visible = false
			if was_auto_advance:
				_clear_bubbles_immediately(_bubble_key(target, "ghost"))
			_spawn_bubble(full_text, target, "ghost", _current_duration)
			_last_bubble_target = target
			_is_typing = false
			_finish_typing()

func _on_options_ready(options: Array) -> void:
	_current_options = options
	if not _is_typing:
		_render_options_or_wait()

func _render_options_or_wait() -> void:
	_ui_clear_options()
	
	# 如果没有选项
	if _current_options.is_empty():
		if _active_presentation == "box":
			# 我们不再生成【点击继续】的物理按钮，而是进入等待点击状态，并在文本末尾加一个提示小光标
			_is_waiting_for_click = true
			_ui_text_label.append_text(" [color=#888888]▼[/color]")
		else:
			_is_waiting_for_click = true
			var wait_seconds: float = 5.0
			if _current_duration > 0.0:
				wait_seconds = _current_duration
			var current_event_id := _auto_advance_event_id
			var t := get_tree().create_timer(wait_seconds)
			t.timeout.connect(func():
				if current_event_id != _auto_advance_event_id:
					return
				_is_waiting_for_click = false
				if _current_next_node != "":
					_is_next_node_advance = true
					DialogueManager._go_to_node(_current_next_node)
				else:
					DialogueManager.dialogue_ended.emit()
			)
		return
		
	# 如果有选项，确保面板显示并渲染按钮
	if _active_presentation != "box" and _ui_panel:
		_ui_panel.visible = true
		if _ui_text_label: _ui_text_label.clear()
			
	for opt in _current_options:
		if typeof(opt) != TYPE_DICTIONARY: continue
		var btn := Button.new()
		btn.text = String(opt.get("text", ""))
		btn.add_theme_font_size_override("font_size", 24)
		var opt_type := String(opt.get("type", "normal"))
		match opt_type:
			"taboo": btn.text = String(opt.get("original_text","???"))
			"hidden": btn.modulate = Color(0.7, 0.7, 0.7)
			"action": btn.modulate = Color(0.8, 1.0, 0.8)
		btn.pressed.connect(func(): _on_option_clicked(opt))
		_ui_options_container.add_child(btn)

func _on_option_clicked(option_data: Dictionary) -> void:
	if _is_taboo_triggering:
		return
	_ui_clear_options()
	DialogueManager.select_option(option_data)

func _on_taboo_triggered(original_text: String, replacement_text: String, presentation: String) -> void:
	_is_taboo_triggering = true
	_pending_taboo_continue = false
	var head := original_text.substr(0, mini(4, original_text.length()))
	
	# 触发全屏闪红特效
	_play_taboo_flash_effect()
	
	if presentation == "box":
		if not _ui_text_label:
			_is_taboo_triggering = false
			DialogueManager.proceed_after_taboo()
			return
		
		# 演出前确保文字全部显示
		_ui_text_label.visible_characters = -1
		# 演出：文字碎裂
		_ui_text_label.parse_bbcode("[color=#ff5555]" + head + "[/color][shake rate=50.0 level=20 connected=1]......[/shake]")
		
		# 演出：触发相机的屏幕震动（需确保场景里有对应方法，这里仅作文字表现）
		var t1 := get_tree().create_timer(_TABOO_BOX_SHATTER_SECONDS)
		await t1.timeout
		
		_ui_text_label.parse_bbcode(replacement_text)
		
		var t2 := get_tree().create_timer(_TABOO_BOX_REVEAL_SECONDS)
		await t2.timeout
		_is_waiting_for_click = true
		_pending_taboo_continue = true
		_ui_text_label.append_text(" [color=#888888]▼[/color]")
		return
	else:
		_spawn_bubble(head + "......", _last_bubble_target, presentation, _TABOO_BUBBLE_SHATTER_SECONDS)
		var t1 := get_tree().create_timer(_TABOO_BUBBLE_SHATTER_SECONDS)
		await t1.timeout
		
		_spawn_bubble(replacement_text, _last_bubble_target, presentation, _TABOO_BUBBLE_REVEAL_SECONDS)
		var t2 := get_tree().create_timer(_TABOO_BUBBLE_REVEAL_SECONDS)
		await t2.timeout
		
	_is_taboo_triggering = false
	DialogueManager.proceed_after_taboo()

func _on_dialogue_ended() -> void:
	_is_typing = false
	_is_waiting_for_click = false
	_auto_advance_event_id += 1
	_type_plan_active = false
	if _ui_panel:
		_ui_panel.visible = false
	if _ui_text_label:
		_ui_text_label.clear()
	_ui_clear_options()
	var all_keys := _bubbles_by_key.keys()
	for k in all_keys:
		_clear_bubbles_immediately(k)
	_bubble_targets.clear()
	_last_bubble_target = null

# --- UI 辅助方法 ---
func _ui_clear_options() -> void:
	for child in _ui_options_container.get_children():
		child.queue_free()

func _ui_add_system_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 24)
	btn.modulate = Color(0.6, 0.6, 0.6)
	btn.pressed.connect(callback)
	_ui_options_container.add_child(btn)

func _play_taboo_flash_effect() -> void:
	if not _taboo_flash_rect: return
	_taboo_flash_rect.visible = true
	_taboo_flash_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_taboo_flash_rect, "modulate:a", 1.0, 0.1) # 瞬间红
	tween.tween_property(_taboo_flash_rect, "modulate:a", 0.0, 1.0) # 慢慢褪去
	await tween.finished
	_taboo_flash_rect.visible = false

func _bubble_key(target: Node, presentation: String) -> String:
	if target == null:
		return ""
	return "%s|%s" % [str(target.get_instance_id()), presentation]

func _get_bubble_stack(key: String) -> Array:
	if not _bubbles_by_key.has(key):
		_bubbles_by_key[key] = []
	return _bubbles_by_key[key] as Array

func _get_bubble_text(bubble: Control) -> String:
	var label := bubble.get_node_or_null("BubbleLabel") as RichTextLabel
	if label:
		return label.get_parsed_text()
	return ""

func _layout_bubbles(key: String, _animate: bool) -> void:
	if key == "" or not _bubbles_by_key.has(key):
		return
	var stack := _bubbles_by_key[key] as Array
	for i in range(stack.size()):
		var bubble: Control = stack[i] as Control
		if bubble == null or not is_instance_valid(bubble):
			continue
		if not bubble.has_method("set_anchor_offset"):
			continue
		var offset := Vector2(0.0, _BUBBLE_STACK_Y_START - float(i) * _BUBBLE_STACK_Y_STEP)
		bubble.call("set_anchor_offset", offset)
		if bubble.has_method("request_sync"):
			bubble.call("request_sync")

func _clear_bubbles_immediately(key: String) -> void:
	if key == "" or not _bubbles_by_key.has(key):
		return
	var stack: Array = _bubbles_by_key[key]
	for bubble in stack:
		if bubble == null or not is_instance_valid(bubble):
			continue
		var tw: Tween = bubble.get_meta("_life_tween", null) as Tween
		if tw != null and tw.is_valid():
			tw.kill()
		bubble.queue_free()
	stack.clear()
	_bubbles_by_key.erase(key)

func _spawn_bubble(text: String, target: Node, presentation: String, duration: float) -> void:
	if target == null or not (target is CanvasItem):
		return
	var key: String = _bubble_key(target, presentation)
	var stack2 := _get_bubble_stack(key)
	if not _bubble_targets.has(target):
		_bubble_targets.append(target)

	if stack2.size() > 0:
		var top_bubble: Control = stack2[0] as Control
		if top_bubble != null and is_instance_valid(top_bubble):
			var existing_text := _get_bubble_text(top_bubble)
			if existing_text == text:
				var top_label := top_bubble.get_node_or_null("BubbleLabel") as RichTextLabel
				if top_label:
					_apply_text_with_type_plan(top_label, text)
					top_label.visible_characters = -1
				if top_bubble.has_method("request_sync"):
					top_bubble.call("request_sync")
				var old_tween: Tween = top_bubble.get_meta("_life_tween", null) as Tween
				if old_tween != null and old_tween.is_valid():
					old_tween.kill()
				top_bubble.modulate.a = 1.0
				var replace_tween := create_tween()
				top_bubble.set_meta("_life_tween", replace_tween)
				var replace_life := maxf(duration, 0.0)
				if replace_life > 0.0:
					var replace_fade_out := 0.18
					var replace_wait := maxf(replace_life - replace_fade_out, 0.0)
					replace_tween.tween_interval(replace_wait)
					replace_tween.tween_property(top_bubble, "modulate:a", 0.0, replace_fade_out)
				replace_tween.finished.connect(func():
					_remove_bubble(key, top_bubble, target)
				, CONNECT_ONE_SHOT)
				return

	var bubble := _BUBBLE_SCENE.instantiate() as Control
	if bubble == null:
		return
	bubble.name = "DialogueBubble"
	bubble.visible = false
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 4096
	bubble.z_as_relative = false
	if bubble.has_method("set_presentation"):
		bubble.call("set_presentation", presentation)
	var new_label := bubble.get_node_or_null("BubbleLabel") as RichTextLabel
	if new_label:
		_apply_text_with_type_plan(new_label, text)
		new_label.visible_characters = -1
	target.add_child(bubble)
	if bubble.has_method("request_sync"):
		bubble.call("request_sync")
	stack2.insert(0, bubble)
	_layout_bubbles(key, true)
	bubble.modulate.a = 0.0
	bubble.visible = true
	var new_tween := create_tween()
	bubble.set_meta("_life_tween", new_tween)
	new_tween.tween_property(bubble, "modulate:a", 1.0, 0.12)
	var new_life := maxf(duration, 0.0)
	if new_life > 0.0:
		var new_fade_out := 0.3
		var new_wait := maxf(new_life - new_fade_out, 0.0)
		new_tween.tween_interval(new_wait)
		new_tween.tween_property(bubble, "modulate:a", 0.0, new_fade_out)
	new_tween.finished.connect(func():
		_remove_bubble(key, bubble, target)
	, CONNECT_ONE_SHOT)

func _remove_bubble(key: String, bubble: Control, target: Node) -> void:
	if key != "" and _bubbles_by_key.has(key):
		var stack := _bubbles_by_key[key] as Array
		var idx := stack.find(bubble)
		if idx != -1:
			stack.remove_at(idx)
		_layout_bubbles(key, true)
		if stack.is_empty():
			_bubbles_by_key.erase(key)
			_bubble_targets.erase(target)
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()

func _measure_bbcode_visible_chars(bbcode_text: String) -> int:
	if not _bbcode_measure:
		return bbcode_text.length()
	_bbcode_measure.parse_bbcode(bbcode_text)
	return _bbcode_measure.get_total_character_count()

func _apply_text_with_type_plan(label: RichTextLabel, bbcode_text: String) -> void:
	_type_plan_active = false
	_type_plan_prefix_chars = 0
	_type_plan_segment_chars = 0
	_type_plan_delay = 0.0
	_type_plan_segment_speed = 0.0
	_type_plan_total_chars = 0
	if not label:
		return
	var open_idx: int = bbcode_text.find("[type")
	if open_idx == -1:
		label.parse_bbcode(bbcode_text)
		_type_plan_total_chars = label.get_total_character_count()
		return
	var open_end_idx: int = bbcode_text.find("]", open_idx)
	if open_end_idx == -1:
		label.parse_bbcode(bbcode_text)
		_type_plan_total_chars = label.get_total_character_count()
		return
	var close_idx: int = bbcode_text.find("[/type]", open_end_idx)
	if close_idx == -1:
		label.parse_bbcode(bbcode_text)
		_type_plan_total_chars = label.get_total_character_count()
		return
	var prefix_bbcode: String = bbcode_text.substr(0, open_idx)
	var env_str: String = bbcode_text.substr(open_idx + 5, open_end_idx - (open_idx + 5)).strip_edges()
	var inner_bbcode: String = bbcode_text.substr(open_end_idx + 1, close_idx - (open_end_idx + 1))
	var suffix_bbcode: String = bbcode_text.substr(close_idx + 7)
	var clean_bbcode: String = prefix_bbcode + inner_bbcode + suffix_bbcode
	var delay: float = 0.0
	var speed: float = _type_speed_base
	if env_str != "":
		for token in env_str.split(" ", false):
			var eq: int = token.find("=")
			if eq == -1:
				continue
			var k: String = token.substr(0, eq).strip_edges()
			var v: String = token.substr(eq + 1).strip_edges()
			if k == "delay":
				delay = float(v)
			elif k == "speed":
				speed = float(v)
	speed = maxf(speed, 0.001)
	label.parse_bbcode(clean_bbcode)
	_type_plan_prefix_chars = _measure_bbcode_visible_chars(prefix_bbcode)
	_type_plan_segment_chars = _measure_bbcode_visible_chars(inner_bbcode)
	_type_plan_delay = maxf(delay, 0.0)
	_type_plan_segment_speed = speed
	_type_plan_total_chars = label.get_total_character_count()
	_type_plan_active = true

func _compute_type_plan_visible_chars(t: float) -> int:
	var base_speed: float = maxf(_type_speed_base, 0.001)
	var prefix_time: float = float(_type_plan_prefix_chars) / base_speed
	if t < prefix_time:
		return mini(int(t * base_speed), _type_plan_total_chars)
	var t2: float = t - prefix_time
	if t2 < _type_plan_delay:
		return mini(_type_plan_prefix_chars, _type_plan_total_chars)
	var t3: float = t2 - _type_plan_delay
	var segment_time: float = float(_type_plan_segment_chars) / _type_plan_segment_speed
	if t3 < segment_time:
		return mini(_type_plan_prefix_chars + int(t3 * _type_plan_segment_speed), _type_plan_total_chars)
	var t4: float = t3 - segment_time
	var after_chars: int = int(t4 * base_speed)
	return mini(_type_plan_prefix_chars + _type_plan_segment_chars + after_chars, _type_plan_total_chars)
