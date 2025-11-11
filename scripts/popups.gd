extends CanvasLayer

@onready var info_label: Label = $InfoLabel
@onready var player = $"../Player"
@onready var camera = player.get_viewport().get_camera_3d()
var players_raycast: RayCast3D

func _ready() -> void:
	players_raycast = player.get_child(2).get_child(1)
	players_raycast.show_info.connect(_on_show_info)
	players_raycast.hide_info.connect(_on_hide_info)
	info_label.visible = false

func _on_show_info(text: String, world_pos: Vector3) -> void:
	info_label.text = text
	info_label.visible = true
	var screen_pos = camera.unproject_position(world_pos)
	info_label.position = screen_pos + Vector2(0, -50)

func _on_hide_info() -> void:
	info_label.visible = false
