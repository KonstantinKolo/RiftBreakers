extends CharacterBody3D

signal healthChanged
signal staminaChanged
signal blinkStaminaBar

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/FinishedMC/AnimationPlayer
@onready var cross_hair: TextureRect = $camera_mount/Camera3D/CrossHair
@onready var stamina_bar: TextureProgressBar = $camera_mount/Camera3D/StaminaBar
const EMPTY_CIRCLE = preload("res://assets/models/Icons/empty-circle.png")
const CROSSHAIR = preload("res://assets/models/Icons/crosshair.svg")

var speed = 2
const JUMP_VELOCITY = 4.5

@export var health = 100
@export var stamina = 20
@export var ray_length = 100.0

var reverse_anim_bool = false
var is_jumping = false
var jump_concluded = false
var start_counting_air_time = false
var punch_mode = false
var is_punching = false
var is_selecting_mode = false
var can_regenerate_stamina = true
@export var critical_stamina = false

var combat_animation_number = 0
var air_time = 0.0

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

func _ready():
	#enemy_detected = $camera_mount/RayCast3D.enemy_detected
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_player.animation_finished.connect(self._on_animation_player_animation_finished)
	await get_tree().create_timer(0.1).timeout
	animation_player.play("a-idle")


func _input(event):
	if event is InputEventMouseMotion and \
	   Input.is_action_pressed("right_mouse") and \
	   !punch_mode:
		# TODO reseting the z axis is kinda jittery
		camera_mount.rotation.z = 0
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
		camera_mount.rotate_x(deg_to_rad((-event.relative.y*sens_vertical)))
	elif event is InputEventMouseMotion and !punch_mode:
		camera_mount.rotate_y(deg_to_rad(-event.relative.x * sens_horizontal))
		
		# Clamp the vertical rotation to avoid flipping
		var new_rotation_x = camera_mount.rotation.x + deg_to_rad(-event.relative.y * sens_vertical)
		new_rotation_x = clamp(new_rotation_x, deg_to_rad(-90), deg_to_rad(90))
		camera_mount.rotation.x = new_rotation_x
	# Combat mouse mode
	elif event is InputEventMouseMotion and punch_mode:
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if can_regenerate_stamina: regenerate_stamina(delta)
	elif !can_regenerate_stamina && animation_player.current_animation == "a-run":
		spend_stamina(delta * 5)
	
	#TODO add transition from punch_mode to falling
	# Handle falling without jumping
	if not is_on_floor() and !punch_mode and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   animation_player.current_animation != "":
		start_counting_air_time = true
		animation_player.speed_scale = 1.8
		animation_player.play("a-idle-to-fall")
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
	
	# Handle attack functionality
	if Input.is_action_just_pressed("attack") and !is_selecting_mode and \
		stamina >= 10 and !critical_stamina:
		print("pressed attack")
		if !punch_mode:
			is_selecting_mode = true
			is_punching = true
			speed = 0
			_punch_mode_transition()
			
			# wait until the animations are over
			while animation_player.current_animation != "a-idle-fight":
					await get_tree().process_frame
			
			_punch_attack()
		elif punch_mode:
			# Check which mode we have selected when we have multiple modes
			is_punching = true
			speed = 0
			_punch_attack()
   
	# Handle the weapon selection
	if Input.is_action_just_pressed("mode_selection") and !is_selecting_mode:
		is_selecting_mode = true
		
		# Done as if we already selected punch mode
		#Transition back to idle mode
		if(punch_mode): 
			speed = 0
			_punch_mode_to_idle()
			return
		
		_punch_mode_transition()
	
	# Hanlde camera_rotation
	if punch_mode and (camera_mount.rotation.x != 0 or camera_mount.rotation.y != 0): 
		camera_mount.rotation.x = move_toward(camera_mount.rotation.x, 0, delta * 3)
		camera_mount.rotation.y = move_toward(camera_mount.rotation.y, 0, delta * 3)
	
	# Handle movement
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if _check_walkable() && (!Input.is_action_pressed("sprint") or critical_stamina):
			can_regenerate_stamina = true
			if animation_player.current_animation == "a-run":
				animation_player.play_backwards("a-walk-to-run")
				reverse_anim_bool = true
			else:
				animation_player.play("a-idle-to-walk")
				speed = 2
		elif _check_runable() && Input.is_action_pressed("sprint"):
			can_regenerate_stamina = false
			if animation_player.current_animation == "a-walk":
				animation_player.play("a-walk-to-run")
			else:
				animation_player.play("a-idle-to-run")
				speed = 4
		
		if punch_mode and !is_punching and \
		   animation_player.current_animation == "a-idle-fight":
			animation_player.play("a-idle-fight-to-fight-walk")
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		can_regenerate_stamina = true
		if animation_player.current_animation != "a-idle" and !punch_mode:
			_reverse_animation_to_idle()
		elif punch_mode and !_check_punching():
			_reverse_animation_to_fight_idle()
		
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

