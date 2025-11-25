extends Control

@onready var anim_player: AnimationPlayer = $AnimationPlayer
var is_skipped = false

func _ready():
	anim_player.play("fade_out")
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_button_2_pressed() -> void:
	anim_player.play("skip")
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fade_out":
		get_tree().change_scene_to_file("res://Maps/intro_scene.tscn")
	elif anim_name == "skip":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
