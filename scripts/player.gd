extends CharacterBody3D

signal healthChanged
signal staminaChanged
signal blinkStaminaBar

@onready var raycast3D : RayCast3D = get_node("camera_mount/RayCast3D")
@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/SmoothMC/AnimationPlayer
@onready var cross_hair: TextureRect = $camera_mount/Camera3D/CanvasLayer/CrossHair
@onready var stamina_bar: TextureProgressBar = $camera_mount/Camera3D/CanvasLayer/StaminaBar
@onready var rich_text_label: RichTextLabel = $camera_mount/Camera3D/CanvasLayer/RichTextLabel
const EMPTY_CIRCLE = preload("res://assets/models/Icons/empty-circle.png")
const CROSSHAIR = preload("res://assets/models/Icons/crosshair.svg")

var targeted_enemy : Node = null

var speed = 2
const JUMP_VELOCITY = 4.5

@export var health = 100
@export var stamina = 100
@export var ray_length = 100.0

var reverse_anim_bool = false
var is_jumping = false
var jump_concluded = false
var start_counting_air_time = false

var punch_mode = false
var punch_to_idle = false
var is_punching = false

var is_selecting_mode = false
var is_gun_mode = false
var is_throw_mode = false

var can_regenerate_stamina = true
@export var critical_stamina = false

var selected_weapon
var previous_weapon

var combat_animation_number = 0
var air_time = 0.0

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5
@export var sens_rotation = 2.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_player.animation_finished.connect(self._on_animation_player_animation_finished)
	await get_tree().create_timer(0.1).timeout
	animation_player.play("a-idle")
	if Global.show_fps == true:
		Global.show_fps = false
		Global.signalPlayerFPS.emit()


