extends Node3D

var shake_timer: float = 0.0
var shake_duration: float = 0.5
var shake_intensity: float = 0.1

var shake_offset: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta

		# Remove previous frame's offset
		global_position -= shake_offset

		# Generate new offset
		shake_offset = Vector3(
			(randf() - 0.5) * 2.0,
			(randf() - 0.5) * 2.0,
			(randf() - 0.5) * 2.0
		) * shake_intensity

		# Apply new offset
		global_position += shake_offset

		# Stop shake
		if shake_timer <= 0.0:
			global_position -= shake_offset
			shake_offset = Vector3.ZERO

func shake_camera(duration: float = 0.5, intensity: float = 0.1) -> void:
	shake_duration = duration
	shake_intensity = intensity
	shake_timer = shake_duration
