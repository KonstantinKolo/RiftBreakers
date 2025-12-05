extends Node3D

signal healthChanged
signal inHealthBarRange
signal outHealthBarRange

#parts with material
@onready var body_2: MeshInstance3D = $Armature/Skeleton3D/Body_2/Body_2
@onready var cylinder: MeshInstance3D = $Armature/Skeleton3D/Cylinder/Cylinder
@onready var cylinder_2: MeshInstance3D = $Armature/Skeleton3D/Cylinder/Cylinder2
@onready var cylinder_3: MeshInstance3D = $Armature/Skeleton3D/Cylinder/Cylinder3
@onready var cylinder_4: MeshInstance3D = $Armature/Skeleton3D/Cylinder/Cylinder4
@onready var leg: MeshInstance3D = $Armature/Skeleton3D/Leg
@onready var mats: Array[StandardMaterial3D] = [
	body_2.material_override,
	cylinder.material_override,
	cylinder_2.material_override,
	cylinder_3.material_override,
	cylinder_4.material_override,
	leg.material_override
]

@onready var explosion_scene : PackedScene = preload("res://scenes/ParticleEffects/explosion.tscn")
@onready var teleport_portal: Node3D = $"../Portals/TeleportPortal"

@export var health: int = 5000
var is_attacking: bool = false

@export var min_target_distance: float = 3
@export var move_speed: float = 5.0
@export var turn_speed: float = 1.0
@export var ground_offset: float = 0.5

@export var stuck_time_threshold: float = 2.0 # seconds
@export var stuck_distance_threshold: float = 0.5 # minimum distance considered "moving"
var last_position: Vector3
var stuck_timer: float = 0.0

@onready var random_target_3d: RandomTarget3D = $RandomTarget3D
@export var navigation_region: NavigationRegion3D
var target_body: CharacterBody3D = null
var before_player_pos: Vector3 = Vector3(0,0,0)
var target_reached: bool = false
var target_pos : Vector3
var dir : Vector3
var fading_out: bool = false
var fade_speed: float = 1 # alpha units per second
var target_visible: bool = false

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget

@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

@export var is_intro: bool = false

func _process(delta) -> void:
	if fading_out:
		_fade_out(delta)
	
	if health <= 0: 
		if !fading_out: fading_out = true
		return
	
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
	await get_tree().create_timer(0.5).timeout # needed for initial repathing
func _handle_movement(delta) -> void:
	var my_pos: Vector3 = global_position
	
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
		target_reached = true
		stuck_timer = 0.0
	
	if target_reached:
		if target_body != null:
			target_pos = target_body.global_position
		elif before_player_pos != Vector3(0,0,0):
			target_pos = before_player_pos
			before_player_pos = Vector3(0,0,0)
		else:
			target_pos = random_target_3d.GetNextPoint()
		
		var quad_points: Array[Vector3]
		if is_intro:
			quad_points = [
				Vector3(-2.0, -0.2, -3.0),
				Vector3(-2.0, -0.2, -27.5),
				Vector3(97.0, -0.2, -27.0),
				Vector3(97.0, -0.2, -2.5)
			]
		else:
			quad_points = [
				Vector3(-97, 0, 12),
				Vector3(-130.5, 0, 44),
				Vector3(-169.5, 0, 2.5),
				Vector3(-133.5, 0, -29.5)
			]
		
		if is_point_in_quad(target_pos, quad_points[0], quad_points[1], quad_points[2], quad_points[3]):
			pass
		else:
			return
		
		target_reached = false
	elif my_pos.distance_to(target_pos) < min_target_distance || my_pos.x == target_pos.x && my_pos.z == target_pos.z:
		_attack()
		target_reached = true
		return
	
	
	dir = target_pos - my_pos
	dir.y = 0
	dir = dir.normalized()
	
	if is_attacking:
		dir = Vector3.ZERO # stop movement
	
	translate(dir * move_speed * delta)
	
	var a_dir = Input.get_axis('ui_right', 'ui_left')
	rotate_object_local(Vector3.UP, a_dir * turn_speed * delta)