# Combat system functions
func _punch_attack() -> void:
	if !$camera_mount/RayCast3D.enemy_detected:
		speed = 1
		animation_player.speed_scale = 1
		animation_player.play("a-left-punch") #some default animation
		print("While punching an enemy wasnt detected!")
	else:
		#play the combos
		# TODO add player launching towards enemy
		var combo_type = _randomizer(7)
		print(combo_type)
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
		
func _enemy_detected_func():
	print("enemy has been detected in player")
func _randomizer(numElements) -> int:
	return randi() % numElements + 1


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
func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "a-left-punch" or anim_name == "a-right-punch":
		can_regenerate_stamina = false
		spend_stamina(10)
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "a-idle-to-walk":
		if !reverse_anim_bool:
			animation_player.play("a-walk")
		else:
			animation_player.play("a-idle")
			reverse_anim_bool = false
	elif anim_name == "a-idle-to-run":
		if !reverse_anim_bool:
			animation_player.play("a-run")
		else:
			animation_player.play("a-idle")
			reverse_anim_bool = false
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
			animation_player.play("a-fall")
			animation_player.speed_scale = 1
		else:
			animation_player.speed_scale = 1.0
			air_time = 0
			reverse_anim_bool = false
	elif anim_name == "a-idle-to-fight":
		if !reverse_anim_bool:
			animation_player.play("a-idle-fight")
			speed = 1
		else:
			animation_player.play("a-idle")
			reverse_anim_bool = false
			speed = 2
	elif anim_name == "a-idle-fight-to-fight-walk":
		if !reverse_anim_bool:
			animation_player.play("a-fight-walk")
		else:
			animation_player.play("a-idle-fight")
			reverse_anim_bool = false
	#elif anim_name == "a-left-punch":
		## TODO delete this
		#
		##animation_player.play_backwards("a-idle-fight-to-left_punch")
		#animation_player.play("a-idle-fight")
		#is_punching = false
		#can_regenerate_stamina = true
		#speed = 1
	#elif anim_name == "a-right-punch":
		## TODO delete this
		#
		##animation_player.play_backwards("a-idle-fight-to-right_punch")
		#animation_player.play("a-idle-fight")
		#is_punching = false
		#can_regenerate_stamina = true
		#speed = 1
	#elif (anim_name == "a-idle-fight-to-right-punch" or anim_name == "a-idle-fight-to-left-punch") and reverse_anim_bool:
		#animation_player.play("a-idle-fight")
		#reverse_anim_bool = false
	elif punch_mode:
		if anim_name == "a-c1_c4-0":
			combat_animation_number = 1
			animation_player.play("a-left-punch")
		elif anim_name == "a-c2-0":
			combat_animation_number = 2
			animation_player.play("a-right-punch")
		elif anim_name == "a-c3-0":
			combat_animation_number = 3
			animation_player.play("a-right-high-kick")
		elif anim_name == "a-c5-0":
			combat_animation_number = 5
			animation_player.play("a-left-jab-into-elbow")
		elif anim_name == "a-c6-0":
			combat_animation_number = 6
			animation_player.play("a-left-mma-kick")
		elif anim_name == "a-c7-0":
			combat_animation_number = 7
			animation_player.play("a-right-deep-uppercut")
		elif anim_name == "a-c1-1":
			animation_player.play("a-right-elbow")
		elif anim_name == "a-c2-1":
			animation_player.play("a-left-jab-into-elbow")
		elif anim_name == "a-c3-1":
			animation_player.play("a-left-punch")
		elif anim_name == "a-c4-1":
			animation_player.play("a-right-punch")
		elif anim_name == "a-c5-1":
			animation_player.play("a-right-knee")
		elif anim_name == "a-c6-1":
			animation_player.play("a-right-elbow")
		elif anim_name == "a-c7-1":
			animation_player.play("a-left-kick")
		elif anim_name == "a-c1-2":
			animation_player.play("a-left-jab")
		elif anim_name == "a-c3-2":
			animation_player.play("a-right-punch")
		elif anim_name == "a-c4-2":
			animation_player.play("a-left-kick")
		elif anim_name == "a-c6-2":
			animation_player.play("a-left-punch")
		elif anim_name == "a-c7-2":
			animation_player.play("a-right-punch")
		elif Input.is_action_pressed("attack"):
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
			#TODO after return to idle add some code
			#TODO return to idle when combo isnt continued
			if anim_name == "a-c1-3":
				pass
			elif anim_name == "a-c2-3":
				pass
			elif anim_name == "a-c3-2":
				pass
			elif anim_name == "a-c4-3":
				pass
			elif anim_name == "a-c5-2":
				pass
			elif anim_name == "a-c6-3":
				pass
			elif anim_name == "a-c7-3":
				pass
			else:
				#TODO other animations return to idle
				pass
	else:
		print("finished animation:", anim_name)

