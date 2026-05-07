extends PanelContainer

const _HISTORY_ITEM_SCENE: PackedScene = preload("res://core/ui/log_panel/history_item.tscn")

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
		var item := _HISTORY_ITEM_SCENE.instantiate() as HistoryItem
		if not item:
			continue
		item.setup(String(record.get("speaker", "")), String(record.get("text", "")))
		_history_list.add_child(item)
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
