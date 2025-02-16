extends Control

@onready var map: TextureRect = $Map
var tween : Tween

@onready var _center_x = get_viewport().get_visible_rect().size.x / 2
@onready var _center_y = get_viewport().get_visible_rect().size.y / 2
var target_cords : Vector2
var _is_not_centered = false

func _input(event):
	# Mouse in viewport coordinates.
	if event is InputEventMouseMotion:
		_set_target_cords(event)
		tween = create_tween()
		tween.tween_property(map, "position", target_cords, 2)

func _set_target_cords(event) -> void:
	_is_not_centered = false
	if event.position.y > 3 * _center_y / 2:
		_is_not_centered = true
		target_cords.y = -200
	elif event.position.y < _center_y / 2:
		_is_not_centered = true
		target_cords.y = 0
	if event.position.x > 3 * _center_x / 2:
		_is_not_centered = true
		target_cords.x = -405
	elif event.position.x < _center_x / 2:
		_is_not_centered = true
		target_cords.x = 0
	
	if !_is_not_centered:
		target_cords = Vector2(-251, -98)
