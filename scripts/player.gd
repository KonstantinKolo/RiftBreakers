extends CharacterBody3D

#TODO overall rifle fix
#TODO when rifle and walk_backwards it doesnt change anim

signal healthChanged
signal staminaChanged
signal blinkStaminaBar

@onready var raycast3D: RayCast3D = get_node("camera_mount/RayCast3D")
@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/SmoothMC/AnimationPlayer
@onready var cross_hair: TextureRect = $camera_mount/Camera3D/CanvasLayer/CrossHair
@onready var stamina_bar: TextureProgressBar = $camera_mount/Camera3D/CanvasLayer/StaminaBar
@onready var rich_text_label: RichTextLabel = $camera_mount/Camera3D/CanvasLayer/RichTextLabel
@onready var death_screen: Control = $camera_mount/Camera3D/CanvasLayer/DeathScreen
@onready var load_screen: Control = $camera_mount/Camera3D/CanvasLayer/LoadScreen

const EMPTY_CIRCLE: Resource = preload("res://assets/models/Icons/empty-circle.png")
const CROSSHAIR: Resource = preload("res://assets/models/Icons/crosshair.svg")

var targeted_enemy: Node = null

var speed: float = 2.0
const JUMP_VELOCITY: float = 4.5

@export var walk_speed: float = 3
@export var backwards_speed: float = 1.5
@export var run_speed: float = 5.5
@export var turn_speed: float = 0.5

@export var fight_speed: float = 1.5
@export var pistol_speed: float = 2
@export var rifle_speed: float = 2.5
@export var throw_speed: float = 2.5

@export var health: int = 100
@export var stamina: int = 100
@export var ray_length: float = 100.0

var reverse_anim_bool: bool = false
var is_jumping: bool = false
var jump_concluded: bool = false
var start_counting_air_time: bool = false
var is_walking_backwards: bool = false

var punch_mode: bool = false
var punch_to_idle: bool = false
var is_punching: bool = false
var is_shooting: bool = false
var has_thrown: bool = false

var is_selecting_mode: bool = false
var is_gun_mode: bool = false
var is_throw_mode: bool = false
var walk_sideways: bool = false

var is_dead: bool = false
var can_regenerate_stamina: bool = true
@export var critical_stamina: bool = false

var selected_weapon: String
var previous_weapon: String
var last_camera_mode: int

var combat_animation_number: int = 0
var air_time: float = 0.0
var death_timer: float = 0.0

@export var sens_horizontal: float = 0.5
@export var sens_vertical: float = 0.5
@export var sens_rotation: float = 2.0

# Bone attachments
@onready var dynamite: MeshInstance3D = $visuals/SmoothMC/Armature/Skeleton3D/BoneAttachment/Dynamite
@onready var pistol: MeshInstance3D = $visuals/SmoothMC/Armature/Skeleton3D/BoneAttachment/Pistol
@onready var rifle: Node3D = $visuals/SmoothMC/Armature/Skeleton3D/BoneAttachment/Rifle
@onready var bone_attachment: BoneAttachment3D = $visuals/SmoothMC/Armature/Skeleton3D/BoneAttachment


func _ready() -> void:
	load_screen.appear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().create_timer(0.1).timeout
	animation_player.play("a-idle")
	if Global.show_fps == true:
		Global.show_fps = false
		Global.signalPlayerFPS.emit()

