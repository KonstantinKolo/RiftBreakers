extends CharacterBody3D

#TODO CHANGE THE NAME OF THE BOSS GIRL

enum States {
	Look,
	Walking,
	Pursuit
}

@export var custom_material_overlay: StandardMaterial3D = null

@export var walkSpeed: float = 1.2
@export var runSpeed: float = 2.4

@onready var simple_vision_3d: SimpleVision3D = $SimpleVision3D
@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D

@onready var bone_attachment: BoneAttachment3D = $visuals/bossgirl/Armature/Skeleton3D/BoneAttachment3D
@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/bossgirl/Armature/Skeleton3D/Plane_002
@onready var players_camera: Node = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@onready var animation_player: AnimationPlayer = $visuals/bossgirl/AnimationPlayer
var reverse_anim_bool: bool = false

var offset: Vector3 = Vector3(0, 1, 0)  # offset for that target that appears

var stuck_time: float = 0.0
var stuck_anim_threshold: float = 2.0
var stuck_reset_threshold: float = 6.0
var min_movement_threshold: float = 0.01
var last_position: Vector3 = Vector3.ZERO
var is_stuck: bool = false

var target_visible: bool = false
var is_shooting: bool = false
@export var health: int = 100 
@export var damage: int = 10.0
@export var shooting_delay: float = 2.0
var shooting_delay_elapsed: float = 0.0
var time: float = 0.0

var fading_out: bool = false
var fade_speed: float = 0.2 # alpha units per second

var state: States = States.Walking
var is_state_look: bool = false
var target: Node3D
var dir: int = 1 # 1 or -1
var left_point: Vector3
var right_point: Vector3

func _ready() -> void:
	await get_tree().process_frame
	
	left_point = global_position - transform.basis.x * 5.0
	right_point = global_position + transform.basis.x * 5.0
	
	animation_player.play("walk-pistol");
	follow_target_3d.ClearTarget()
	follow_target_3d.Speed = walkSpeed
	if scale.x > 1: #boss logic
		progress_bar.max_value = health
		var line_target
		if dir == 1: line_target = right_point
		else: line_target = left_point
		
		follow_target_3d.SetFixedTarget(line_target)
		if global_position.distance_to(line_target) < 1.0:
			dir *= -1 # flip direction
	else:
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
	target = null 
	
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

func _process(delta):
	if fading_out:
		_fade_out(delta)
	
	if health <= 0: 
		if !fading_out: fading_out = true
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	shooting_delay_elapsed += delta #count the time here
	
	# logic for when the bot gets stuck
	var distance_moved = global_position.distance_to(last_position)
	if distance_moved < min_movement_threshold && !is_shooting:
		stuck_time += delta
		if stuck_time > stuck_anim_threshold and !is_stuck:
			is_stuck = true
			if animation_player.current_animation != "idle-pistol":
				animation_player.play("idle-pistol")
		if stuck_time > stuck_reset_threshold:
			ChangeState(States.Walking)
	else:
		if animation_player.current_animation == "idle-pistol":
			animation_player.play("idle-pistol-to-walk")
		stuck_time = 0.0
		is_stuck = false
	last_position = global_position
	if velocity.length() < 0.3 and !_is_next_to_target() and !is_state_look:
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
	
	# stop moving when close to target
	if target and _is_within_range(8.0) and !is_state_look:
		_in_range_behaviour()
	elif state == States.Pursuit and !_is_within_range(8.0) and follow_target_3d.target != target:
		# ensure it keeps moving when not in range
		is_state_look = false
		if target:
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)
		else:
			# TODO go random target
			pass
	elif state == States.Look and !_is_within_range(8.5):
		is_state_look = false
		ChangeState(States.Pursuit)
	
	#for material overlays when looked ad
	time += delta
	if model_3d.material_overlay and model_3d.material_overlay.next_pass and model_3d.material_overlay.next_pass is ShaderMaterial:
		model_3d.material_overlay.next_pass.set("shader_parameter/time", time)
	if players_camera and target_visible:
		# Calculate the direction vector to the camera
		var camera_position = players_camera.global_transform.origin
		var bot_position = global_transform.origin
		var direction_to_camera = (camera_position - bot_position).normalized()
		# Place the sprite in front of the body (at the specified offset)
		var offset_position = bot_position + direction_to_camera * 0.4
		target_sprite.global_transform.origin = offset_position
		
		# Make the sprite face the camera
		target_sprite.look_at(camera_position, Vector3.UP)

func _in_range_behaviour():
	is_state_look = true
	while is_state_look and health > 0:
		follow_target_3d.Speed = 0
		velocity = Vector3.ZERO
		ChangeState(States.Look)
		if animation_player.current_animation != "idle-pistol" and !is_shooting:
			animation_player.play("idle-pistol")
		await get_tree().create_timer(0.1).timeout

func show_target() -> void:
	if target_sprite:
		target_visible = true
		target_sprite.visible = true
func hide_target() -> void:
	if target_sprite:
		target_visible = false
		target_sprite.visible = false

