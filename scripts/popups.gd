extends CanvasLayer

@onready var info_label: Label = $InfoLabel
@onready var portal_label: Label = $PortalLabel
@onready var player = $"../Player"
@onready var camera = player.get_viewport().get_camera_3d()
var players_raycast: RayCast3D

func _ready() -> void:
	players_raycast = player.get_child(2).get_child(1)
	players_raycast.show_info.connect(_on_show_info)
	players_raycast.hide_info.connect(_on_hide_info)
	info_label.visible = false
	portal_label.visible = false

func _on_show_info(world_pos: Vector3) -> void:
	var screen_pos = camera.unproject_position(world_pos)
	if is_instance_valid(info_label):
		info_label.visible = true
		info_label.position = screen_pos + Vector2(0, -50)
	elif is_instance_valid(portal_label) and !Global.has_unlocked_level_3:
		portal_label.visible = true
		portal_label.position = screen_pos + Vector2(0, -50)

func _on_hide_info() -> void:
	if is_instance_valid(info_label):
		info_label.visible = false
	elif is_instance_valid(portal_label):
		portal_label.visible = false