func _input(event: InputEvent) -> void:
	# So the camera doesnt move after the death screen appears
	if death_timer >= 4.8:
		return
	
	# Camera and player movement events
	if event is InputEventMouseMotion and \
	   (Input.is_action_pressed("right_mouse") and \
	   !punch_mode and !is_gun_mode and !is_throw_mode or is_gun_mode):
		# GUN MODE CAMERA
		if last_camera_mode != 1:
			last_camera_mode = 1
			camera_mount.rotation = Vector3(0, 0, 0)  # Set to default rotation values
		
		camera_mount.rotation.z = 0
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
		camera_mount.rotate_x(deg_to_rad((-event.relative.y*sens_vertical)))
	elif event is InputEventMouseMotion and !punch_mode and \
	!is_gun_mode and !is_throw_mode and !is_selecting_mode:
		# WALK MODE CAMERA
		if last_camera_mode != 2:
			last_camera_mode = 2
			camera_mount.rotation = Vector3(0, 0, 0)  # Set to default rotation values
		
		camera_mount.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		
		# Clamp the vertical rotation to avoid flipping
		var new_rotation_x = camera_mount.rotation.x + deg_to_rad(-event.relative.y * sens_vertical)
		new_rotation_x = clamp(new_rotation_x, deg_to_rad(-90), deg_to_rad(90))
		camera_mount.rotation.x = new_rotation_x
	elif event is InputEventMouseMotion and !is_selecting_mode and \
	(punch_mode or is_throw_mode):
		# Combat, throw and gun mouse mode
		if last_camera_mode != 3:
			last_camera_mode = 3
			camera_mount.rotation = Vector3(0, 0, 0)  # Set to default rotation values
		
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
	elif event is InputEventAction:
		# SAFEGUARD: WALK MODE CAMERA
		if last_camera_mode != 2:
			last_camera_mode = 2
			camera_mount.rotation = Vector3(0, 0, 0)  # Set to default rotation values
		camera_mount.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		# Clamp the vertical rotation to avoid flipping
		var new_rotation_x = camera_mount.rotation.x + deg_to_rad(-event.relative.y * sens_vertical)
		new_rotation_x = clamp(new_rotation_x, deg_to_rad(-90), deg_to_rad(90))
		camera_mount.rotation.x = new_rotation_x
	
	# Combat events
	if health <= 0: return
	if event is InputEventMouseButton or _select_weapon_num():
		# Handle the weapon selection
		# TODO make the SelectionWheel into a variable
		if Input.is_action_just_pressed("mode_selection") and \
		!is_selecting_mode and !$camera_mount/Camera3D/CanvasLayer/SelectionWheel.visible:
			is_selecting_mode = true
			$camera_mount/Camera3D/CanvasLayer/SelectionWheel.show()
		elif _check_mode_changable() or \
			 !$camera_mount/Camera3D/CanvasLayer/SelectionWheel.visible:
			if Input.is_action_just_pressed("mode_selection"):
				selected_weapon = $camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
			elif Input.is_action_just_pressed("One"):
				selected_weapon = "fist"
				$camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
			elif Input.is_action_just_pressed("Two"):
				selected_weapon = "pistol"
				$camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
			elif Input.is_action_just_pressed("Three"):
				if !Global.has_rifle_unlocked: selected_weapon = ""
				else: selected_weapon = "rifle"
				$camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
			elif Input.is_action_just_pressed("Four"):
				if !Global.has_dynamite_unlocked: selected_weapon = ""
				else: selected_weapon = "dynamite"
				$camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
			elif Input.is_action_just_pressed("Five"):
				selected_weapon = "run"
				$camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
				_transition_to_weapon()
		
		# Handle attack functionality
		if Input.is_action_just_pressed("attack") and !is_selecting_mode and \
			stamina >= 10 and !critical_stamina and !is_punching and \
			!is_gun_mode and !is_throw_mode:
			if !punch_mode:
				# Player is in WALK MODE
				is_selecting_mode = true
				is_punching = true
				selected_weapon = "fist"
				_transition_to_weapon()
				
				# wait until the animations are over
				while animation_player.current_animation != "a-idle-fight_":
					if !is_inside_tree(): return
					await get_tree().process_frame
				
				_punch_attack()
			elif punch_mode:
				# Check which mode we have selected when we have multiple modes
				is_punching = true
				speed = 0
				_punch_attack()
		elif Input.is_action_pressed("attack") and \
		is_gun_mode and !is_selecting_mode:
			is_shooting = true
			
			var damage: int
			var rate_of_fire: float
			
			if selected_weapon == "pistol":
				damage = 35
				rate_of_fire = 0.4
			elif selected_weapon == "rifle":
				speed = 0
				damage = 20
				rate_of_fire = 0.2
				
				# Check if the player is moving
				var input_dir := Input.get_vector("left", "right", "forward", "backward")
				var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
				# if its not the right animation for shooting
				# we dont allow the player to shoot
				if animation_player.current_animation != "b-rifle-idle-shoot" and \
				animation_player.current_animation != "b-rifle-idle-walk" and \
				animation_player.current_animation != "b-rifle-idle-to-shoot":
					if direction.length() > 0:
						animation_player.play_backwards("b-rifle-idle-walk")
						reverse_anim_bool = true
						if is_inside_tree():
							await get_tree().create_timer(0.2).timeout
					if animation_player.current_animation == "b-rifle-idle" or \
					animation_player.current_animation == "":
						animation_player.play("b-rifle-idle-to-shoot")
					if is_inside_tree():
						await get_tree().create_timer(0.1).timeout
			while Input.is_action_pressed("attack"):
				# TODO put the relative path in a var
				$camera_mount/GunCast3D.fire_shot(damage)
				_flash_bullet()
				# TODO CREATE A GLOBAL TIMER INSTEAD OF CREATING NEW ONE
				if is_inside_tree():
					await get_tree().create_timer(rate_of_fire).timeout
		elif Input.is_action_pressed("attack") and \
		selected_weapon == "dynamite" and !has_thrown:
			#play throw animation
			has_thrown = true
			speed = 0
			animation_player.speed_scale = 1.5
			animation_player.play("b-throw")
			if is_inside_tree():
				await get_tree().create_timer(1).timeout
			
				var grenadeins = preload("res://scenes/grenade.tscn").instantiate()
				grenadeins.position = $camera_mount/Camera3D/Grenadepos.global_position
				get_tree().current_scene.add_child(grenadeins)
				
				var forward_force = 10
				var upForce = 3.5
				var playerDirection = $camera_mount.global_transform.basis.z.normalized()
				grenadeins.apply_central_impulse((playerDirection * -forward_force) + Vector3(0,upForce,0))
				await get_tree().create_timer(1.45).timeout
				camera_mount.shake_camera(0.4, 0.15)
				has_thrown = false
		elif is_gun_mode:
			if animation_player.current_animation == "b-rifle-idle-shoot" or \
			animation_player.current_animation == "b-rifle-idle-to-shoot":
				animation_player.play_backwards("b-rifle-idle-to-shoot")
				reverse_anim_bool = true
			
			is_shooting = false
			if selected_weapon == "pistol":
				speed = pistol_speed
		
		# Aiming
		if Input.is_action_just_pressed("right_mouse") and \
		is_gun_mode and !is_selecting_mode:
			$camera_mount/Camera3D.fov = 45
		elif Input.is_action_just_released("right_mouse") and \
		is_gun_mode:
			$camera_mount/Camera3D.fov = 75