func is_point_in_quad(point: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> bool:
	# Convert to 2D using XZ
	var P  = Vector2(point.x, point.z)
	var A0 = Vector2(p0.x, p0.z)
	var A1 = Vector2(p1.x, p1.z)
	var A2 = Vector2(p2.x, p2.z)
	var A3 = Vector2(p3.x, p3.z)
	
	# Split into 2 triangles: (A0, A1, A2) and (A2, A3, A0)
	return is_point_in_triangle(P, A0, A1, A2) \
		or is_point_in_triangle(P, A2, A3, A0)
func is_point_in_triangle(P: Vector2, A: Vector2, B: Vector2, C: Vector2) -> bool:
	var v0 = C - A
	var v1 = B - A
	var v2 = P - A
	
	var dot00 = v0.dot(v0)
	var dot01 = v0.dot(v1)
	var dot02 = v0.dot(v2)
	var dot11 = v1.dot(v1)
	var dot12 = v1.dot(v2)
	
	var inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u = (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v = (dot00 * dot12 - dot01 * dot02) * inv_denom
	
	return (u >= 0) and (v >= 0) and (u + v < 1)

func _basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x = normal.cross(transform.basis.z).normalized()
	result.y = normal.normalized()
	result.z = transform.basis.x.cross(normal).normalized()
	return result.orthonormalized()

# placeholder methods so they work for general enemy logic
func show_target() -> void:
	pass
func hide_target() -> void:
	pass
func show_health_bar() -> void:
	pass
func hide_health_bar() -> void:
	pass
func change_mat_overlay(ENEMY_OUTLINE, ENEMY_STATIC_MATERIAL) -> void:
	pass
func remove_mat_overlay() -> void:
	pass

func die() -> void:
	Global.on_boss_killed()
	Global.has_cleared_game = true
	teleport_portal.activate()
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.scale = Vector3(2,2,2)
	explosion.position = global_position
	explosion.explode()
func hurt(hit_points: int) -> void:
	if hit_points < health:
		health -= hit_points
		healthChanged.emit()
	else:
		if health == 0:
			healthChanged.emit() 
			return
		health = 0
		healthChanged.emit()
		die()
func _fade_out(delta) -> void:
	if !is_inside_tree(): return
	
	for i in mats.size():
		var mat := mats[i]
		
		# Fade albedo
		var c := mat.albedo_color
		c.a = max(0.0, c.a - fade_speed * delta)
		mat.albedo_color = c
		
		#disable emissions
		mat.emission_enabled = false
	if _all_mats_invisible():
		queue_free()
func _all_mats_invisible() -> bool:
	for mat in mats:
		if mat.albedo_color.a > 0.0:
			return false
	return true
func _return_health() -> int:
	return health

func _attack() -> void:
	if is_intro: return 
	
	if !is_attacking:
		is_attacking = true
		_attack_flash()
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
		_attack_behaviour()
		_damage()
		if is_inside_tree():
			await get_tree().create_timer(0.5).timeout
		is_attacking = false
func _attack_flash() -> void: 
	for mat in mats:
		if mat == null:
			return
		
		var tween := get_tree().create_tween()
		var flash_count := 3
		for i in flash_count:
			tween.tween_property(mat, "albedo_color", Color.RED, 0.15)
			tween.tween_property(mat, "albedo_color", Color.from_rgba8(43,43,43), 0.35)
func _attack_behaviour() -> void:
	# spawn explosions
	for n in range(-1,1):
		var explosion1 = explosion_scene.instantiate()
		get_tree().root.add_child(explosion1)
		explosion1.scale = Vector3(2,2,2)
		explosion1.position = global_position + Vector3(n*5,0.1,0)
		explosion1.explode()
		var explosion2 = explosion_scene.instantiate()
		get_tree().root.add_child(explosion2)
		explosion2.scale = Vector3(2,2,2)
		explosion2.position = global_position + Vector3(0,0.1,n*5)
		explosion2.explode()
func _damage() -> void:
	if target_body == null: return #safeguard
	if global_position.distance_to(target_body.global_position) < min_target_distance + 1.5 || global_position.x == target_body.global_position.x && global_position.z == target_body.global_position.z:
		target_body.hurt(40)

func _on_player_detection_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		before_player_pos = global_position
		target_body = body
		target_reached = true
		inHealthBarRange.emit()
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		target_body = null
		target_reached = true
		outHealthBarRange.emit()
