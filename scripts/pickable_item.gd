extends Node3D

@onready var area_3d: Area3D = $Area3D

var rotation_speed: float = 90.0  # degrees per second
var text_shown: bool = false

func _process(delta):
	# Rotate the node around the Y-axis (or another axis)
	rotation_degrees.y += rotation_speed * delta
	
	if text_shown and Input.is_action_just_pressed("use"):
		# Add item to the players inventory
		if name == "Dynamite":
			Global.has_dynamite_unlocked = true
		elif name == "Rifle":
			Global.has_rifle_unlocked = true
		queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.show_item_text()
		text_shown = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.hide_item_text()
		text_shown = false