func _physics_process(delta: float) -> void:
	# functionality for death
	if health <= 0:
		death_timer += delta
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if can_regenerate_stamina: regenerate_stamina(delta)
	elif !can_regenerate_stamina && animation_player.current_animation == "a-run":
		spend_stamina(delta * 2)
	
	# Handle falling without jumping
	if not is_on_floor() and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   animation_player.current_animation != "":
		start_counting_air_time = true
		animation_player.speed_scale = 1.8
		jump_concluded = true
		animation_player.play("a-idle-to-fall")
		
		while not !is_jumping:
			if !is_inside_tree(): return
			await get_tree().process_frame
		
		velocity.y = JUMP_VELOCITY
		start_counting_air_time = true
		
		if is_inside_tree():
			await get_tree().create_timer(0.5).timeout
		jump_concluded = true
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and \
	   !punch_mode and !is_throw_mode and !is_gun_mode and \
	   stamina >= 5 and !critical_stamina and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-fall":
		animation_player.speed_scale = 1.8
		_reverse_animation_to_idle()
		# Wait until reverse_anim_bool is false
		while not !reverse_anim_bool:
			if !is_inside_tree(): return
			await get_tree().process_frame
		
		can_regenerate_stamina = false
		spend_stamina(2)
		
		is_jumping = true;
		animation_player.play("a-jump")
		
		# Wait until is_jumping is false
		while not !is_jumping:
			if !is_inside_tree(): return
			await get_tree().process_frame
		
		velocity.y = JUMP_VELOCITY
		start_counting_air_time = true
		
		if is_inside_tree():
			await get_tree().create_timer(0.5).timeout
		jump_concluded = true
		can_regenerate_stamina = true
	
	if start_counting_air_time: air_time += delta
	
	# Handle the landing
	if animation_player.current_animation == "a-fall" && jump_concluded && is_on_floor():
		start_counting_air_time = false
		jump_concluded = false
		if air_time > 1.2:
			#TODO take damage
			animation_player.play("a-landing")
			speed = 0
		else:
			_reverse_landing()
	
	# Hanlde camera_rotation
	if punch_mode and (camera_mount.rotation.x != 0 or camera_mount.rotation.y != 0): 
		camera_mount.rotation.x = move_toward(camera_mount.rotation.x, 0, delta * 3)
		camera_mount.rotation.y = move_toward(camera_mount.rotation.y, 0, delta * 3)
	
	# safeguard for unwanted actions after death
	if health <= 0: return
	# Handle movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0:
		# Smoothly rotate the character to face the movement direction
		var target_rotation = direction
		var current_forward = -transform.basis.z.normalized()
		var rotation_axis = current_forward.cross(target_rotation).normalized()
		
		if rotation_axis != Vector3.ZERO:  # Avoid rotation when directions are parallel
			var target_basis = (Basis(rotation_axis, current_forward.angle_to(target_rotation)) * transform.basis).orthonormalized()
			transform.basis = transform.basis.slerp(target_basis, sens_rotation * delta)
		
		is_walking_backwards = current_forward.dot(direction) < 0
		
		# If player is pressing just left or right use turning anims
		if !Input.is_action_pressed("forward") and \
		!Input.is_action_pressed("backward") and \
		_check_turnable():
			if Input.is_action_pressed("left"):
				animation_player.speed_scale = 1.5
				speed = turn_speed
				animation_player.play("a-left-turn")
			elif Input.is_action_pressed("right"):
				animation_player.speed_scale = 1.5
				speed = turn_speed
				animation_player.play("a-right-turn")
		elif punch_mode and !is_punching and \
		animation_player.current_animation == "a-idle-fight_":
			sens_rotation = 0
			animation_player.play("a-idle-fight-to-fight-walk")
		elif is_gun_mode and !is_shooting and \
		(animation_player.current_animation == "b-pistol-idle" or \
		animation_player.current_animation == "b-rifle-idle"):
			sens_rotation = 0
			if selected_weapon == "rifle":
				animation_player.play("b-rifle-idle-walk")
			else:
				animation_player.play("b-pistol-idle-walk")
		elif is_gun_mode and is_gun_walkable() and !is_walking_backwards:
			
			sens_rotation = 0
			if selected_weapon == "rifle":
				speed = rifle_speed
				animation_player.speed_scale = 1
				animation_player.play("b-rifle-idle-walk")
			else:
				speed = pistol_speed
				animation_player.speed_scale = 1
				animation_player.play("b-pistol-idle-walk")
		
		if _check_walkable() and !is_walking_backwards and \
		   (!Input.is_action_pressed("sprint") or critical_stamina):
			can_regenerate_stamina = true
			sens_rotation = 2.0
			if animation_player.current_animation == "a-run":
				animation_player.play_backwards("a-walk-to-run")
				reverse_anim_bool = true
			elif animation_player.current_animation == "a-walk-backwards":
				animation_player.play_backwards("a-walk-to-walk-backwards")
				reverse_anim_bool = true
			else:
				animation_player.play("a-idle-to-walk")
				speed = walk_speed
		elif _check_backwards_walkable() and is_walking_backwards:
			if is_gun_mode:
				_reverse_animation_to_gun_idle()
				can_regenerate_stamina = true
				if selected_weapon == "rifle":
					animation_player.play("b-rifle-idle-walk")
				else:
					animation_player.play("b-pistol-idle-walk")
			else:
				sens_rotation = 1.5
				can_regenerate_stamina = true
				if animation_player.current_animation == "a-run":
					animation_player.play_backwards("a-walk-backwards-to-run")
					reverse_anim_bool = true
				elif animation_player.current_animation == "a-walk":
					animation_player.play("a-walk-to-walk-backwards")
				else:
					animation_player.play("a-idle-to-walk-backwards")
					speed = backwards_speed
		elif _check_runable() && Input.is_action_pressed("sprint") and !is_walking_backwards:
			sens_rotation = 3.0
			can_regenerate_stamina = false
			if animation_player.current_animation == "a-walk":
				animation_player.play("a-walk-to-run")
			elif animation_player.current_animation == "a-walk_backwards":
				animation_player.play("a-walk-backwards-to-run")
			else:
				animation_player.play("a-idle-to-run")
				speed = run_speed
		elif !is_walking_backwards and is_gun_mode and \
		(animation_player.current_animation == "b-pistol-walk-backwards" or \
		animation_player.current_animation == "b-rifle-walk-backwards"):
			sens_rotation = 2.0
			_reverse_animation_to_gun_idle()
		
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		is_walking_backwards = false
		can_regenerate_stamina = true
		if animation_player.current_animation == "a-left-turn" \
		or animation_player.current_animation == "a-right-turn":
			_turn_to_idle()
		elif animation_player.current_animation != "a-idle" and \
		!punch_mode and !is_gun_mode:
			_reverse_animation_to_idle()
		elif punch_mode:
			_reverse_animation_to_fight_idle()
		elif is_gun_mode and _can_reverse_to_gun_idle():
			_reverse_animation_to_gun_idle()
			animation_player.speed_scale = 1
			sens_rotation = 2.0
		
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

