extends PanelContainer

const _SETTINGS_PATH := "user://settings.cfg"

const _RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const _DEFAULTS := {
	"master_volume": 80.0,
	"bgm_volume": 80.0,
	"sfx_volume": 80.0,
	"fullscreen": false,
	"resolution_index": 0,
	"text_speed": 50.0,
	"auto_advance": false,
}

@onready var _master_slider: HSlider = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/MasterVolume/HSlider
@onready var _master_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/MasterVolume/ValueLabel
@onready var _bgm_slider: HSlider = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/BGMVolume/HSlider
@onready var _bgm_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/BGMVolume/ValueLabel
@onready var _sfx_slider: HSlider = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/SFXVolume/HSlider
@onready var _sfx_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/AudioSection/SFXVolume/ValueLabel

@onready var _fullscreen_check: CheckButton = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/DisplaySection/FullscreenRow/CheckButton
@onready var _resolution_option: OptionButton = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/DisplaySection/ResolutionRow/OptionButton

@onready var _text_speed_slider: HSlider = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/GameplaySection/TextSpeed/HSlider
@onready var _text_speed_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/GameplaySection/TextSpeed/ValueLabel
@onready var _auto_advance_check: CheckButton = $MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/GameplaySection/AutoAdvanceRow/CheckButton

var _settings: Dictionary = {}
var _applying := false

signal settings_changed(settings: Dictionary)
signal close_requested

func _ready() -> void:
	_load_settings()
	_apply_to_ui()
	_apply_all()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) == OK:
		for key in _DEFAULTS:
			_settings[key] = cfg.get_value("settings", key, _DEFAULTS[key])
	else:
		_settings = _DEFAULTS.duplicate()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _settings:
		cfg.set_value("settings", key, _settings[key])
	cfg.save(_SETTINGS_PATH)

func _apply_to_ui() -> void:
	_applying = true
	_master_slider.value = _settings["master_volume"]
	_master_label.text = str(int(_settings["master_volume"]))
	_bgm_slider.value = _settings["bgm_volume"]
	_bgm_label.text = str(int(_settings["bgm_volume"]))
	_sfx_slider.value = _settings["sfx_volume"]
	_sfx_label.text = str(int(_settings["sfx_volume"]))

	_fullscreen_check.button_pressed = _settings["fullscreen"]
	_resolution_option.selected = _settings["resolution_index"]

	_text_speed_slider.value = _settings["text_speed"]
	_text_speed_label.text = str(int(_settings["text_speed"]))
	_auto_advance_check.button_pressed = _settings["auto_advance"]
	_applying = false

func _apply_all() -> void:
	_set_bus_volume("Master", _settings["master_volume"])
	_set_bus_volume("BGM", _settings["bgm_volume"])
	_set_bus_volume("SFX", _settings["sfx_volume"])
	_apply_display()
	settings_changed.emit(_settings)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db := linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_display() -> void:
	if OS.has_feature("editor"):
		return
	if _settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var idx: int = _settings["resolution_index"]
		if idx >= 0 and idx < _RESOLUTIONS.size():
			DisplayServer.window_set_size(_RESOLUTIONS[idx])

func _on_master_volume_changed(value: float) -> void:
	if _applying:
		return
	_settings["master_volume"] = value
	_master_label.text = str(int(value))
	_set_bus_volume("Master", value)
	_save_settings()

func _on_bgm_volume_changed(value: float) -> void:
	if _applying:
		return
	_settings["bgm_volume"] = value
	_bgm_label.text = str(int(value))
	_set_bus_volume("BGM", value)
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	if _applying:
		return
	_settings["sfx_volume"] = value
	_sfx_label.text = str(int(value))
	_set_bus_volume("SFX", value)
	_save_settings()

func _on_fullscreen_toggled(pressed: bool) -> void:
	if _applying:
		return
	_settings["fullscreen"] = pressed
	_apply_display()
	_save_settings()

func _on_resolution_selected(index: int) -> void:
	if _applying:
		return
	_settings["resolution_index"] = index
	if not _settings["fullscreen"] and not OS.has_feature("editor"):
		DisplayServer.window_set_size(_RESOLUTIONS[index])
	_save_settings()

func _on_text_speed_changed(value: float) -> void:
	if _applying:
		return
	_settings["text_speed"] = value
	_text_speed_label.text = str(int(value))
	_save_settings()
	settings_changed.emit(_settings)

func _on_auto_advance_toggled(pressed: bool) -> void:
	if _applying:
		return
	_settings["auto_advance"] = pressed
	_save_settings()
	settings_changed.emit(_settings)

func _on_reset_pressed() -> void:
	_settings = _DEFAULTS.duplicate()
	_apply_to_ui()
	_apply_all()
	_save_settings()

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func get_text_speed() -> float:
	return _settings.get("text_speed", _DEFAULTS["text_speed"])

func is_auto_advance() -> bool:
	return _settings.get("auto_advance", _DEFAULTS["auto_advance"])
