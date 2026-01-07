extends RayCast3D

var current_collider
@onready var pistol_sound: AudioStreamPlayer3D = $"../../Audio/PistolSound"
@onready var rifle_sound: AudioStreamPlayer3D = $"../../Audio/RifleSound"

func fire_shot(damage: int):
	if damage == 25:
		rifle_sound.play()
	elif damage == 20:
		pistol_sound.play()
		
	var collider = get_collider()
	if is_instance_valid(collider) and _check_hit(collider):
		_damage_enemy(collider, damage)
	elif is_instance_valid(collider) and _check_hit_parent(collider):
		_damage_enemy(collider.get_parent(), damage)

func _check_hit(collider):
	if collider.is_in_group("enemies"):
		return true
	return false
func _check_hit_parent(collider):
	if collider.get_parent() and \
	collider.get_parent().is_in_group("enemies"):
		collider = collider.get_parent()
		return true
	return false

func _damage_enemy(collider, damage: int):
	collider.hurt(damage)
