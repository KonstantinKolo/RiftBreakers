extends Control

@onready var score_2: Label = $Score2
@onready var kills_melee_2: Label = $KillsMelee2
@onready var kills_ranged_2: Label = $KillsRanged2
@onready var kills_boss_2: Label = $KillsBoss2
@onready var total_time_2: Label = $TotalTime2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	kills_melee_2.text = str(Global.melee_bots_killed)
	kills_ranged_2.text = str(Global.ranged_bots_killed)
	kills_boss_2.text = str(Global.bosses_killed)
	total_time_2.text = str(Global.total_time) # in seconds
	score_2.text = str(Global.calculate_score())

func _on_return_to_menu_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://Maps/menu.tscn")

func _on_close_game_btn_pressed() -> void:
	get_tree().quit()
