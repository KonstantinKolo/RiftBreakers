extends StaticBody3D

func _on_hit_player_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("player", "hurt", 50)
