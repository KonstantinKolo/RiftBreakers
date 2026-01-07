extends Node3D

@onready var player: CharacterBody3D = $Player

# Get rid of the loading screen after the foliage is loaded
func _on_proton_scatter_build_completed() -> void:
	Global.triggeredMap.emit()
	MusicManager.play_music("res://assets/music/DavidKBD - The Last Pack - Dongxiao - 07 - loopeable.ogg")
	player.load_screen_disappear()
	Global.map_start_time = Global.total_time
