extends RigidBody3D

@export var damage: int = 10
var speed: float = 30.0
var direction: Vector3 = Vector3.ZERO
@export var life_time : float = 3.0
@export var inaccuracy_degrees: float = 4.0 # how much the bullet can miss

func _ready():
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(_delta):
	# move in space
	if direction and direction != Vector3.ZERO:
		direction = direction.normalized()
		linear_velocity = direction * speed
	else:
		# Stop movement if no direction is given
		linear_velocity = Vector3.ZERO

func set_direction(dir: Vector3):
	 # add random bullet spread
	direction = dir.normalized()
	direction = direction.rotated(
		Vector3.UP,
		deg_to_rad(randf_range(-inaccuracy_degrees, inaccuracy_degrees))
	).rotated(
		Vector3.RIGHT,
		deg_to_rad(randf_range(-inaccuracy_degrees, inaccuracy_degrees))
	).normalized()
func set_damage(amount: int):
	damage = amount

func _on_area_3d_body_entered(body: Node3D) -> void:
	#TODO add bullet imprint
	if body == self or body.get_parent() == self:
		return
	if body.is_in_group("player") or body.get_parent().is_in_group("player"):
		body.hurt(damage)
	queue_free()