# Combat system functions
func _punch_attack() -> void:
	targeted_enemy = raycast3D.return_enemy()
	if targeted_enemy == null:
		speed = fight_speed
		animation_player.speed_scale = 1
		spend_stamina(10)
		punch_to_idle = true
		animation_player.play("a-left-punch") #some default animation
	else:
		var direction = _get_direction_to_Node(targeted_enemy)
		
		var to_enemy = targeted_enemy.global_transform.origin - global_transform.origin
		var distance = to_enemy.length()
		
		if distance <= 4.0: # prevents actions if enemy is too far away
			# Offset target position
			if direction.length() > 0.8:
				_launch_forward(direction, targeted_enemy)
			elif direction.length() < 0.73:
				_launch_backwards(direction)
		
		animation_player.speed_scale = 1.35
		var combo_type = _randomizer(7)
		if combo_type == 1:
			animation_player.play("a-c1_c4-0")
		elif combo_type == 2:
			animation_player.play("a-c2-0")
		elif combo_type == 3:
			animation_player.play("a-c3-0")
		elif combo_type == 4:
			animation_player.play("a-c1_c4-0")
		elif combo_type == 5:
			animation_player.play("a-c5-0")
		elif combo_type == 6:
			animation_player.play("a-c6-0")
		elif combo_type == 7:
			animation_player.play("a-c7-0")
func _damage_enemy(damage: int) -> void:
	if targeted_enemy != null:
		targeted_enemy.hurt(damage)
		if targeted_enemy._return_health() == 0:
			targeted_enemy.queue_free()
func _flash_bullet() -> void:
	var bullet = load("res://scenes/ParticleEffects/muzzle_flash.tscn").instantiate()
	bone_attachment.add_child(bullet)
	
	bullet.position.x += 0.1
	bullet.position.z += 0.1
	bullet.position.y += 0.7
	if selected_weapon == "rifle":
		bullet.position.x -= 0.1
		bullet.position.y += 0.35
	bullet.rotation.x = bullet.rotation.x + 8
	
	bullet.shoot()
func _randomizer(numElements: int) -> int:
	return randi() % numElements + 1
func _get_direction_to_Node(targetNode : Node) -> Vector3:
	if targetNode == null:
		return global_position
	else:
		var direction = (targetNode.global_position - global_position).normalized()
		direction.y = 0  # Keep Y-axis unchanged
		return direction
func _launch_backwards(direction: Vector3) -> void:
		direction = -direction.normalized()  # Reverse direction
		var backward_position = global_position + (direction * 0.3) # 0.4 is the backwards distance
		backward_position.y = global_position.y  # Keep Y unchanged
		
		# Move backwards smoothly
		var tween = create_tween()
		tween.tween_property(self, "global_position", backward_position, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) #0.7 is the move time
