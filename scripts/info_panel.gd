extends PopupPanel

@onready var texture_rect: TextureRect = $MarginContainer/VBoxContainer/HBoxContainer2/TextureRect
@onready var map_name: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/MapName
@onready var initial_label: Label = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer/InitialLabel

@export var image : Texture2D
@export var text : String
@export var _map_name : String

func _ready() -> void:
	texture_rect.texture = image
	initial_label.text = text
	map_name.text = _map_name
	
	await get_tree().create_timer(0.2).timeout
	size.x = 420
	size.y = 168