# More animtion transition functions
func _reverse_animation_to_idle() -> void:
	if animation_player.current_animation == "a-walk":
		animation_player.play_backwards("a-idle-to-walk")
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
func _reverse_landing() -> void:
	animation_player.speed_scale = 1.8
	animation_player.play_backwards("a-idle-to-fall")
	reverse_anim_bool = true
func _punch_mode_transition() -> void:
	if !_check_mode_changable():
		is_selecting_mode = false
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
func _punch_mode_to_idle() -> void:
	# reset the crosshair to normal
	cross_hair.texture = EMPTY_CIRCLE
	cross_hair.size = Vector2(40,40)
	cross_hair.position.x += 10
	cross_hair.position.y += 10
	
	_punching_to_fight_idle()
	
	reverse_anim_bool = true
	animation_player.play_backwards("a-idle-to-fight")
	
	while animation_player.current_animation != "a-idle":
		await get_tree().process_frame
	
	is_selecting_mode = false
	punch_mode = false
func _punching_to_fight_idle() -> void:
	# TODO fix this method to work with all anims
	if _check_punching():
		pass
		#while animation_player.current_animation != "a-idle-fight-to-left-punch" and \
		#animation_player.current_animation != "a-idle-fight-to-right-punch":
			#await get_tree().process_frame
		#
		#if has_left_punched:
			#animation_player.play_backwards("a-idle-fight-to-right-punch")
			#reverse_anim_bool = true
		#else:
			#animation_player.play_backwards("a-idle-fight-to-left-punch")
			#reverse_anim_bool = true
		

# Boolean functions
func _check_punching() -> bool:
	if animation_player.current_animation != "a-idle-fight-to-left-punch" and \
	   animation_player.current_animation != "a-left-punch" and \
	   animation_player.current_animation != "a-idle-fight-to-right-punch" and \
	   animation_player.current_animation != "a-right-punch":
		return false
	else: return true
func _check_mode_changable() -> bool:
	if is_on_floor() and health > 0 and !punch_mode and \
	animation_player.current_animation != "a-jump" and \
	animation_player.current_animation != "a-landing" and \
	animation_player.current_animation != "a-fall" and \
	animation_player.current_animation != "a-idle-to-fall" and \
	animation_player.current_animation != "a-falling" and \
	animation_player.current_animation != "a-idle-to-walk" and \
	animation_player.current_animation != "a-idle-to-run" and \
	animation_player.current_animation != "a-walk-to-run" and \
	animation_player.current_animation != "":
		return true
	else: return false
func _check_walkable() -> bool:
	if animation_player.current_animation != "a-walk" and \
	   animation_player.current_animation != "a-idle-to-walk" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
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
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-idle-to-fall" and \
	   !punch_mode:
		return true
	else:
		return false
