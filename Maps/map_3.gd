extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var texture_rect: TextureRect = $CanvasLayer/MarginContainer/HBoxContainer/TextureRect
@onready var progress_bar: ProgressBar = $CanvasLayer/MarginContainer/HBoxContainer/ProgressBar
@onready var spider_bot: Node3D = $SpiderBot
@onready var teleport_portal: Node3D = $Portals/TeleportPortal

var health_bar_fading_out: bool = false

func _ready() -> void:
	Global.triggeredMap.emit()
	spider_bot.inHealthBarRange.connect(_show_boss_health_bar)
	spider_bot.outHealthBarRange.connect(_hide_boss_health_bar)
	spider_bot.healthChanged.connect(_change_health_value)
	player.load_screen_disappear()
	progress_bar.value = spider_bot.health
	teleport_portal.deactivate()

func _show_boss_health_bar() -> void:
	if health_bar_fading_out: return
	texture_rect.visible = true
	progress_bar.visible = true
func _hide_boss_health_bar() -> void:
	if health_bar_fading_out: return
	texture_rect.visible = false
	progress_bar.visible = false
	
func _change_health_value() -> void:
	progress_bar.value = spider_bot.health
	if progress_bar.value <= 0 and !health_bar_fading_out:
		_fade_out_health_bar()
func _fade_out_health_bar() -> void:
	health_bar_fading_out = true
	var tween := get_tree().create_tween()
	tween.set_parallel()  # run animations together

	# fade health bar
	tween.tween_property(texture_rect, "modulate:a", 0.0, 0.5)
	tween.tween_property(progress_bar, "modulate:a", 0.0, 0.5)

	await tween.finished
	texture_rect.queue_free()
	progress_bar.queue_free()
