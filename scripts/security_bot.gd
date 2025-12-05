extends CharacterBody3D

enum States {
	Look,
	Walking,
	Pursuit
}

@export var custom_material_overlay : StandardMaterial3D = null

@export var walkSpeed : float = 1.2
@export var runSpeed : float = 2.4

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D

var stuck_time := 0.0
var stuck_threshold := 2.0
var min_movement_threshold := 0.05
var last_position := Vector3.ZERO
var is_stuck := false

var fading_out: bool = false
var fade_speed: float = 0.2 # alpha units per second

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/security_bot/Armature/Skeleton3D/Plane_003
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@onready var animation_player: AnimationPlayer = $visuals/security_bot/AnimationPlayer
var combat_anims = ["swing", "combo", "kick"]
var reverse_anim_bool = false

var offset: Vector3 = Vector3(0, 1, 0)  # offset for the target that appears

var player_target: CharacterBody3D = null
var target_visible = false
@export var health = 100 
var time = 0.0

@export var reach_target_distance := 1.3
var state : States = States.Walking
var target : Node3D

func _ready() -> void:
	follow_target_3d.target_desired_distance = reach_target_distance
	var next_point = random_target_3d.GetNextPoint()
	ChangeState(States.Walking)
	
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.max_value = health
	progress_bar.value = health

func _process(delta):
	if fading_out:
		_fade_out(delta)
	
	if health <= 0: 
		if !fading_out: fading_out = true
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	
	# logic for when the bot gets stuck
	var distance_moved = global_position.distance_to(last_position)
	if distance_moved < min_movement_threshold:
		stuck_time += delta
		if stuck_time > stuck_threshold and !is_stuck:
			is_stuck = true
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
	else:
		if animation_player.current_animation == "idle":
			animation_player.play("idle-to-run")
		stuck_time = 0.0
		is_stuck = false
	last_position = global_position
	if velocity.length() < 0.3 and !_is_next_to_target() and state != States.Look and player_target == null:
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
	
	
	if state == States.Look:
		if animation_player.current_animation == "idle":
			var random_animation = combat_anims[randi() % combat_anims.size()] #Pick a random combat anim
			animation_player.play(random_animation) #Play the randomly picked animation
			_await_damage(5)
	
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
		Global.on_boss_killed()
		Global.has_unlocked_level_2 = true
	else: 
		Global.on_melee_killed()
	
	follow_target_3d.Speed = 0
	_return_to_idle()
	if !is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	if animation_player.current_animation != "death": 
		animation_player.play("death")
func hurt(hit_points: int) -> void:
	if hit_points < health:
		health -= hit_points
		progress_bar.value = health
		#play hurt anim
		follow_target_3d.Speed = 0.9
		_return_to_idle()
		while animation_player.current_animation != "idle":
			if !is_inside_tree(): return
			await get_tree().process_frame
		animation_player.play("hit")
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

func _await_damage(amount: int):
	var player_nodes = get_tree().get_nodes_in_group("player")
	if is_inside_tree():
		await get_tree().create_timer(0.7).timeout
	if _is_next_to_target(2.5):
		player_nodes[0].hurt(5)

func ChangeState(newState : States) -> void:
	if health == 0:
		return
	
	state = newState
	match state:
		States.Look:
			follow_target_3d.ClearTarget()
			if target:
				look_at(target.global_position, Vector3.UP)
		States.Walking:
			animation_player.play("walk");
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			
			target = null
		States.Pursuit:
			if !_is_combat_anim():
				animation_player.play("walk-to-run")
			follow_target_3d.Speed = runSpeed
			if player_target == null:
				follow_target_3d.SetTarget(target)
			else:
				follow_target_3d.SetTarget(player_target)