func _launch_forward(direction: Vector3, target: Node3D) -> void:
	# Calculate direction vector toward the target
	var look_at_direction = (target.global_position - global_position).normalized()
	
	# Calculate the correct Y-axis rotation
	var target_rotation_y = atan2(-look_at_direction.x, -look_at_direction.z)  # Flip signs if needed
	
	# Get current rotation and update only Y-axis
	var target_rotation = rotation
	target_rotation.y = target_rotation_y  # Rotate only on Y-axis
	
	# Calculate target position in front of the enemy
	var target_position = target.global_position - (direction * 1.0)  # Offset in front of the enemy
	target_position.y = global_position.y  # Keep Y level
	
	# Tween for smooth rotation
	var tween = create_tween()
	tween.tween_property(self, "rotation", target_rotation, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # 0.3s for rotation
	
	# Tween for movement
	tween.tween_property(self, "global_position", target_position, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # 0.7s for movement

# Load screen funcs
func load_screen_disappear() -> void:
	load_screen.disappear()

# Item collection
func show_item_text() -> void:
	rich_text_label.visible = true
func hide_item_text() -> void:
	rich_text_label.visible = false

# Stamina system functions
func spend_stamina(amount: int) -> void:
	if stamina < amount:
		stamina = 0
	else:
		stamina -= amount
	staminaChanged.emit()
func regenerate_stamina(delta: float) -> void:
	if stamina < 100:
		stamina += 1.7 * delta
		stamina = min(stamina, 100)
		staminaChanged.emit()
# Health system functions
func heal(amount: int) -> void:
	if amount + health > 100:
		health = 100
	else:
		health += amount 
	healthChanged.emit()
func hurt(hit_points: int) -> void:
	if is_dead: return
	if hit_points < health:
		health -= hit_points
	else:
		health = 0
	if health == 0:
		die()
	healthChanged.emit()
func die() -> void:
	is_dead = true
	speed = 0
	_reverse_animation_to_idle()
	
	var timer := 0.0
	while animation_player.current_animation != "a-idle":
		var delta := get_process_delta_time()
		timer += delta
		if timer >= 0.5:
			break
		if !is_inside_tree(): return
		await get_tree().process_frame
	
	animation_player.play("a-death")
func _after_death() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	death_screen.appear()

# Animation transition functions
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "a-idle-to-walk":
		if !reverse_anim_bool:
			animation_player.play("a-walk")
		else:
			speed = walk_speed
			animation_player.play("a-idle")
			reverse_anim_bool = false
	elif anim_name == "a-death":
		_after_death()
	elif anim_name == "a-left-turn" or anim_name == "a-right-turn":
		animation_player.speed_scale = 1
		animation_player.play("a-idle")
	elif anim_name == "a-idle-to-walk-backwards":
		if !reverse_anim_bool:
			animation_player.play("a-walk-backwards")
		else:
			animation_player.play("a-idle")
			speed = walk_speed
			reverse_anim_bool = false
	elif anim_name == "a-idle-to-run":
		if !reverse_anim_bool:
			animation_player.play("a-run")
		else:
			speed = run_speed
			animation_player.play("a-idle")
			reverse_anim_bool = false
	elif anim_name == "a-walk-to-walk-backwards":
		if !reverse_anim_bool:
			animation_player.play("a-walk-backwards")
		else:
			animation_player.play("a-walk")
	elif anim_name == "a-walk-to-run":
		if !reverse_anim_bool:
			animation_player.play("a-run")
			speed = run_speed
		else:
			animation_player.play("a-walk")
			speed = walk_speed
			reverse_anim_bool = false;
	elif anim_name == "a-jump":
		if !reverse_anim_bool:
			is_jumping = false;
			animation_player.speed_scale = 1.0
			animation_player.play("a-fall")
		else:
			animation_player.speed_scale = 1.0
			air_time = 0
			reverse_anim_bool = false
			animation_player.play("a-idle")
	elif anim_name == "a-landing":
		speed = walk_speed
		air_time = 0
		animation_player.play("a-idle")
	elif anim_name == "a-idle-to-fall":
		if !reverse_anim_bool:
			is_jumping = false
			animation_player.play("a-fall")
			animation_player.speed_scale = 1
		else:
			animation_player.speed_scale = 1.0
			air_time = 0
			reverse_anim_bool = false
			if !punch_mode:
				animation_player.play("a-idle")
			else:
				animation_player.play("a-idle-fight_")
	elif anim_name == "a-idle-to-fight":
		if !reverse_anim_bool:
			animation_player.play("a-idle-fight_")
			speed = fight_speed
		else:
			animation_player.play("a-idle")
			reverse_anim_bool = false
			speed = walk_speed
	elif anim_name == "a-idle-fight-to-fight-walk":
		if !reverse_anim_bool:
			animation_player.play("a-fight-walk")
		else:
			animation_player.play("a-idle-fight_")
			reverse_anim_bool = false
	elif anim_name == "a-left-turn" or anim_name == "a-right-turn":
		animation_player.play("a-idle")
		speed = walk_speed
	elif anim_name == "b-throw":
		speed = throw_speed
		animation_player.speed_scale = 1
		animation_player.play("b-throw-idle")
	elif anim_name == "b-throw-idle":
		animation_player.play("a-idle")
	elif is_gun_mode:
		if anim_name == "b-rifle-idle-walk":
			if walk_sideways:
				animation_player.play("b-rifle-left")
			elif is_walking_backwards:
				animation_player.play("b-rifle-walk-backwards")
			elif !reverse_anim_bool:
				animation_player.play("b-rifle-walk")
			else:
				animation_player.play("b-rifle-idle")
				reverse_anim_bool = false
		elif anim_name == "b-pistol-idle-walk":
			if walk_sideways:
				animation_player.play("b-pistol-left")
			elif is_walking_backwards:
				animation_player.play("b-pistol-walk-backwards")
			elif !reverse_anim_bool:
				animation_player.play("b-pistol-walk")
			else:
				animation_player.play("b-pistol-idle")
				reverse_anim_bool = false
		elif anim_name == "b-rifle-idle-to-shoot":
			if !reverse_anim_bool:
				animation_player.play("b-rifle-idle-shoot")
			else:
				animation_player.play("b-rifle-idle")
				reverse_anim_bool = false
			
	elif punch_mode:
		if anim_name == "a-left-punch" and punch_to_idle:
			animation_player.play("a-left-punch-to-idle-fight")
			is_punching = false
			reverse_anim_bool = false
			spend_stamina(10)
		elif anim_name == "a-c1_c4-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 1
			animation_player.play("a-left-punch")
		elif anim_name == "a-c2-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 2
			animation_player.play("a-right-punch")
		elif anim_name == "a-c3-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 3
			animation_player.play("a-right-high-kick")
			
			if is_inside_tree():
				await get_tree().create_timer(0.2).timeout
				var enemy : Node = get_node("camera_mount/RayCast3D").return_enemy()
				var direction = _get_direction_to_Node(enemy)
				_launch_backwards(direction)
		elif anim_name == "a-c5-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 5
			animation_player.play("a-left-jab-into-elbow")
		elif anim_name == "a-c6-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 6
			animation_player.play("a-left-mma-kick")
		elif anim_name == "a-c7-0":
			spend_stamina(10)
			_damage_enemy(20)
			combat_animation_number = 7
			animation_player.play("a-right-deep-uppercut")
		elif anim_name == "a-c1-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-elbow")
		elif anim_name == "a-c2-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-jab-into-elbow")
		elif anim_name == "a-c3-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-punch")
		elif anim_name == "a-c4-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-punch")
		elif anim_name == "a-c5-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-knee")
		elif anim_name == "a-c6-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-elbow")
		elif anim_name == "a-c7-1":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-kick")
		elif anim_name == "a-c1-2":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-jab")
		elif anim_name == "a-c3-2":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-punch")
		elif anim_name == "a-c4-2":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-kick")
		elif anim_name == "a-c6-2":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-left-punch")
		elif anim_name == "a-c7-2":
			spend_stamina(10)
			_damage_enemy(20)
			animation_player.play("a-right-punch")
		elif Input.is_action_pressed("attack") and stamina >= 10 and \
		!_a_c_animation_checker(anim_name):
			if anim_name == "a-left-jab":
				#only is in a-c1
				animation_player.play("a-c1-3")
			elif anim_name == "a-right-deep-uppercut":
				animation_player.play("a-c7-1")
			elif anim_name == "a-left-mma-kick":
				animation_player.play("a-c6-1")
			elif anim_name == "a-right-high-kick":
				#only is in a-c3
				animation_player.play("a-c3-1")
				
				var direction = _get_direction_to_Node(targeted_enemy)
				_launch_forward(direction,targeted_enemy)
			elif anim_name == "a-right-knee":
				animation_player.play("a-c5-2")
			elif anim_name == "a-left-jab-into-elbow":
				if combat_animation_number == 2:
					animation_player.play("a-c2-2")
				elif combat_animation_number == 5:
					animation_player.play("a-c5-1")
				else:
					# a-left-jab-into-elbow in _on_animation_end: combat animation number is incorrect
					pass
			elif anim_name == "a-left-kick":
				if combat_animation_number == 4:
					animation_player.play("a-c4-3")
				elif combat_animation_number == 7:
					animation_player.play("a-c7-2")
				else:
					# a-left-kick in _on_animation_end: combat animation number is incorrect
					pass
			elif anim_name == "a-right-punch":
				if combat_animation_number == 2:
					animation_player.play("a-c2-1")
				elif combat_animation_number == 3:
					animation_player.play("a-c3-3")
				elif combat_animation_number == 4:
					animation_player.play("a-c4-2")
				elif combat_animation_number == 7:
					animation_player.play("a-c7-3")
				else:
					# a-right-punch in _on_animation_end: combat animation number is incorrect
					pass
			elif anim_name == "a-right-elbow":
				if combat_animation_number == 1:
					animation_player.play("a-c1-2")
				elif combat_animation_number == 6:
					animation_player.play("a-c6-2")
				else:
						# a-right-elbow in _on_animation_end: combat animation number is incorrect
						pass
			elif anim_name == "a-left-punch":
				if combat_animation_number == 4 or combat_animation_number == 1:
					var rand = _randomizer(2)
					if rand == 1:
						combat_animation_number = 1
						animation_player.play("a-c1-1")
					else:
						combat_animation_number = 4
						animation_player.play("a-c4-1")
				elif combat_animation_number == 3:
					animation_player.play("a-c3-2")
				elif combat_animation_number == 6:
					animation_player.play("a-c6-3")
				else:
					# a-left-punch in _on_animation_end: combat animation number is incorrect
					pass
		else:
			is_punching = false
			animation_player.speed_scale = 1
			
			if !punch_to_idle:
				_launch_backwards(global_position)
			
			punch_to_idle = false
			animation_player.play("a-idle-fight_")
			speed = fight_speed
	else:
		pass
