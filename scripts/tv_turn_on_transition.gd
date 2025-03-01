extends CanvasLayer

signal tv_finished
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name):
	if anim_name == "turn_off":
		visible = false
		tv_finished.emit()

func turn_on_tv():
	visible = true
	animation_player.play_backwards("turn_off")
