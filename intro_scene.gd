extends Node3D

@export var scroll_speed: float = 40.0

@onready var animation_player: AnimationPlayer = $SmoothMC/AnimationPlayer
@onready var scene_animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect_2: ColorRect = $CanvasLayer/ColorRect2
@onready var story: RichTextLabel = $CanvasLayer/Story

var scroll_stop: bool = false

func _ready() -> void:
	color_rect_2.visible = false
	animation_player.play("a-idle")
	scene_animation_player.play("initial_load")

func _process(delta):
	if !scroll_stop:
		story.position.y -= scroll_speed * delta

func _on_button_pressed() -> void:
	color_rect_2.visible = false
	story.visible = false
	scene_animation_player.play("fade_to_black")
	scene_animation_player.animation_finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)
func _on_button_2_pressed() -> void:
	color_rect_2.visible = !color_rect_2.visible
	story.visible = !story.visible
	scroll_stop = !scroll_stop

func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
	
func _on_fade_finished(anim_name: StringName) -> void:
	if anim_name == "fade_to_black":
		get_tree().change_scene_to_file("res://Maps/menu.tscn")
