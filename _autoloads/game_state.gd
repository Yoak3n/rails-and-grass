extends Node
#class_name GameState

var traces: Dictionary = {
	"silence_count": 0,
	"pain_value": 0,
	"knows_bookstore": false
}

func get_trace(key: String) -> Variant:
	return traces.get(key, null)

func set_trace(key: String, value: Variant) -> void:
	traces[key] = value

# 在主菜单点击“新游戏”时调用
func reset_game() -> void:
	traces = {
		"silence_count": 0,
		"pain_value": 0,
		"knows_bookstore": false
	}
	print("GameState: 游戏数据已重置。")