# Methods to change the material overlay
func change_mat_overlay(ENEMY_OUTLINE, ENEMY_STATIC_MATERIAL) -> void:
	if custom_material_overlay != null:
		model_3d.material_overlay.next_pass = ENEMY_OUTLINE
		model_3d.material_overlay.next_pass.next_pass = ENEMY_STATIC_MATERIAL
	else:
		model_3d.material_overlay = ENEMY_OUTLINE
		model_3d.material_overlay.next_pass = ENEMY_STATIC_MATERIAL
func remove_mat_overlay() -> void:
	model_3d.material_overlay = custom_material_overlay
	if model_3d.material_overlay and model_3d.material_overlay.next_pass:
		model_3d.material_overlay.next_pass = null

# combat funcs
func _shoot():
	if shooting_delay_elapsed < shooting_delay:
		return
	shooting_delay_elapsed = 0.0
	
	var close_range_distance := 1.5
	var distance_to_target := global_transform.origin.distance_to(target.global_transform.origin)
	
	var space_state = get_world_3d().direct_space_state
	var from = global_transform.origin + Vector3.UP * 1.5
	var to = target.global_transform.origin + Vector3.UP * 1.5

	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	# exclude the enemy and its child collision shapes
	params.exclude = _get_all_descendants(self)
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var result = space_state.intersect_ray(params)

	if result.size() > 0:
		var collider = result.get("collider") # collider is the object we hit
		
		if collider == target || target.is_ancestor_of(collider):
			# clear line of sight
			pass
		elif collider is Area3D:
			# area3d objects are invisible so bullets can pass 
			pass
		else:
			# obstacle so no shots
			return
	else:
		# Nothing hit (target may have no collider)
		pass
	
	is_shooting = true
	
	# Check if target is too close for shooting animation
	if distance_to_target <= close_range_distance:
		_close_range_attack(target)
	else:
		animation_player.play("idle-pistol-to-shoot") 
		await get_tree().create_timer(0.3).timeout
		animation_player.play_backwards("idle-pistol-to-shoot") 
		await get_tree().create_timer(0.3).timeout
		animation_player.play("idle-pistol")
		await get_tree().create_timer(0.3).timeout
		is_shooting = false
		
		_gun_bullet()
		_gun_flash()
func _gun_bullet() -> void:
	var bullet = load("res://scenes/bullet.tscn").instantiate()
	bullet.set_damage(10)

	# Spawn at gun socket
	bullet.global_transform = $visuals/bossgirl/Armature/Skeleton3D/BoneAttachment3D.global_transform

	# Set direction toward target
	bullet.global_transform = $visuals/bossgirl/Armature/Skeleton3D/BoneAttachment3D.global_transform
	get_tree().current_scene.add_child(bullet)
	var aim_height_offset = Vector3.UP * 1.2 # tweak to aim at chest/head
	var from_pos = bullet.global_transform.origin
	var to_pos = target.global_transform.origin + aim_height_offset
	var direction = (to_pos - from_pos).normalized()
	bullet.set_direction(direction)
func _gun_flash() -> void:
	var flash = load("res://scenes/ParticleEffects/muzzle_flash.tscn").instantiate()
	bone_attachment.add_child(flash)
	
	flash.position.z += 0.1
	flash.position.y += 1.05
	flash.rotation.x = flash.rotation.x + 8
	
	flash.shoot()
func _close_range_attack(target: CharacterBody3D) -> void:
	animation_player.play("shove")
	await get_tree().create_timer(0.8).timeout
	if _is_next_to_target(1.8):
		target.hurt(5) #deal damage to player
	await get_tree().create_timer(1.4).timeout # wait for the animation to finish
	is_shooting = false
func _get_all_descendants(node: Node) -> Array:
	var nodes = [node]
	for child in node.get_children():
		nodes += _get_all_descendants(child)
	return nodes

# Method to show the health bar
func show_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = true

# Method to hide the health bar
func hide_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = false

func die() -> void:
	if scale.x > 1: #for boss
		Global.has_unlocked_level_3 = true
	
	follow_target_3d.Speed = 0
	velocity = Vector3.ZERO
	_return_to_idle()
	if !is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	if animation_player.current_animation != "death":
		follow_target_3d.Speed = 0
		velocity = Vector3.ZERO
		animation_player.play("death")
func hurt(hit_points: int) -> void:
	if hit_points < health:
		health -= hit_points
		progress_bar.value = health
		#play hurt anim
		follow_target_3d.Speed = 0.9
		_return_to_idle()
		while animation_player.current_animation != "idle-pistol":
			await get_tree().process_frame
		_play_hit()
	else:
		if progress_bar.value == 0: return
		
		health = 0
		progress_bar.value = health
		die()
func _fade_out(delta):
	var mat := model_3d.get_surface_override_material(0)
	if mat == null:
		mat = model_3d.get_active_material(0).duplicate()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.flags_transparent = true
		model_3d.set_surface_override_material(0, mat)
	
	var new_alpha = mat.albedo_color.a - fade_speed * delta
	mat.albedo_color.a = clamp(new_alpha, 0.0, 1.0)
	
	if mat.albedo_color.a <= 0.0:
		queue_free()