func _input(event):
	# Camera and player movement events
	if event is InputEventMouseMotion and \
	   Input.is_action_pressed("right_mouse") and \
	   !punch_mode:
		# TODO in a-idle reseting the z axis is kinda jittery
		camera_mount.rotation.z = 0
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
		camera_mount.rotate_x(deg_to_rad((-event.relative.y*sens_vertical)))
	elif event is InputEventMouseMotion and !punch_mode and !is_selecting_mode:
		camera_mount.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		
		# Clamp the vertical rotation to avoid flipping
		var new_rotation_x = camera_mount.rotation.x + deg_to_rad(-event.relative.y * sens_vertical)
		new_rotation_x = clamp(new_rotation_x, deg_to_rad(-90), deg_to_rad(90))
		camera_mount.rotation.x = new_rotation_x
	# Combat mouse mode
	elif event is InputEventMouseMotion and punch_mode and !is_selecting_mode:
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
	
	# Combat events
	if event is InputEventMouseButton:
		# Handle the weapon selection
		if Input.is_action_just_pressed("mode_selection") and \
		!is_selecting_mode:
			is_selecting_mode = true
			$camera_mount/Camera3D/CanvasLayer/SelectionWheel.show()
		elif Input.is_action_just_pressed("mode_selection") and _check_mode_changable():
			selected_weapon = $camera_mount/Camera3D/CanvasLayer/SelectionWheel.Close()
			
			_transition_to_weapon()
		
		# Handle attack functionality
		if Input.is_action_just_pressed("attack") and !is_selecting_mode and \
			stamina >= 10 and !critical_stamina and !is_punching and \
			!is_gun_mode and !is_throw_mode:
			if !punch_mode:
				is_selecting_mode = true
				is_punching = true
				selected_weapon = "fist"
				_transition_to_weapon()
				
				# wait until the animations are over
				while animation_player.current_animation != "a-idle-fight_":
						await get_tree().process_frame
				
				_punch_attack()
			elif punch_mode:
				# Check which mode we have selected when we have multiple modes
				is_punching = true
				speed = 0
				_punch_attack()
		elif Input.is_action_pressed("attack") and \
		is_gun_mode and !is_selecting_mode:
			var damage: int
			if selected_weapon == "pistol":
				damage = 35
			elif selected_weapon == "rifle":
				damage = 20
			$camera_mount/GunCast3D.fire_shot(damage)
		elif Input.is_action_pressed("attack") and selected_weapon == "dynamite":
			var grenadeins = preload("res://scenes/grenade.tscn").instantiate()
			grenadeins.position = $camera_mount/Camera3D/Grenadepos.global_position
			get_tree().current_scene.add_child(grenadeins)
			
			var forward_force = 10
			var upForce = 3.5
			var playerDirection = $camera_mount.global_transform.basis.z.normalized()
			grenadeins.apply_central_impulse((playerDirection * -forward_force) + Vector3(0,upForce,0))
			await get_tree().create_timer(1.45).timeout
			camera_mount.shake_camera(0.4, 0.15)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if can_regenerate_stamina: regenerate_stamina(delta)
	elif !can_regenerate_stamina && animation_player.current_animation == "a-run":
		spend_stamina(delta * 5)
	
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
			await get_tree().process_frame
		
		velocity.y = JUMP_VELOCITY
		start_counting_air_time = true
		
		await get_tree().create_timer(0.5).timeout
		jump_concluded = true
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and \
	   !punch_mode and stamina >= 10 and !critical_stamina and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-fall":
		animation_player.speed_scale = 1.8
		_reverse_animation_to_idle()
		# Wait until reverse_anim_bool is false
		while not !reverse_anim_bool:
			await get_tree().process_frame
		
		can_regenerate_stamina = false
		spend_stamina(10)
		
		is_jumping = true;
		animation_player.play("a-jump")
		
		# Wait until is_jumping is false
		while not !is_jumping:
			await get_tree().process_frame
		
		velocity.y = JUMP_VELOCITY
		start_counting_air_time = true
		
		await get_tree().create_timer(0.5).timeout
		jump_concluded = true
		can_regenerate_stamina = true
	
	if start_counting_air_time: air_time += delta
	
	# Handle the landing
	if animation_player.current_animation == "a-fall" && jump_concluded && is_on_floor():
		start_counting_air_time = false
		jump_concluded = false
		if air_time > 1.2:
			animation_player.play("a-landing")
			speed = 0
		else:
			_reverse_landing()
	
	# Hanlde camera_rotation
	if punch_mode and (camera_mount.rotation.x != 0 or camera_mount.rotation.y != 0): 
		camera_mount.rotation.x = move_toward(camera_mount.rotation.x, 0, delta * 3)
		camera_mount.rotation.y = move_toward(camera_mount.rotation.y, 0, delta * 3)
	
	# Handle movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0:
		# Smoothly rotate the character to face the movement direction
		var target_rotation = direction
		var current_forward = -transform.basis.z.normalized()
		var rotation_axis = current_forward.cross(target_rotation).normalized()
		
		if rotation_axis != Vector3.ZERO:  # Avoid rotation when directions are parallel
			var target_basis = Basis(rotation_axis, current_forward.angle_to(target_rotation)) * transform.basis
			transform.basis = transform.basis.slerp(target_basis, sens_rotation * delta)
		
		var is_walking_backwards = current_forward.dot(direction) < 0
		
		# If player is pressing just left or right use turning anims
		if !Input.is_action_pressed("forward") and \
		!Input.is_action_pressed("backward") and \
		_check_turnable():
			animation_player.speed_scale = 1.5
			speed = 0.5
			if Input.is_action_pressed("left"):
				animation_player.play("a-left-turn")
			elif Input.is_action_pressed("right"):
				animation_player.play("a-right-turn")
		
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
				speed = 2
		elif _check_backwards_walkable() and is_walking_backwards:
			sens_rotation = 1.5
			can_regenerate_stamina = true
			if animation_player.current_animation == "a-run":
				animation_player.play_backwards("a-walk-backwards-to-run")
				reverse_anim_bool = true
			elif animation_player.current_animation == "a-walk":
				animation_player.play("a-walk-to-walk-backwards")
			else:
				animation_player.play("a-idle-to-walk-backwards")
				speed = 1
		elif _check_runable() && Input.is_action_pressed("sprint") and !is_walking_backwards:
			sens_rotation = 3.0
			can_regenerate_stamina = false
			if animation_player.current_animation == "a-walk":
				animation_player.play("a-walk-to-run")
			elif animation_player.current_animation == "a-walk_backwards":
				animation_player.play("a-walk-backwards-to-run")
			else:
				animation_player.play("a-idle-to-run")
				speed = 4
		
		if punch_mode and !is_punching and \
		animation_player.current_animation == "a-idle-fight_":
			sens_rotation = 0
			animation_player.play("a-idle-fight-to-fight-walk")
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		can_regenerate_stamina = true
		if animation_player.current_animation == "a-left-turn" \
		or animation_player.current_animation == "a-right-turn":
			_turn_to_idle()
		elif animation_player.current_animation != "a-idle" and !punch_mode:
			_reverse_animation_to_idle()
		elif punch_mode:
			_reverse_animation_to_fight_idle()
		
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	move_and_slide()

