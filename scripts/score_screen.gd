extends Control

@onready var score_2: Label = $Score2
@onready var kills_melee_2: Label = $KillsMelee2
@onready var kills_ranged_2: Label = $KillsRanged2
@onready var kills_boss_2: Label = $KillsBoss2
@onready var total_time_2: Label = $TotalTime2

func _ready() -> void:
	kills_melee_2.text = str(Global.melee_bots_killed)
	kills_ranged_2.text = str(Global.ranged_bots_killed)
	kills_boss_2.text = str(Global.bosses_killed)
	total_time_2.text = str(Global.total_time) # in seconds
	score_2.text = str(_calculate_score())

func _calculate_score() -> int:
#   +10 points per melee kill
#   +15 points per ranged kill
#   +50 points for boss
#   -20 point per minute played
	var total_score = Global.melee_bots_killed * 10 \
					+ Global.ranged_bots_killed * 15 \
					+ Global.bosses_killed * 50 \
					- int(Global.total_time / 60) * 20
	return total_score

func _on_return_to_menu_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://Maps/intro_scene.tscn")

func _on_close_game_btn_pressed() -> void:
	get_tree().quit()
