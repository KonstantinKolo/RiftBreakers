extends RayCast3D

var enemy_detected = false
var previous_collider: Node = null
var current_collider: Node = null

const ENEMY_OUTLINE = preload("res://assets/materials/enemy_outline.tres")
const ENEMY_STATIC_MATERIAL = preload("res://assets/materials/enemy_static_material.tres")

func _physics_process(delta: float) -> void:
	if is_colliding():
		current_collider = get_collider().get_parent()
		
		if current_collider != previous_collider and  \
		previous_collider and \
		previous_collider.is_in_group("enemies"):
			previous_collider.hide_health_bar()
		
		previous_collider = current_collider
		
		if current_collider.is_in_group("enemies") and !enemy_detected:
			enemy_detected = true
			current_collider.show_health_bar()
			current_collider.show_target()
			current_collider.get_node("CSGMesh3D").material_overlay = ENEMY_OUTLINE
			current_collider.get_node("CSGMesh3D").material_overlay.next_pass = ENEMY_STATIC_MATERIAL
	else:
		if previous_collider:
		# Stopped colliding\
			if previous_collider.is_in_group("enemies"): 
				previous_collider.hide_health_bar()
				previous_collider.hide_target()
				previous_collider.get_node("CSGMesh3D").material_overlay = null
				enemy_detected = false
			previous_collider = null

func return_enemy() -> Node:
	if current_collider and current_collider.is_in_group("enemies"):
		return current_collider
	else:
		return null
