extends PanelContainer
class_name HistoryItem

var text_label: RichTextLabel = null
var speaker: String = ""
var content: String = ""

func _ready() -> void:
	text_label = %RichTextLabel
	_apply_text()

func setup(_speaker: String, _content: String) -> void:
	speaker = _speaker
	content = _content
	if is_node_ready() and text_label:
		_apply_text()

func _apply_text() -> void:
	if not text_label:
		return
	if speaker != "":
		text_label.parse_bbcode("[color=#88ccff]" + speaker + "[/color]：" + content)
	else:
		text_label.parse_bbcode("[color=#cccccc]" + content + "[/color]")
	
