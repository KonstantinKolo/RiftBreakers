extends CharacterBody3D

#TODO CHANGE THE NAME OF THE BOSS GIRL

enum States {
	Look,
	Walking,
	Pursuit
}

@export var walkSpeed : float = 1.2
@export var runSpeed : float = 2.4

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D

@onready var bone_attachment: BoneAttachment3D = $visuals/bossgirl/Armature/Skeleton3D/BoneAttachment3D
@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/bossgirl/Armature/Skeleton3D/Plane_002
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@onready var animation_player: AnimationPlayer = $visuals/bossgirl/AnimationPlayer
var reverse_anim_bool = false

@export var radius: float = 0.35  # Distance from the center of the StaticBody3D
@export var offset: Vector3 = Vector3(0, 1, 0)  # Optional offset from the StaticBody3D's position

var target_visible = false
var is_shooting = false
var health = 100 
var time = 0.0

var fading_out := false
var fade_speed := 0.2 # alpha units per second

var state : States = States.Walking
var is_state_look = false
var target : Node3D

func _ready() -> void:
	await get_tree().process_frame
	
	var next_point = random_target_3d.GetNextPoint()
	print("RandomTarget3D next_point:", next_point)
	print("Global origin:", random_target_3d.global_transform.origin)
	
	ChangeState(States.Walking)
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

func _process(delta):
	if fading_out:
		_fade_out(delta)
	
	if health <= 0: 
		if animation_player.current_animation != "death" and animation_player.current_animation != "":
			print(animation_player.current_animation)
			animation_player.play("death") 
			fading_out = true
		
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# stop moving when close to target
	if target and _is_within_range(5.0) and !is_state_look:
		_in_range_behaviour()
	elif state == States.Pursuit and !_is_within_range(5.0) and follow_target_3d.target != target:
		# ensure it keeps moving when not in range
		print("NOT IN RANGE")
		is_state_look = false
		if target:
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)
		else:
			# TODO go random target
			pass
	elif state == States.Look and !_is_within_range(5.5):
		print("Elif look")
		is_state_look = false
		ChangeState(States.Pursuit)
	
	#if velocity.length() < 0.3 and !_is_next_to_target(): # checks if the bot is stuck
		#follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
		#print("Stuck")
	
	#for material overlays when looked ad
	time += delta
	if model_3d.material_overlay and model_3d.material_overlay.next_pass and model_3d.material_overlay.next_pass is ShaderMaterial:
		model_3d.material_overlay.next_pass.set("shader_parameter/time", time)
	# TODO make it if the player is close the target dissappears
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
		print("IN RANGE")
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
	model_3d.material_overlay = ENEMY_OUTLINE
	model_3d.material_overlay.next_pass = ENEMY_STATIC_MATERIAL
func remove_mat_overlay() -> void:
	model_3d.material_overlay = null

# Method to add effect for shooting
func _shoot():
	print("BOT SHOOT")
	is_shooting = true
	animation_player.play("idle-pistol-to-shoot") 
	await get_tree().create_timer(0.3).timeout
	animation_player.play_backwards("idle-pistol-to-shoot") 
	await get_tree().create_timer(0.3).timeout
	animation_player.play("idle-pistol")
	await get_tree().create_timer(0.3).timeout
	is_shooting = false
	
	_flash_bullet()
func _flash_bullet() -> void:
	var bullet = load("res://scenes/ParticleEffects/muzzle_flash.tscn").instantiate()
	bone_attachment.add_child(bullet)
	
	bullet.position.z += 0.1
	bullet.position.y += 1.05
	bullet.rotation.x = bullet.rotation.x + 8
	
	bullet.shoot()

# Method to show the health bar
func show_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = true

# Method to hide the health bar
func hide_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = false

func die() -> void:
	print("DEATH")
	follow_target_3d.Speed = 0
	_return_to_idle()
	await get_tree().create_timer(0.1).timeout
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
	if health == 0:
		return
	
	print(newState)
	
	state = newState
	match state:
		States.Look:
			print("STATE LOOK")
			follow_target_3d.ClearTarget()
			if target:
				look_at(target.global_position, Vector3.UP)
				if !is_shooting:
					_shoot()
		States.Walking:
			print("STATE WALK")
			animation_player.play("walk-pistol");
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			target = null 
		States.Pursuit:
			print("STATE PURSUIT")
			if !_is_combat_anim():
				animation_player.play("walk-to-run")
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)

# ai funcs
func _on_follow_target_3d_navigation_finished() -> void:
	if health == 0:
		return
	
	print(follow_target_3d.targetPosition)
	
	if target and _is_next_to_target():
		print("I")
		look_at(target.global_position)
		#play strife-left animation
		if _check_punchable():
			_return_to_idle()
			while animation_player.current_animation != "idle-pistol":
				await get_tree().process_frame
			
			_shoot()
	elif target && !_is_next_to_target():
		print("II")
		if animation_player.current_animation != "run":
			animation_player.play("walk-to-run")
	elif target:
		print("III")
		animation_player.play("walk-to-run")
	else :
		print("IV")
		print(animation_player.current_animation)
		if !is_walking():
			animation_player.play("walk-to-run")
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	print("Get sight")
	if health == 0:
		return
	target = body
	ChangeState(States.Pursuit)
func _on_simple_vision_3d_lost_sight() -> void:
	print("Lost sight")
	pass
func _is_within_range(range: float) -> bool:
	if target:
		return global_position.distance_to(target.global_position) <= range
	return false
func _is_next_to_target() -> bool:
	print("Next to target")
	if target:
		var distance = global_position.distance_to(target.global_position)
		return distance <= 2.0  # Adjust this distance as needed
	return false

# animation funcs
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if health == 0:
		return
	
	if anim_name == "walk-to-run":
		if !reverse_anim_bool:
			print("Finished walk-to-run")
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
	print("Run")
	_return_to_idle()
	
	while animation_player.current_animation != "idle-pistol":
		await get_tree().process_frame
	
	animation_player.play("idle-pistol-to-walk")
	
	while animation_player.current_animation != "walk-pistol":
		await get_tree().process_frame
	
	animation_player.play("walk-to-run")
func _play_hit():
	print("Play hit")
	if health > 0:
		_return_to_idle()
	
	while animation_player.current_animation != "idle-pistol":
		await get_tree().process_frame
	
	animation_player.play("strife-left")
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
