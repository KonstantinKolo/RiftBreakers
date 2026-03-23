extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var confirm_button: Button = $Modal/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton

func _ready() -> void:
	_lang_setup()
	modulate.a = 0
	color_rect.modulate.a = 0
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

func appear() -> void:
	_lang_setup()
	animation_player.play("appear")
func disappear() -> void:
	animation_player.play("disappear")

func _on_confirm_button_pressed() -> void:
	disappear()
	await get_tree().create_timer(1.5).timeout
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://scenes/Maps/score_screen.tscn")

func _lang_setup() -> void:
	if Global.selected_language == "en":
		$Label.text = "YOU HAVE DIED!"
		$Modal/MarginContainer/VBoxContainer/HeaderLabel.text = "Return to the menu?"
		$Modal/MarginContainer/VBoxContainer/MessageLabel.text = "This will also display the score."
		$Modal/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton.text = "Confirm"
	elif Global.selected_language == "bg":
		$Label.text = "ВИЕ ЗАГИНАХТЕ!"
		$Modal/MarginContainer/VBoxContainer/HeaderLabel.text = "Обратно към менюто?"
		$Modal/MarginContainer/VBoxContainer/MessageLabel.text = "Това също ще покаже резултата."
		$Modal/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton.text = "Потвърди"
