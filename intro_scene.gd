extends Node3D

@onready var animation_player: AnimationPlayer = $SmoothMC/AnimationPlayer
@onready var scene_animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.play("a-idle")


func _on_button_pressed() -> void:
	scene_animation_player.play("fade_to_black")
	scene_animation_player.animation_finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)

func _on_fade_finished(anim_name: StringName) -> void:
	if anim_name == "fade_to_black":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
