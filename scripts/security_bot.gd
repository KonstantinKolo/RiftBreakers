extends CharacterBody3D

enum States {
	Look,
	Walking,
	Pursuit
}

@export var walkSpeed : float = 1.2
@export var runSpeed : float = 2.4

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/security_bot/Armature/Skeleton3D/Plane_003
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@onready var animation_player: AnimationPlayer = $visuals/security_bot/AnimationPlayer
var combat_anims = ["swing", "combo", "kick"]
var reverse_anim_bool = false

@export var radius: float = 0.35  # Distance from the center of the StaticBody3D
@export var offset: Vector3 = Vector3(0, 1, 0)  # Optional offset from the StaticBody3D's position

var target_visible = false
var health = 100 
var time = 0.0

var state : States = States.Walking
var target : Node3D

func _ready() -> void:
	var next_point = random_target_3d.GetNextPoint()
	print("RandomTarget3D next_point:", next_point)
	print("Global origin:", random_target_3d.global_transform.origin)
	
	ChangeState(States.Walking)
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

func _process(delta):
	if health == 0: 
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if velocity.length() < 0.3 and !_is_next_to_target(): # checks if the bot is stuck
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
	
	#fot material overlays when looked ad
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
	model_3d.material_overlay = ENEMY_OUTLINE
	model_3d.material_overlay.next_pass = ENEMY_STATIC_MATERIAL
func remove_mat_overlay() -> void:
	model_3d.material_overlay = null


# Method to show the health bar
func show_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = true

# Method to hide the health bar
func hide_health_bar() -> void:
	if progress_bar:
		progress_bar.visible = false

func die() -> void:
	follow_target_3d.Speed = 0
	_return_to_idle()
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
			await get_tree().process_frame
		animation_player.play("hit")
	else:
		if progress_bar.value == 0: return
		
		health = 0
		progress_bar.value = health
		die()
		
		
func _return_health() -> int:
	return health

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
			follow_target_3d.SetTarget(target)

# ai funcs
func _on_follow_target_3d_navigation_finished() -> void:
	if health == 0:
		return
	
	if target and _is_next_to_target():
		look_at(target.global_position)
		#play hit animation
		if _check_punchable():
			_return_to_idle()
			while animation_player.current_animation != "idle":
				await get_tree().process_frame
			
			var random_animation = combat_anims[randi() % combat_anims.size()] #Pick a random combat anim
			
			animation_player.play(random_animation) #Play the randomly picked animation
			
			var player_nodes = get_tree().get_nodes_in_group("player")
			await get_tree().create_timer(0.7).timeout
			if _is_next_to_target():
				player_nodes[0].hurt(5) #deal damage to player
		elif !_is_next_to_target():
			if animation_player.current_animation != "run":
				animation_player.play("idle-to-run")
	elif target:
		animation_player.play("idle-to-run")
	else:
		animation_player.play("idle-to-run")
		follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	if health == 0:
		return
	target = body
	ChangeState(States.Pursuit)
func _on_simple_vision_3d_lost_sight() -> void:
	pass
	
	#ChangeState(States.Walking)
func _is_next_to_target() -> bool:
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
		if States.Pursuit:
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
