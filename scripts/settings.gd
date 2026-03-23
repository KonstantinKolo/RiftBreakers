extends Control

signal langChange

const SAVE_PATH: String = "user://save_data.json"

@onready var fps: CheckBox = $VBoxContainer/MarginContainer/VBoxContainer/FPS
@onready var time: CheckBox = $VBoxContainer/MarginContainer/VBoxContainer/Time

var can_pause:bool = false

func _ready() -> void:
	# Safe guard
	await get_tree().create_timer(2.0).timeout
	_lang_setup()
	if Global.show_fps: fps.set_pressed_no_signal(true)
	if Global.show_time: time.set_pressed_no_signal(true)
	can_pause = true
func _input(event: InputEvent) -> void:
	if !can_pause:
		return
	
	if event.is_action_pressed("escape"):
		if get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			visible = false
			get_tree().paused = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			visible = true
			get_tree().paused = true

func _on_volume_value_changed(value: float) -> void:
	var db: float
	if value <= 50.0:
		# Map 0–50 → -80 dB → 0 dB
		db = lerp(-40.0, 0.0, value / 50.0)
	else:
		# Map 50–100 → 0 dB → +3 dB
		db = lerp(0.0, 5.0, (value - 50.0) / 50.0)
	AudioServer.set_bus_volume_db(0, db)

func _on_mute_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0,toggled_on)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN) 
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED) 
		DisplayServer.window_set_size(Vector2i(1152, 648))

func _on_fps_toggled(toggled_on: bool) -> void:
	Global.signalPlayerFPS.emit()

func _on_time_toggled(toggled_on: bool) -> void:
	Global.signalPlayerTime.emit()

func _on_button_pressed() -> void: # Delete progress
	# Use DirAccess to remove the file
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
	get_tree().paused = false
	Global.reset_progress()
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://scenes/Maps/menu.tscn")

func _on_button_2_pressed() -> void: # Save progress
	var current_level: int 
	if Global.has_unlocked_level_3: current_level = 3
	elif Global.has_unlocked_level_2: current_level = 2
	else: current_level = 1
	
	var save_data = {
		"current_level": current_level,
		"melee_bots_killed": Global.melee_bots_killed,
		"ranged_bots_killed": Global.ranged_bots_killed,
		"total_time": Global.map_start_time,
		"has_dynamite_unlocked": Global.has_dynamite_unlocked,
		"has_rifle_unlocked": Global.has_rifle_unlocked
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Failed to save game!")
	
	get_tree().paused = false
	Global.reset_progress()
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://scenes/Maps/menu.tscn")

func _on_english_lang_pressed() -> void:
	Global.selected_language = "en"
	langChange.emit()
	_lang_setup()
func _on_bulgarian_lang_pressed() -> void:
	Global.selected_language = "bg"
	langChange.emit()
	_lang_setup()
func _lang_setup() -> void:
	if Global.selected_language == "en":
		$VBoxContainer/MarginContainer/VBoxContainer/Label2.text = "Volume"
		$VBoxContainer/MarginContainer/VBoxContainer/Mute.text = "Mute"
		$VBoxContainer/MarginContainer/VBoxContainer/Fullscreen.text = "Fullscreen"
		$VBoxContainer/MarginContainer/VBoxContainer/FPS.text = "Show FPS"
		$VBoxContainer/MarginContainer/VBoxContainer/Time.text = "Show Time"
		$VBoxContainer/MarginContainer/VBoxContainer/Button.text = "Give Up Session"
		$VBoxContainer/MarginContainer/VBoxContainer/Button2.text = "Save And Return To Menu"
	elif Global.selected_language == "bg":
		$VBoxContainer/MarginContainer/VBoxContainer/Label2.text = "Звук"
		$VBoxContainer/MarginContainer/VBoxContainer/Mute.text = "Без звук"
		$VBoxContainer/MarginContainer/VBoxContainer/Fullscreen.text = "Цял екран"
		$VBoxContainer/MarginContainer/VBoxContainer/FPS.text = "Покажи FPS"
		$VBoxContainer/MarginContainer/VBoxContainer/Time.text = "Покажи време"
		$VBoxContainer/MarginContainer/VBoxContainer/Button.text = "Откажи се от сесията"
		$VBoxContainer/MarginContainer/VBoxContainer/Button2.text = "Запази и се върни в менюто"
