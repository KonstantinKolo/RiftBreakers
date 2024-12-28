extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/FinishedMC/AnimationPlayer

var speed = 2
const JUMP_VELOCITY = 4.5

var reverse_anim_bool = false
var is_jumping = false
var jump_concluded = false
var start_counting_air_time = false

var air_time = 0.0

@export var sens_horizontal = 0.5
@export var sens_vertical = 0.5

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	animation_player.animation_finished.connect(self._on_animation_player_animation_finished)


func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x*sens_horizontal))
		camera_mount.rotate_x(deg_to_rad((-event.relative.y*sens_vertical)))

func _physics_process(delta: float) -> void:
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle falling without jumping
	if not is_on_floor() and \
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
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-fall":
		animation_player.speed_scale = 1.8
		_reverse_animation_to_idle()
		
		# Wait until reverse_anim_bool is false
		while not !reverse_anim_bool:
			await get_tree().process_frame
		
		is_jumping = true;
		animation_player.play("a-jump")
		
		# Wait until is_jumping is false
		while not !is_jumping:
			await get_tree().process_frame
		
		velocity.y = JUMP_VELOCITY
		start_counting_air_time = true
		
		await get_tree().create_timer(0.5).timeout
		jump_concluded = true
	
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

	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if _check_walkable() && !Input.is_action_pressed("sprint"):
			if animation_player.current_animation == "a-run":
				animation_player.play_backwards("a-walk-to-run")
				reverse_anim_bool = true
			else:
				animation_player.play("a-idle-to-walk")
				speed = 2
		elif _check_runable() && Input.is_action_pressed("sprint"):
			if animation_player.current_animation == "a-walk":
				animation_player.play("a-walk-to-run")
			else:
				animation_player.play("a-idle-to-run")
				speed = 4
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		if animation_player.current_animation != "a-idle":
			_reverse_animation_to_idle()
			
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "a-idle-to-walk" && !reverse_anim_bool:
		animation_player.play("a-walk")
	elif anim_name == "a-idle-to-walk" && reverse_anim_bool:
		animation_player.play("a-idle")
		reverse_anim_bool = false
	elif anim_name == "a-idle-to-run" && !reverse_anim_bool:
		animation_player.play("a-run")
	elif anim_name == "a-idle-to-run" && reverse_anim_bool:
		animation_player.play("a-idle")
		reverse_anim_bool = false
	elif anim_name == "a-walk-to-run" && reverse_anim_bool:
		animation_player.play("a-walk")
		speed = 2
		reverse_anim_bool = false;
	elif anim_name == "a-walk-to-run" && !reverse_anim_bool:
		animation_player.play("a-run")
		speed = 4
	elif anim_name == "a-jump" && !reverse_anim_bool:
		is_jumping = false;
		animation_player.speed_scale = 1.0
		animation_player.play("a-fall")
	elif anim_name == "a-jump" && reverse_anim_bool:
		animation_player.speed_scale = 1.0
		air_time = 0
		reverse_anim_bool = false
		animation_player.play("a-idle")
	elif anim_name == "a-landing":
		speed = 2
		air_time = 0
		animation_player.play("a-idle")
	elif anim_name == "a-idle-to-fall" and !reverse_anim_bool:
		animation_player.play("a-fall")
		animation_player.speed_scale = 1
	elif anim_name == "a-idle-to-fall" and reverse_anim_bool:
		animation_player.speed_scale = 1.0
		air_time = 0
		reverse_anim_bool = false
	else:
		print("finished animation:", anim_name)

func _reverse_animation_to_idle() -> void:
	if animation_player.current_animation == "a-walk":
		animation_player.play_backwards("a-idle-to-walk")
		reverse_anim_bool = true
	elif animation_player.current_animation == "a-run":
		animation_player.play_backwards("a-idle-to-run")
		reverse_anim_bool = true
		speed = 2
func _reverse_landing() -> void:
	animation_player.speed_scale = 1.8
	animation_player.play_backwards("a-idle-to-fall")
	reverse_anim_bool = true

func _check_walkable() -> bool:
	if animation_player.current_animation != "a-walk" and \
	   animation_player.current_animation != "a-idle-to-walk" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-idle-to-fall":
		return true
	else:
		return false
func _check_runable() -> bool:
	if animation_player.current_animation != "a-run" and \
	   animation_player.current_animation != "a-idle-to-run" and \
	   animation_player.current_animation != "a-walk-to-run" and \
	   animation_player.current_animation != "a-jump" and \
	   animation_player.current_animation != "a-fall" and \
	   animation_player.current_animation != "a-landing" and \
	   animation_player.current_animation != "a-idle-to-fall":
		return true
	else:
		return false
