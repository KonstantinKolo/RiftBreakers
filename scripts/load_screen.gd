extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func appear() -> void:
	animation_player.play("start")
func disappear() -> void:
	animation_player.play("end")
