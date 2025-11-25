extends Node3D
@export var info_text: String = "The path is blocked! Get explosives from the graveyard and blow up the obstacle."
@onready var info_label: Label = $"../../Popups/InfoLabel"

func timed_free() -> void:
	await get_tree().create_timer(1).timeout
	info_label.queue_free()
	queue_free()