func _a_c_animation_checker(text: String) -> bool:
	if str(text[0] + text[1] + text[2]) == "a-c":
		return true
	else: return false

# More animtion transition functions
func _reverse_animation_to_idle() -> void:
	if animation_player.current_animation == "a-walk":
		animation_player.play_backwards("a-idle-to-walk")
		reverse_anim_bool = true
	elif animation_player.current_animation == "a-walk-backwards":
		animation_player.play_backwards("a-idle-to-walk-backwards")
		reverse_anim_bool = true
	elif animation_player.current_animation == "a-run":
		animation_player.play_backwards("a-idle-to-run")
		reverse_anim_bool = true
		speed = walk_speed
func _reverse_animation_to_fight_idle() -> void:
	if animation_player.current_animation == "a-left-punch":
		animation_player.play_backwards("a-left-punch")
		reverse_anim_bool = true
	elif animation_player.current_animation == "a-right-punch":
		animation_player.play_backwards("a-right-punch")
		reverse_anim_bool = true
	elif animation_player.current_animation == "a-fight-walk":
		animation_player.play_backwards("a-idle-fight-to-fight-walk")
		reverse_anim_bool = true
func _reverse_animation_to_gun_idle():
	if animation_player.current_animation == "b-pistol-left" or animation_player.current_animation == "b-rifle-left":
		walk_sideways = false
		if selected_weapon == "rifle":
			$visuals.scale.x = 1
			reverse_anim_bool = true
			animation_player.play_backwards("b-rifle-idle-walk")
		else:
			$visuals.scale.x = 1
			reverse_anim_bool = true
			animation_player.play_backwards("b-pistol-idle-walk")
	elif selected_weapon == "rifle":
		if animation_player.current_animation == "b-rifle-walk":
			animation_player.play_backwards("b-rifle-idle-walk")
			reverse_anim_bool = true
		elif animation_player.current_animation == "b-rifle-walk-backwards":
			animation_player.play_backwards("b-rifle-idle-walk")
			reverse_anim_bool = true
	else:
		if animation_player.current_animation == "b-pistol-walk":
			animation_player.play_backwards("b-pistol-idle-walk")
			reverse_anim_bool = true
		elif animation_player.current_animation == "b-pistol-walk-backwards":
			animation_player.play_backwards("b-pistol-idle-walk")
			reverse_anim_bool = true
