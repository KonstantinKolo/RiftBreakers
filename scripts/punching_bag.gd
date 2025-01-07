extends StaticBody3D

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
@onready var player_camera: Camera3D = $camera_mount/Camera3D

var health = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.visible = false
	progress_bar.value = health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