# Combat system functions
func _punch_attack() -> void:
	targeted_enemy = raycast3D.return_enemy()
	if targeted_enemy == null:
		speed = 1
		animation_player.speed_scale = 1
		spend_stamina(10)
		punch_to_idle = true
		animation_player.play("a-left-punch") #some default animation
		print("While punching an enemy wasnt detected!")
	else:
		var direction = _get_direction_to_Node(targeted_enemy)
		
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

func _randomizer(numElements) -> int:
	return randi() % numElements + 1
func _get_direction_to_Node(targetNode : Node) -> Vector3:
	if targetNode == null:
		return global_position
	else:
		var direction = (targetNode.global_position - global_position).normalized()
		direction.y = 0  # Keep Y-axis unchanged
		return direction
func _launch_backwards(direction) -> void:
		direction = -direction.normalized()  # Reverse direction
		var backward_position = global_position + (direction * 0.3) # 0.4 is the backwards distance
		backward_position.y = global_position.y  # Keep Y unchanged
		
		# Move backwards smoothly
		var tween = create_tween()
		tween.tween_property(self, "global_position", backward_position, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) #0.7 is the move time
func _launch_forward(direction, target) -> void:
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

# Item collection
func show_item_text():
	rich_text_label.visible = true
func hide_item_text():
	rich_text_label.visible = false

# Stamina system functions
func spend_stamina(amount):
	if stamina < amount:
		stamina = 0
	else:
		stamina -= amount
	staminaChanged.emit()
func regenerate_stamina(delta):
	if stamina < 100:
		stamina += 1.7 * delta
		stamina = min(stamina, 100)
		staminaChanged.emit()
# Health system functions
func heal(amount):
	if amount + health > 100:
		health = 100
	else:
		health += amount 
	healthChanged.emit()
func hurt(hit_points):
	if hit_points < health:
		health -= hit_points
	else:
		health = 0
	if health == 0:
		die()
	healthChanged.emit()
func die():
	pass

