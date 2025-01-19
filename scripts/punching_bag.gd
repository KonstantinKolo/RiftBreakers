extends StaticBody3D

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var csg_mesh_3d: CSGMesh3D = $CSGMesh3D
@onready var players_camera = get_node("/root/Node3D/Player/camera_mount/Camera3D")
@onready var target_sprite: Sprite3D = $Sprite3D2

@export var radius: float = 0.35  # Distance from the center of the StaticBody3D
@export var offset: Vector3 = Vector3(0, 1, 0)  # Optional offset from the StaticBody3D's position

var target_visible = false
var health = 100
var time = 0.0

func _process(delta):
	time += delta
	if csg_mesh_3d.material_overlay and csg_mesh_3d.material_overlay.next_pass and csg_mesh_3d.material_overlay.next_pass is ShaderMaterial:
		csg_mesh_3d.material_overlay.next_pass.set("shader_parameter/time", time)
	# TODO make it if the player is close the target dissappears
	if players_camera and target_visible:
		# Calculate the direction vector to the camera
		var camera_position = players_camera.global_transform.origin
		var bag_position = global_transform.origin
		var direction_to_camera = (camera_position - bag_position).normalized()
		# Place the sprite in front of the body (at the specified offset)
		var offset_position = bag_position + direction_to_camera * 0.4
		target_sprite.global_transform.origin = offset_position
		
		# Make the sprite face the camera
		target_sprite.look_at(camera_position, Vector3.UP)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_sprite.visible = false
	progress_bar.visible = false
	progress_bar.value = health

func show_target():
	if target_sprite:
		target_visible = true
		target_sprite.visible = true
func hide_target():
	if target_sprite:
		target_visible = false
		target_sprite.visible = false

# Method to show the health bar
func show_health_bar():
	if progress_bar:
		progress_bar.visible = true

# Method to hide the health bar
func hide_health_bar():
	if progress_bar:
		progress_bar.visible = false

func hurt(hit_points):
	if hit_points < health:
		health -= hit_points
	else:
		health = 0
	if health == 0:
		health = 100
