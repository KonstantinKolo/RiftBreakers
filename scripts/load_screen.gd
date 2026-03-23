extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func appear() -> void:
	_lang_setup()
	animation_player.play("start")
func disappear() -> void:
	animation_player.play("end")

func _lang_setup() -> void:
	if Global.selected_language == "en":
		$Label.text = "Loading..."
	elif Global.selected_language == "bg":
		$Label.text = "Зареждане..."
