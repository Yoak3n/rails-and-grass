extends CanvasLayer

var fade_tween: Tween

@onready var ui_root: Control = $MainMenu
@onready var log_btn = $MainMenu/Header/LogBtn
@onready var setting_btn = $MainMenu/Header/SettingBtn
@onready var log_panel = $MainMenu/HistoryPanel
@onready var setting_menu = $MainMenu/SettingMenu

var current_open_panel: Control = null

func _ready() -> void:
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_ui(0.0)
	log_panel.hide()
	setting_menu.hide()
	
	log_panel.on_history_visible_update.connect(_on_history_panel_update)
	setting_menu.close_requested.connect(_on_setting_menu_close_requested)
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_open_panel != null	:
		close_current_panel()
		# 阻止输入事件进一步被传递
		get_viewport().set_input_as_handled()

func show_ui(fade_time: float = 0.5):
	show()
	ui_root.visible = true # 确保节点可见
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	# 让子节点（所有UI元素）的透明度平滑过渡到 1.0
	fade_tween.tween_property(ui_root, "modulate:a", 1.0, fade_time)

func hide_ui(fade_time: float = 0.5):
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	# 透明度过渡到 0
	fade_tween.tween_property(ui_root, "modulate:a", 0.0, fade_time)
	
	# 动画结束后，彻底隐藏节点，防止玩家在过场动画时瞎点到隐形的按钮
	if fade_time > 0:
		fade_tween.tween_callback(ui_root.hide)
	else:
		ui_root.hide()

func _on_log_btn_pressed() -> void:
	toggle_panel(log_panel)


func _on_setting_btn_pressed() -> void:
	toggle_panel(setting_menu)

func toggle_panel(panel_to_open: Control):
	# 1. 如果点击的面板已经开着，那就关掉它（相当于关闭按钮）
	if current_open_panel == panel_to_open:
		close_current_panel()
		return

	# 2. 如果当前有别的面板开着（比如正在看 LOG 却点开了 Setting），先关掉旧的
	if current_open_panel != null:
		current_open_panel.hide()
		
	# 3. 打开新面板
	panel_to_open.show()
	if panel_to_open.has_method("show_history"):
		panel_to_open.call("show_history")
	
	current_open_panel = panel_to_open
	
	# 4. 极其重要：打开面板时，自动暂停游戏世界！
	get_tree().paused = true


func close_current_panel():
	if current_open_panel:
		current_open_panel.hide()
		current_open_panel = null	
		# 面板关完，恢复游戏时间流逝
		get_tree().paused = false

func _on_history_panel_update(history_visible: bool):
	if not history_visible:
		if current_open_panel == log_panel:
			close_current_panel()

func _on_setting_menu_close_requested():
	if current_open_panel == setting_menu:
		close_current_panel()
