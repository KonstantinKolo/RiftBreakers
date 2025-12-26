extends ColorRect

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			TransitionScene.transition()
			await TransitionScene.on_transition_finished
			get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
