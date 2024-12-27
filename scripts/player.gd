extends CharacterBody3D

@onready var camera_mount: Node3D = $camera_mount
@onready var animation_player: AnimationPlayer = $visuals/MainCharacter/AnimationPlayer

var speed = 2
const JUMP_VELOCITY = 4.5

var reverseAnimBool = false;

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

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		if animation_player.current_animation != "a-walk" && animation_player.current_animation != "a-idle-to-walk" && animation_player.current_animation != "a-walk-to-run" && !Input.is_action_pressed("sprint"):
			if animation_player.current_animation == "a-run":
				animation_player.play_backwards("a-walk-to-run")
				reverseAnimBool = true
			else:
				animation_player.play("a-idle-to-walk")
				speed = 2
		elif animation_player.current_animation != "a-run" && animation_player.current_animation != "a-idle-to-run" && animation_player.current_animation != "a-walk-to-run" && Input.is_action_pressed("sprint"):
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
	if anim_name == "a-idle-to-walk" && !reverseAnimBool:
		animation_player.play("a-walk")
	elif anim_name == "a-idle-to-walk" && reverseAnimBool:
		animation_player.play("a-idle")
		reverseAnimBool = false
	elif anim_name == "a-idle-to-run" && !reverseAnimBool:
		animation_player.play("a-run")
	elif anim_name == "a-idle-to-run" && reverseAnimBool:
		animation_player.play("a-idle")
		reverseAnimBool = false
	elif anim_name == "a-walk-to-run" && reverseAnimBool:
		animation_player.play("a-walk")
		speed = 2
		reverseAnimBool = false;
	elif anim_name == "a-walk-to-run" && !reverseAnimBool:
		animation_player.play("a-run")
		speed = 4
	else:
		print("finished animation:", anim_name)

func _reverse_animation_to_idle() -> void:
	pass
	if animation_player.current_animation == "a-walk":
		animation_player.play_backwards("a-idle-to-walk")
		reverseAnimBool = true
	elif animation_player.current_animation == "a-run":
		animation_player.play_backwards("a-idle-to-run")
		reverseAnimBool = true
		speed = 2
