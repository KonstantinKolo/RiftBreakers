extends CharacterBody3D

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var target_sprite: Sprite3D = $Sprite3D2
@onready var model_3d: MeshInstance3D = $visuals/security_bot/Armature/Skeleton3D/Plane_003
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@export var radius: float = 0.35  # Distance from the center of the StaticBody3D
@export var offset: Vector3 = Vector3(0, 1, 0)  # Optional offset from the StaticBody3D's position

var target_visible = false
var health = 100 
var time = 0.0

func _process(delta):
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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

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