func _return_health() -> int:
	return health

func ChangeState(newState : States) -> void:
	if health <= 0:
		return
	
	state = newState
	match state:
		States.Look:
			follow_target_3d.ClearTarget()
			if target:
				look_at(target.global_position, Vector3.UP)
				if !is_shooting:
					_shoot()
		States.Walking:
			animation_player.play("walk-pistol");
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			target = null 
		States.Pursuit:
			if !_is_combat_anim():
				animation_player.play("walk-to-run")
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)

# ai funcs
func _on_follow_target_3d_navigation_finished() -> void:
	if health <= 0:
		return
	
	if target and _is_next_to_target(20):
		look_at(target.global_position)
		#play strife-left animation
		if _check_punchable() and !is_shooting:
			_return_to_idle()
			while animation_player.current_animation != "idle-pistol":
				await get_tree().process_frame
			
			_shoot()
	elif target && !_is_next_to_target():
		if animation_player.current_animation != "run":
			animation_player.play("walk-to-run")
	elif target:
		animation_player.play("walk-to-run")
	else :
		if !is_walking():
			animation_player.play("walk-to-run")
		if scale.x > 1: # boss logic
			var line_target
			if dir == 1: line_target = right_point
			else: line_target = left_point
			
			follow_target_3d.SetFixedTarget(line_target)
			if global_position.distance_to(line_target) < 1.0:
				dir *= -1 # flip direction
		else:
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	if health <= 0:
		return
	target = body
	ChangeState(States.Pursuit)
func _on_simple_vision_3d_lost_sight() -> void:
	pass
func _is_within_range(range: float) -> bool:
	if target:
		return global_position.distance_to(target.global_position) <= range
	return false
func _is_next_to_target(max_distance := 2.0) -> bool:
	if target:
		var distance = global_position.distance_to(target.global_position)
		return distance <= max_distance
	return false

# animation functions
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if health <= 0:
		return
	
	if anim_name == "walk-to-run":
		if !reverse_anim_bool:
			animation_player.play("run")
		else:
			animation_player.play("walk-pistol")
			reverse_anim_bool = false
	elif anim_name == "idle-pistol-to-walk":
		if reverse_anim_bool:
			animation_player.play("idle-pistol")
			reverse_anim_bool = false
		else: 
			animation_player.play("walk-pistol")
	elif anim_name == "strife-left":
		follow_target_3d.Speed = runSpeed
		animation_player.speed_scale = 1
		_run()
func _run():
	_return_to_idle()
	
	while animation_player.current_animation != "idle-pistol":
		await get_tree().process_frame
	
	animation_player.play("idle-pistol-to-walk")
	
	while animation_player.current_animation != "walk-pistol":
		await get_tree().process_frame
	
	animation_player.play("walk-to-run")
func _play_hit():
	if health > 0:
		_return_to_idle()
	else: return
	
	
	follow_target_3d.Speed = 0
	velocity = Vector3.ZERO
	while animation_player.current_animation != "idle-pistol":
		await get_tree().process_frame
	
	animation_player.play("idle-pistol-to-shoot")
	await get_tree().create_timer(0.3).timeout
	animation_player.play("idle-pistol")
	follow_target_3d.Speed = runSpeed
func _return_to_idle():
	if animation_player.current_animation == "run":
		reverse_anim_bool = true
		animation_player.play_backwards("walk-to-run")
		while animation_player.current_animation != "walk-pistol":
				await get_tree().process_frame
		
		animation_player.play_backwards("idle-pistol-to-walk")
		reverse_anim_bool = true
	elif animation_player.current_animation == "walk-pistol":
		reverse_anim_bool = true
		animation_player.play_backwards("idle-pistol-to-walk")
	else:
		await get_tree().create_timer(0.5).timeout
		animation_player.play("idle-pistol")

# boolean functions
func is_walking():
	if animation_player.current_animation != " walk-to-run" and \
	   animation_player.current_animation != "run" and \
	   animation_player.current_animation != "strife-left" and \
	   animation_player.current_animation != "strife-right" and \
	   animation_player.current_animation != "idle-pistol-to-walk" and \
	   animation_player.current_animation != "walk-backwards-pistol" and \
	   animation_player.current_animation != "walk-pistol":
		return false
	return true
func _is_combat_anim():
	if animation_player.current_animation != "idle-pistol-to-shoot" and \
	   animation_player.current_animation != "shove" and \
	   animation_player.current_animation != "strife-left":
		return false
	return true
func _check_runable():
	if animation_player.current_animation != "strife-left" and \
	   animation_player.current_animation != "walk-to-run" and \
	   follow_target_3d.Speed != 0.9:
		return true
	return false
func _check_punchable():
	if animation_player.current_animation != "strife-left" and \
	   animation_player.current_animation != "idle-pistol-to-walk" and \
	   animation_player.current_animation != "shove" and \
	   follow_target_3d.Speed != 0.9 and \
	   _is_next_to_target():
		return true
	return false
