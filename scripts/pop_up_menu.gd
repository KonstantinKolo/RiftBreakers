extends Control

signal closeGame

@export var menu_size = 0.45
@export var lerp_speed = 0.2

var _popped_up = false
var _up_anchor = Vector2(0.95 -menu_size, 1)
var _down_anchor = Vector2(1, 1 + menu_size)
var _target_anchor = _down_anchor

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
	AudioServer.set_bus_volume_db(0, value)
func _on_check_box_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0,toggled_on)
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN) 
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) 
		DisplayServer.window_set_size(Vector2i(1152, 648))
func _on_fps_toggled(toggled_on: bool) -> void:
	Global.signalFPS.emit()
