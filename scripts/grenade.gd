extends RigidBody3D

@onready var grenade_mesh: Node3D = $Sketchfab_Scene


func _on_radius_body_entered(body: Node3D) -> void:
	linear_damp = 0.3
	angular_damp = 1.5
	_on_fusetimer_timeout()


func _on_fusetimer_timeout() -> void:
	await get_tree().create_timer(0.2).timeout
	var bodies = $Radius.get_overlapping_bodies()
	for obj in bodies:
		if obj.is_in_group("enemies") && obj.has_method("hurt"):
			obj.hurt(100)
		elif obj.get_parent().is_in_group("obstacles"):
			obj.get_parent().queue_free()
	
	# TODO make explosion
	await get_tree().create_timer(1.2).timeout
	queue_free()