func _can_reverse_to_gun_idle() -> bool:
	if animation_player.current_animation != "b-pistol-idle-walk" and \
	animation_player.current_animation != "b-rifle-idle-walk" and \
	animation_player.current_animation != "b-pistol-idle" and \
	animation_player.current_animation != "b-rifle-idle":
		return true
	return false
func _turn_to_idle() -> void:
	speed = turn_speed
	if animation_player.current_animation_position < animation_player.current_animation_length / 2:
		animation_player.speed_scale = -1.5 # when animation is past the half way
func _reverse_landing() -> void:
	animation_player.speed_scale = 1.8
	animation_player.play_backwards("a-idle-to-fall")
	reverse_anim_bool = true
func _transition_to_weapon() -> void:
	#Transition back to idle mode
	if selected_weapon == previous_weapon:
		is_selecting_mode = false
		return
	
	match previous_weapon:
		"run":
			speed = 0
			is_selecting_mode = false
		"fist":
			speed = 0
			_punch_mode_to_idle()
		"pistol":
			speed = 0
			is_gun_mode = false
			_pistol_to_idle()
		"rifle":
			speed = 0
			is_gun_mode = false
			_rifle_to_idle()
		"dynamite":
			speed = 0
			is_throw_mode = false
			_dynamite_to_idle()
	speed = 0
	is_throw_mode = false
	is_gun_mode = false
	punch_mode = false
	is_selecting_mode = false
	
	# wait until we get into idle animation for "fist"
	# mode, because it takes a bit longer than others
	var timer := 0.0
	if previous_weapon == "fist":
		while animation_player.current_animation != "a-idle":
			var delta := get_process_delta_time()
			timer += delta
			if timer >= 0:
				animation_player.play("a-idle")
			
			if !is_inside_tree(): return
			await get_tree().process_frame
	
	# Transition from idle to other modes
	match selected_weapon:
		"run":
			speed = walk_speed
		"fist":
			_punch_mode_transition()
		"pistol":
			is_gun_mode = true
			_pistol_transition()
		"rifle":
			is_gun_mode = true
			_rifle_transition()
		"dynamite":
			is_throw_mode = true
			_dynamite_transition()
	
	is_selecting_mode = false
	if selected_weapon != "":
		previous_weapon = selected_weapon

# From idle animatios
func _punch_mode_transition() -> void:
	if !_check_mode_changable():
		is_selecting_mode = false
		is_punching = false
		speed = fight_speed
		return
	#stop movement until switch is over
	punch_mode = true
	_reverse_animation_to_idle()
	speed = 0
	while animation_player.current_animation != "a-idle":
		if !is_inside_tree(): return
		await get_tree().process_frame
	animation_player.play("a-idle-to-fight")
	cross_hair.texture = CROSSHAIR
	cross_hair.size = Vector2(60,60)
	cross_hair.position.x -= 10
	cross_hair.position.y -= 10
	is_selecting_mode = false
func _dynamite_transition() -> void:
	speed = 0
	animation_player.play("b-idle-pulldynamite-idle")
	if is_inside_tree():
		await get_tree().create_timer(0.75).timeout
	dynamite.visible = true
	speed = throw_speed
func _pistol_transition() -> void:
	speed = 0
	animation_player.play("b-pull-pistol")
	if is_inside_tree():
		await get_tree().create_timer(0.4).timeout
	pistol.visible = true
	speed = pistol_speed
func _rifle_transition() -> void:
	speed = 0
	animation_player.play("b-pull-gun")
	if is_inside_tree():
		await get_tree().create_timer(1).timeout
	rifle.visible = true
	speed = rifle_speed

# To idle animations
func _punch_mode_to_idle() -> void:
	# reset the crosshair to normal
	cross_hair.texture = EMPTY_CIRCLE
	cross_hair.size = Vector2(40,40)
	cross_hair.position.x += 10
	cross_hair.position.y += 10
	
	#animation_player.play("a-idle-fight_")
	
	reverse_anim_bool = true
	animation_player.play_backwards("a-idle-to-fight")
	
	while animation_player.current_animation != "a-idle":
		if !is_inside_tree(): return
		await get_tree().process_frame
	
	is_selecting_mode = false
	punch_mode = false
	is_punching = false
func _dynamite_to_idle() -> void:
	speed = 0
	animation_player.play_backwards("b-idle-pulldynamite-idle")
	if is_inside_tree():
		await get_tree().create_timer(0.75).timeout
	dynamite.visible = false
	speed = walk_speed
	is_selecting_mode = false
