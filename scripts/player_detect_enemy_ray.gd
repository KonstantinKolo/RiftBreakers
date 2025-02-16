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
			if get_collision_point().distance_to(global_position) < 2.0:
				print("get rid of target")
			current_collider.show_target()
			current_collider.change_mat_overlay(ENEMY_OUTLINE, ENEMY_STATIC_MATERIAL)
			wait_for_distance_shortened()
	else:
		if previous_collider and is_instance_valid(previous_collider):
			# Stopped colliding
			if previous_collider.is_in_group("enemies"): 
				previous_collider.hide_health_bar()
				previous_collider.hide_target()
				previous_collider.remove_mat_overlay()
				enemy_detected = false
			previous_collider = null
		elif !is_instance_valid(previous_collider):
			enemy_detected = false
			previous_collider = null

func return_enemy() -> Node:
	if current_collider and is_instance_valid(current_collider) and current_collider.is_in_group("enemies"):
		return current_collider
	else:
		return null
func wait_for_distance_shortened() -> void:
	# when character gets too close to the enemy
	# the target will disappear to avoid clippin
	while enemy_detected:
		await get_tree().create_timer(0.5).timeout
		if !is_instance_valid(current_collider): return
		if get_collision_point().distance_to(global_position) > 2.0 \
		and (current_collider == previous_collider and previous_collider != null):
			current_collider.show_target()
		elif current_collider.target_visible == true:
			current_collider.hide_target()
