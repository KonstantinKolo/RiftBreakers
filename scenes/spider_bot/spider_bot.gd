extends Node3D

@export var move_speed: float = 5.0
@export var turn_speed: float = 1.0
@export var ground_offset: float = 0.5

@export var stuck_time_threshold: float = 2.0 # seconds
@export var stuck_distance_threshold: float = 0.1 # minimum distance considered "moving"
var last_position: Vector3
var stuck_timer: float = 0.0

@onready var random_target_3d: RandomTarget3D = $RandomTarget3D
@export var navigation_region: NavigationRegion3D
var target_reached := false
var target_pos : Vector3
var dir : Vector3

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget

@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

func _process(delta):
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	var target_basis = _basis_from_normal(avg_normal)
	
	var old_scale = scale
	transform.basis = lerp(transform.basis.orthonormalized(), _basis_from_normal(avg_normal), move_speed * delta).orthonormalized()
	#transform.basis = lerp(transform.basis, _basis_from_normal(avg_normal), move_speed * delta).orthonormalized()
	#transform.basis = lerp(transform.basis, target_basis, move_speed * delta).orthonormalized()
	scale = old_scale
	
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var target = avg + transform.basis.y * ground_offset
	var distance = transform.basis.y.dot(target - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)
	
	_handle_movement(delta)
	
func _handle_movement(delta):
	var my_pos: Vector3 = global_position
	#print(my_pos)
	#print(target_pos)
	#print("||||")
	
	# Check if stuck
	if last_position == null:
		last_position = my_pos
	var distance_moved = my_pos.distance_to(last_position)
	if distance_moved < stuck_distance_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	last_position = my_pos

	# If stuck for too long, pick a new target
	if stuck_timer >= stuck_time_threshold || target_pos == Vector3(0,0,0):
		print("Bot seems stuck! Choosing a new target.")
		target_reached = true
		stuck_timer = 0.0
	
	if target_reached:
		target_pos = random_target_3d.GetNextPoint()
		
		var bounds = navigation_region.get_bounds()
		var min = bounds.position
		var max = bounds.position + bounds.size
		
		if target_pos.x >= min.x and target_pos.x <= max.x \
		and target_pos.z >= min.z and target_pos.z <= max.z:
			print("Inside navigation region (XZ only)")
		else:
			print("Outside navigation region (XZ only)")
			return
		
		target_reached = false
	elif my_pos.distance_to(target_pos) < 0.5 || my_pos.x == target_pos.x && my_pos.z == target_pos.z:
		target_reached = true
		return
	
	dir = target_pos - my_pos
	dir.y = 0
	dir = dir.normalized()
	
	translate(dir * move_speed * delta)
	
	var a_dir = Input.get_axis('ui_right', 'ui_left')
	rotate_object_local(Vector3.UP, a_dir * turn_speed * delta)

func _basis_from_normal(normal: Vector3) -> Basis:
	#var result = Basis()
	#result.x = normal.cross(transform.basis.z)
	#result.y = normal
	#result.z = transform.basis.x.cross(normal)
#
	#result = result.orthonormalized()
	#
	#result.x *= scale.x 
	#result.y *= scale.y 
	#result.z *= scale.z 
	#
	#return result
	var result = Basis()
	result.x = normal.cross(transform.basis.z).normalized()
	result.y = normal.normalized()
	result.z = transform.basis.x.cross(normal).normalized()
	return result.orthonormalized()
