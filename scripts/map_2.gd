extends Node3D

@onready var player: CharacterBody3D = $Player

# Get rid of the loading screen after the foliage is loaded
func _on_proton_scatter_build_completed() -> void:
	Global.triggeredMap.emit()
	player.load_screen_disappear()
