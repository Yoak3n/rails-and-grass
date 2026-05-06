extends Node
#class_name SceneManager

# 当开始淡出、完全变黑、完成淡入时，发射信号，以便在这些节点做一些处理（比如存档）
signal transition_started
signal screen_blacked_out
signal transition_finished
signal before_leave 

var _canvas_layer: CanvasLayer
var _color_rect: ColorRect
var _is_transitioning: bool = false

# 全局存储玩家切图时的位置与朝向（如果需要）
var next_spawn_point: String = ""
var _saved_load_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. 动态创建一个层级极高（Layer 100）的 CanvasLayer
	# 这样黑屏就能挡住游戏里的所有 UI、特效和对话框
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)
	
	# 2. 动态创建一个铺满全屏的黑色 ColorRect
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0) # 初始完全透明
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_color_rect)

# 核心的切关卡方法
func change_scene(path: String, spawn_point_name: String = "", fade_duration: float = 1.0) -> void:
	if _is_transitioning:
		return
	
	before_leave.emit()
	
	_is_transitioning = true
	next_spawn_point = spawn_point_name
	transition_started.emit()
	
	# 冻结当前场景
	get_tree().paused = true
	
	# 阶段一：淡出（Fade Out 到全黑）
	var tween_out = create_tween()
	tween_out.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	
	await tween_out.finished
	
	# 发射全黑信号，此时画面全黑，是进行场景切换的最佳时机
	screen_blacked_out.emit()
	
	# 阶段二：卸载旧场景，加载新场景
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: Failed to load scene -> ", path)
		get_tree().paused = false
		_is_transitioning = false
		return
		
	# 等待新场景在下一帧初始化完毕 ( _ready 被调用 )
	await get_tree().process_frame

	if _saved_load_position != Vector2.ZERO:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is Node2D:
			(players[0] as Node2D).global_position = _saved_load_position
		_saved_load_position = Vector2.ZERO
		next_spawn_point = ""
	
	# 阶段三：淡入（Fade In 画面亮起）
	var tween_in = create_tween()
	tween_in.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	
	await tween_in.finished
	
	# 解除场景冻结
	get_tree().paused = false
	_is_transitioning = false
	transition_finished.emit()

	if path != "res://scenes/common/start_menu.tscn":
		SaveManager.start_auto_save()
	else:
		SaveManager.stop_auto_save()