# Animation transition functions
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "a-idle-to-walk":
		if !reverse_anim_bool:
			animation_player.play("a-walk")
		else:
			speed = 2
			animation_player.play("a-idle")
			reverse_anim_bool = false
	elif anim_name == "a-left-turn" or anim_name == "a-right-turn":
		animation_player.speed_scale = 1
		animation_player.play("a-idle")
	elif anim_name == "a-idle-to-walk-backwards":
		if !reverse_anim_bool:
			animation_player.play("a-walk-backwards")
		else:
			animation_player.play("a-idle")
			speed = 2
			reverse_anim_bool = false
	elif anim_name == "a-idle-to-run":
		if !reverse_anim_bool:
			animation_player.play("a-run")
		else:
			speed = 4
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
			speed = 4
		else:
			animation_player.play("a-walk")
			speed = 2
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
		speed = 2
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
			speed = 1
		else:
			animation_player.play("a-idle")
			reverse_anim_bool = false
			speed = 2
	elif anim_name == "a-idle-fight-to-fight-walk":
		if !reverse_anim_bool:
			animation_player.play("a-fight-walk")
		else:
			animation_player.play("a-idle-fight_")
			reverse_anim_bool = false
	elif anim_name == "a-left-turn" or anim_name == "a-right-turn":
		animation_player.play("a-idle")
		speed = 2
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
					print("a-left-jab-into-elbow in _on_animation_end: combat animation number is incorrect")
			elif anim_name == "a-left-kick":
				if combat_animation_number == 4:
					animation_player.play("a-c4-3")
				elif combat_animation_number == 7:
					animation_player.play("a-c7-2")
				else:
					print("a-left-kick in _on_animation_end: combat animation number is incorrect")
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
					print("a-right-punch in _on_animation_end: combat animation number is incorrect")
			elif anim_name == "a-right-elbow":
				if combat_animation_number == 1:
					animation_player.play("a-c1-2")
				elif combat_animation_number == 6:
					animation_player.play("a-c6-2")
				else:
						print("a-right-elbow in _on_animation_end: combat animation number is incorrect")
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
					print("a-left-punch in _on_animation_end: combat animation number is incorrect")
		else:
			is_punching = false
			animation_player.speed_scale = 1
			
			if !punch_to_idle:
				_launch_backwards(global_position)
			
			punch_to_idle = false
			animation_player.play("a-idle-fight_")
			speed = 1
	else:
		print("finished animation:", anim_name)
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
		speed = 2
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
func _turn_to_idle() -> void:
	speed = 1
	if animation_player.current_animation_position < animation_player.current_animation_length / 2:
		animation_player.speed_scale = -1.5 # when animation is past the half way
	
func _reverse_landing() -> void:
	animation_player.speed_scale = 1.8
	animation_player.play_backwards("a-idle-to-fall")
	reverse_anim_bool = true
func _transition_to_weapon() -> void:
	#Transition back to idle mode
	match previous_weapon:
		"run":
			speed = 0
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
		_:
			speed = 0
			#print("1none")
	
	# Transition from idle to other modes
	match selected_weapon:
		"run":
			speed = 1
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
		_:
			speed = 1
			print("2none")
	
	is_selecting_mode = false
	if selected_weapon != "":
		previous_weapon = selected_weapon

# From idle animatios
func _punch_mode_transition() -> void:
	if !_check_mode_changable():
		is_selecting_mode = false
		is_punching = false
		speed = 1
		return
	#stop movement until switch is over
	punch_mode = true
	_reverse_animation_to_idle()
	speed = 0
	while animation_player.current_animation != "a-idle":
		await get_tree().process_frame
	animation_player.play("a-idle-to-fight")
	cross_hair.texture = CROSSHAIR
	cross_hair.size = Vector2(60,60)
	cross_hair.position.x -= 10
	cross_hair.position.y -= 10
	is_selecting_mode = false
func _dynamite_transition() -> void:
	pass
func _pistol_transition() -> void:
	pass
func _rifle_transition() -> void:
	pass

# To idle animations
func _punch_mode_to_idle() -> void:
	# reset the crosshair to normal
	cross_hair.texture = EMPTY_CIRCLE
	cross_hair.size = Vector2(40,40)
	cross_hair.position.x += 10
	cross_hair.position.y += 10
	
	animation_player.play("a-idle-fight_")
	
	reverse_anim_bool = true
	animation_player.play_backwards("a-idle-to-fight")
	
	while animation_player.current_animation != "a-idle":
		await get_tree().process_frame
	
	is_selecting_mode = false
	punch_mode = false
	is_punching = false
func _dynamite_to_idle() -> void:
	pass
func _pistol_to_idle() -> void:
	pass
func _rifle_to_idle() -> void:
	pass

# Boolean functions
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
	animation_player.current_animation != "a-walk-backwards-to-run" and \
	animation_player.current_animation != "":
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
	is_on_floor() and !punch_mode:
		return true
	else: return false
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
	   !punch_mode:
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
	   !punch_mode:
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
	   !punch_mode:
		return true
	else:
		return false
