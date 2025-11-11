extends RigidBody3D

@onready var grenade_mesh: Node3D = $Sketchfab_Scene
@onready var explosion_scene : PackedScene = preload("res://scenes/ParticleEffects/explosion.tscn")


func _on_radius_body_entered(body: Node3D) -> void:
	linear_damp = 0.3
	angular_damp = 1.5
	_on_fusetimer_timeout()


func _on_fusetimer_timeout() -> void:
	await get_tree().create_timer(0.2).timeout
	var bodies = $Radius.get_overlapping_bodies()
	for obj in bodies:
		if is_instance_valid(obj) and obj.is_in_group("enemies") && obj.has_method("hurt"):
			obj.hurt(100)
		elif is_instance_valid(obj) and obj.get_parent().is_in_group("obstacles"):
			if obj.get_parent().has_method("timed_free"):
				obj.get_parent().timed_free()
	
	await get_tree().create_timer(1.2).timeout
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.position = global_position
	explosion.explode()
	queue_free()
