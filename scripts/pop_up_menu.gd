extends Control

signal closeGame
signal changeLang

@export var menu_size = 0.45
@export var lerp_speed = 0.2

var _popped_up = false
var _up_anchor = Vector2(0.95 -menu_size, 1)
var _down_anchor = Vector2(1, 1 + menu_size)
var _target_anchor = _down_anchor

func _ready() -> void:
	_lang_setup()

func _process(delta: float) -> void:
	anchor_top = lerp(anchor_top, _target_anchor.x, lerp_speed)
	anchor_bottom = lerp(anchor_bottom, _target_anchor.y, lerp_speed)

func _on_settings_pressed() -> void:
	if !_popped_up:
		_target_anchor = _up_anchor
	else:
		_target_anchor = _down_anchor
	_popped_up = !_popped_up
func _on_exit_pressed() -> void:
	if !_popped_up:
		closeGame.emit()

func _on_volume_value_changed(value: float) -> void:
	var db: float
	if value <= 50.0:
		# Map 0–50 → -80 dB → 0 dB
		db = lerp(-40.0, 0.0, value / 50.0)
	else:
		# Map 50–100 → 0 dB → +3 dB
		db = lerp(0.0, 5.0, (value - 50.0) / 50.0)
	AudioServer.set_bus_volume_db(0, db)

func _on_check_box_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0,toggled_on)
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		print(1)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN) 
	else:
		print(2)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) 
		DisplayServer.window_set_size(Vector2i(1152, 648))
func _on_fps_toggled(toggled_on: bool) -> void:
	Global.signalFPS.emit()


func _on_english_lang_pressed() -> void:
	Global.selected_language = "en"
	_lang_setup()
	changeLang.emit()
func _on_bulgarian_lang_pressed() -> void:
	Global.selected_language = "bg"
	_lang_setup()
	changeLang.emit()
func _lang_setup() -> void:
	if Global.selected_language == "en":
		$VBoxContainer/HBoxContainer/Settings/Label.text = "SETTINGS"
		$VBoxContainer/HBoxContainer/Exit/Label.text = "EXIT"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/Label2.text = "Volume"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Mute.text = "Mute"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Fullscreen.text = "Fullscreen"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FPS.text = "Show FPS"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/Label.text = "Choose
Language"
	elif Global.selected_language == "bg":
		$VBoxContainer/HBoxContainer/Settings/Label.text = "НАСТРОЙКИ"
		$VBoxContainer/HBoxContainer/Exit/Label.text = "ИЗХОД"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/Label2.text = "Звук"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Mute.text = "Без звук"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/Fullscreen.text = "Цял екран"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FPS.text = "Покажи FPS"
		$VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/Label.text = "Избери
		Език"
