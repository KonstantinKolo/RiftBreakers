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
		elif name == "Button1":
			var enemy_spawner: Node3D = $"../../../Portals/EnemySpawner"
			enemy_spawner.enemy_type = preload("res://scenes/security_bot.tscn")
			enemy_spawner.spawn_enemy()
			return
		elif name == "Button2":
			var enemy_spawner: Node3D = $"../../../Portals/EnemySpawner"
			enemy_spawner.enemy_type = preload("res://scenes/ranged_bot.tscn")
			enemy_spawner.spawn_enemy()
			return
		elif name == "Button3":
			var security_bot_boss: CharacterBody3D = $"../../../SecurityBotBoss"
			security_bot_boss.position = Vector3(15, 0.5, 0)
			return
		elif name == "Button4":
			var ranged_bot_boss: CharacterBody3D = $"../../../RangedBotBoss"
			ranged_bot_boss.position = Vector3(15, 0.5, 0)
		queue_free()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.show_item_text()
		text_shown = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.hide_item_text()
		text_shown = false
