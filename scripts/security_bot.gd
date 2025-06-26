extends CharacterBody3D

enum States {
	Walking,
	Pursuit
}

@export var walkSpeed : float = 1.0
@export var runSpeed : float = 2.0

@onready var follow_target_3d: FollowTarget3D = $FollowTarget3D
@onready var random_target_3d: RandomTarget3D = $RandomTarget3D

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/security_bot/Armature/Skeleton3D/Plane_003
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@export var radius: float = 0.35  # Distance from the center of the StaticBody3D
@export var offset: Vector3 = Vector3(0, 1, 0)  # Optional offset from the StaticBody3D's position

var target_visible = false
var health = 100 
var time = 0.0

var state : States = States.Walking
var target : Node3D

func _ready() -> void:	
	ChangeState(States.Walking)
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

func _process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
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

func hurt(hit_points: int) -> void:
	if hit_points < health:
		health -= hit_points
		progress_bar.value = health
	else:
		health = 0
		progress_bar.value = health
func _return_health() -> int:
	return health

func ChangeState(newState : States) -> void:
	state = newState
	match state:
		States.Walking:
			follow_target_3d.ClearTarget()
			follow_target_3d.Speed = walkSpeed
			follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())
			target = null
		States.Pursuit:
			follow_target_3d.Speed = runSpeed
			follow_target_3d.SetTarget(target)

func _on_follow_target_3d_navigation_finished() -> void:
	follow_target_3d.SetFixedTarget(random_target_3d.GetNextPoint())

func _on_simple_vision_3d_get_sight(body: Node3D) -> void:
	target = body
	ChangeState(States.Pursuit)

func _on_simple_vision_3d_lost_sight() -> void:
	ChangeState(States.Walking)
