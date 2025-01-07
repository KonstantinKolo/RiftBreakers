extends RayCast3D

var enemy_detected = false
var previous_collider: Node = null

func _physics_process(delta: float) -> void:
	if is_colliding():
		var current_collider = get_collider().get_parent()
		
		if current_collider != previous_collider and  \
		previous_collider and \
		previous_collider.is_in_group("enemies"):
			previous_collider.hide_health_bar()
		
		previous_collider = current_collider
		
		if current_collider.is_in_group("enemies") and !enemy_detected:
			enemy_detected = true
			current_collider.show_health_bar()
	else:
		if previous_collider:
		# Stopped colliding\
			if previous_collider.is_in_group("enemies"): 
				previous_collider.hide_health_bar()
				enemy_detected = false
			previous_collider = null
