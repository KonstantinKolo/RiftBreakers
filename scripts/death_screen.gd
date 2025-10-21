extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var confirm_button: Button = $Modal/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton

func _ready() -> void:
	modulate.a = 0
	color_rect.modulate.a = 0
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

func appear() -> void:
	animation_player.play("appear")
func disappear() -> void:
	animation_player.play("disappear")

func _on_confirm_button_pressed() -> void:
	disappear()
	await get_tree().create_timer(1.5).timeout
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://Maps/score_screen.tscn")
