extends Node

var has_unlocked_level_2 = false;
var has_unlocked_level_3 = false;

signal signalFPS
var show_fps: bool = false
var fps_label = Label.new()

func _ready() -> void:
	signalFPS.connect(fps_handle)

func _process(delta: float) -> void:
	if show_fps:
		fps_label.text = "FPS: %s" % [Engine.get_frames_per_second()]

func fps_handle() -> void:
	if !show_fps:
		show_fps = true
		display_fps()
	else:
		show_fps = false
		display_fps()

func display_fps() -> void:
	var current_scene = get_tree().current_scene
	if show_fps:
		current_scene.add_child(fps_label)
	else:
		current_scene.remove_child(fps_label)