func _pistol_to_idle() -> void:
	speed = 0
	animation_player.play_backwards("b-pull-pistol")
	if is_inside_tree():
		await get_tree().create_timer(0.8).timeout
	pistol.visible = false
	speed = walk_speed
	is_selecting_mode = false
func _rifle_to_idle() -> void:
	speed = 0
	animation_player.play_backwards("b-pull-gun")
	if is_inside_tree():
		await get_tree().create_timer(1).timeout
	rifle.visible = false
	speed = walk_speed
	is_selecting_mode = false

# Boolean functions
func _select_weapon_num() -> bool:
	if Input.is_action_just_pressed("One") or \
	   Input.is_action_just_pressed("Two") or \
	   Input.is_action_just_pressed("Three") or \
	   Input.is_action_just_pressed("Four") or \
	   Input.is_action_just_pressed("Five"):
		return true
	return false
func is_gun_walkable() -> bool:
	var anim = animation_player.current_animation
	if anim != "b-idle-pull-gun" and \
	anim != "b-pistol-hit" and \
	anim != "b-pistol-idle-hit" and \
	anim != "b-pistol-idle-whip" and \
	anim != "b-pistol-whip" and \
	anim != "b-pull-gun" and \
	anim != "b-pull-gun-gun" and \
	anim != "b-pull-pistol" and \
	anim != "b-rifle-hit" and \
	anim != "b-rifle-idle-shoot" and \
	anim != "b-rifle-idle-to-shoot" and \
	anim != "b-rifle-walk-shoot" and \
	anim != "b-rifle-walk-to-shoot" and \
	anim != "b-rifle-walk" and \
	anim != "b-rifle-idle-walk" and \
	anim != "b-pistol-idle-walk" and \
	anim != "b-pistol-walk-to-left" and \
	anim != "b-rifle-walk-to-left" and \
	anim != "b-pistol-walk" and \
	walk_sideways == false and !is_shooting:
		return true
	return false
func _check_mode_changable() -> bool:
	if is_on_floor() and health > 0 and \
	animation_player.current_animation != "a-jump" and \
	animation_player.current_animation != "a-landing" and \
	animation_player.current_animation != "a-fall" and \
	animation_player.current_animation != "a-idle-to-fall" and \
	animation_player.current_animation != "a-falling" and \
	animation_player.current_animation != "a-idle-to-walk" and \
	animation_player.current_animation != "a-idle-to-walk-backwards" and \
	animation_player.current_animation != "a-idle-to-run" and \
	animation_player.current_animation != "a-walk-to-run" and \
	animation_player.current_animation != "a-walk-backwards-to-run":
		return true
	else: return false
func _check_turnable() -> bool:
	if animation_player.current_animation != "a-idle-to-walk" and \
	animation_player.current_animation != "a-idle-to-walk-backwards" and \
	animation_player.current_animation != "a-jump" and \
	animation_player.current_animation != "a-fall" and \
	animation_player.current_animation != "a-landing" and \
	animation_player.current_animation != "a-idle-to-fall" and \
	animation_player.current_animation != "a-right-turn" and \
	animation_player.current_animation != "a-left-turn" and \
	is_on_floor() and !punch_mode and !is_gun_mode:
		return true
	return false
func _check_gun_turnable() -> bool:
	if animation_player.current_animation != "b-rifle-idle-walk" and \
	animation_player.current_animation != "b-rifle-walk-to-left" and \
	animation_player.current_animation != "b-rifle-left" and \
	animation_player.current_animation != "b-pistol-idle-walk" and \
	animation_player.current_animation != "b-pistol-walk-to-left" and \
	animation_player.current_animation != "b-pistol-left":
		return true
	return false
func _check_walkable() -> bool:
	if animation_player.current_animation != "a-walk" and \
	   animation_player.current_animation != "a-idle-to-walk" and \
	   animation_player.current_animation != "a-idle-to-walk-backwards" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-walk-backwards-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   animation_player.current_animation != "a-left-turn" and \
	   animation_player.current_animation != "a-right-turn" and \
	   animation_player.current_animation != "b-throw" and \
	   !punch_mode and !is_gun_mode and speed > 0:
		return true
	else:
		return false
func _check_backwards_walkable() -> bool:
	if animation_player.current_animation != "a-walk-backwards" and \
	   animation_player.current_animation != "a-idle-to-walk" and \
	   animation_player.current_animation != "a-idle-to-walk-backwards" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-walk-backwards-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-left-turn" and \
	   animation_player.current_animation != "a-right-turn" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   animation_player.current_animation != "b-throw" and \
	   animation_player.current_animation != "b-rifle-idle-walk" and \
	   animation_player.current_animation != "b-pistol-idle-walk" and \
	   animation_player.current_animation != "b-rifle-walk-backwards" and \
	   animation_player.current_animation != "b-pistol-walk-backwards" and \
	   !punch_mode and speed > 0:
		return true
	else:
		return false
func _check_runable() -> bool:
	if stamina == 0:
		blinkStaminaBar.emit()
		critical_stamina = true
		return false
	elif stamina > 0 and !critical_stamina and \
	   animation_player.current_animation != "a-run" and \
	   animation_player.current_animation != "a-idle-to-run" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-walk-backwards-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   animation_player.current_animation != "a-left-turn" and \
	   animation_player.current_animation != "a-right-turn" and \
	   animation_player.current_animation != "b-throw" and \
	   !punch_mode and !is_gun_mode and speed > 0:
		return true
	else:
		return false
