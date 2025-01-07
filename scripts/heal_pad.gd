extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_hit_player_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("player", "heal", 10)
