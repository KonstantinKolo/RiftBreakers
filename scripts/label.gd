extends Label

func _ready() -> void:
	Global.scoreChanged.connect(_update_text)
	await get_tree().create_timer(0.2).timeout
	text = "Current Score: " + str(Global.calculate_score())

func _update_text() -> void:
	text = "Current Score: " + str(Global.calculate_score())
