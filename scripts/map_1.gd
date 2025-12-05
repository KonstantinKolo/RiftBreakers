extends Node3D

@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	Global.triggeredMap.emit()
	player.load_screen_disappear()
