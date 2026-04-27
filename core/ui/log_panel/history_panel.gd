extends PanelContainer

@onready var _history_scroll: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var _history_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HistoryList
@onready var close_btn = $MarginContainer/VBoxContainer/HBoxContainer/CloseHistoryButton

signal on_history_visible_update(visible: bool)

func _ready() -> void:
	close_btn.pressed.connect(hide_history)

func show_history() -> void:
	print("show_history")
	# 1. 清空旧的历史节点
	for child in _history_list.get_children():
		child.queue_free()
		
	# 2. 读取 Manager 中的数据并动态生成 RichTextLabel
	for record in DialogueManager.session_history:
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("normal_font_size", 22) # 根据你的UI调整字号
		var spk: String = record["speaker"]
		var txt: String = record["text"]
		
		# 使用 BBCode 区分说话人和正文颜色
		if spk != "":
			lbl.parse_bbcode("[color=#88ccff]" + spk + "[/color]：" + txt)
		else:
			lbl.parse_bbcode("[color=#cccccc]" + txt + "[/color]")
		print(lbl.get_parsed_text())
		_history_list.add_child(lbl)
	on_history_visible_update.emit(true)
	# 3. 延迟一帧将滚动条拉到最底部（必须延迟，等引擎排版计算完高度）
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	_history_scroll.scroll_vertical = int(_history_scroll.get_v_scroll_bar().max_value)

func hide_history() -> void:
	on_history_visible_update.emit(false)
	hide()


func _on_draw() -> void:
	pass