# ai funcs
func _on_follow_target_3d_navigation_finished() -> void:
	if health == 0:
		return
	
	if scale.x > 1:
		_boss_follow_logic()
	if (target or player_target) and _is_next_to_target():
		look_at(target.global_position)
		#play hit animation
		if _check_punchable():
			_return_to_idle()
			while animation_player.current_animation != "idle":
				if !is_inside_tree(): return
				await get_tree().process_frame
			
			var random_animation = combat_anims[randi() % combat_anims.size()] #Pick a random combat anim
			
			animation_player.play(random_animation) #Play the randomly picked animation
			
			if is_inside_tree():
				var player_nodes = get_tree().get_nodes_in_group("player")
				await get_tree().create_timer(0.7).timeout
				if _is_next_to_target():
					player_nodes[0].hurt(5) #deal damage to player
		elif !_is_next_to_target():
			if animation_player.current_animation != "run":
				animation_player.play("idle-to-run")
	elif target and !player_target:
		animation_player.play("idle-to-run")
	elif player_target:
		animation_player.play("idle")
		await get_tree().create_timer(0.5).timeout
	else:
		animation_player.play("idle-to-run")
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
func _boss_follow_logic() -> void:
	if animation_player.current_animation != "idle" and \
	   animation_player.current_animation != combat_anims[0] and \
	   animation_player.current_animation != combat_anims[1] and \
	   animation_player.current_animation != combat_anims[2]:
		animation_player.play("idle")
		await get_tree().create_timer(0.1).timeout
		follow_target_3d.Speed = 0
		velocity = Vector3.ZERO
		
	ChangeState(States.Look)
	while _is_within_range(reach_target_distance):
		if !is_inside_tree(): return
		await get_tree().process_frame
	if state != States.Pursuit:
		ChangeState(States.Pursuit)
func _is_within_range(range: float) -> bool:
	if target:
		return global_position.distance_to(target.global_position) <= range
	return false
func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	if health == 0:
		return
	target = body
	if player_target == null:
		player_target = body
	
	ChangeState(States.Pursuit)
func _on_simple_vision_3d_lost_sight() -> void:
	pass
	
	#ChangeState(States.Walking)
func _is_next_to_target(max_distance := 2.0) -> bool:
	if target:
		var distance = global_position.distance_to(target.global_position)
		return distance <= max_distance  # Adjust this distance as needed
	return false

# animation funcs
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if health == 0:
		return
	
	if anim_name == "walk-to-run":
		if !reverse_anim_bool:
			animation_player.play("run")
		else:
			animation_player.play("walk")
			reverse_anim_bool = false
	elif anim_name == "idle-to-run":
		if reverse_anim_bool:
			animation_player.play("idle")
			reverse_anim_bool = false
		else:
			follow_target_3d.Speed = runSpeed
			animation_player.play("run")
	elif anim_name == "idle-to-walk":
		if reverse_anim_bool:
			animation_player.play("idle")
			reverse_anim_bool = false
		else: 
			animation_player.play("walk")
	elif anim_name == "hit":
		follow_target_3d.Speed = runSpeed
		animation_player.speed_scale = 1
		animation_player.play("idle-to-run")
	elif anim_name == combat_anims[0] or \
		 anim_name == combat_anims[1] or \
		 anim_name == combat_anims[2]:
		if state == States.Pursuit:
			animation_player.play("walk-to-run")
		else:
			animation_player.play("idle")
func _return_to_idle():
	if animation_player.current_animation == "run":
		reverse_anim_bool = true
		animation_player.play_backwards("idle-to-run")
	elif animation_player.current_animation == "walk":
		reverse_anim_bool = true
		animation_player.play_backwards("idle-to-walk")
	else:
		if !is_inside_tree(): return
		await get_tree().create_timer(0.5).timeout
		animation_player.play("idle")
		
func _is_combat_anim():
	if animation_player.current_animation != "combo" and \
	   animation_player.current_animation != "swing" and \
	   animation_player.current_animation != "kick" and \
	   animation_player.current_animation != "hit":
		return false
	return true
func _check_runable():
	if animation_player.current_animation != "hit" and \
	   animation_player.current_animation != "idle-to-run" and \
	   follow_target_3d.Speed != 0.9 and \
	   animation_player.current_animation != "idle-to-walk":
		return true
	return false
func _check_punchable():
	if animation_player.current_animation != "hit" and \
	   animation_player.current_animation != "idle-to-walk" and \
	   animation_player.current_animation != "idle-to-run" and \
	   animation_player.current_animation != "combo" and \
	   animation_player.current_animation != "swing" and \
	   animation_player.current_animation != "kick" and \
	   follow_target_3d.Speed != 0.9 and \
	   _is_next_to_target():
		return true
	return false
