extends RayCast3D

var current_collider

func fire_shot(damage: int):
	print("fire_shot()")
	var collider = get_collider()
	print(collider)
	if is_instance_valid(collider) and _check_hit(collider):
		_damage_enemy(collider, damage)

func _check_hit(collider):
	print("_check_hit")
	if collider.is_in_group("enemies"):
		print("HIT!")
		return true
	return false

func _damage_enemy(collider, damage: int):
	collider.hurt(damage)

#func _physics_process(delta: float) -> void:
	#if check_hit:
		#check_hit = false
		#_check_hit()
