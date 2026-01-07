extends Node3D

@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	Global.triggeredMap.emit()
	MusicManager.play_music("res://assets/music/DavidKBD - The Last Pack - Orchestra - 03 - loopeable.ogg")
	player.load_screen_disappear()
	Global.map_start_time = Global.total_time
