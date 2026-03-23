extends Control

@onready var score_2: Label = $Score2
@onready var kills_melee_2: Label = $KillsMelee2
@onready var kills_ranged_2: Label = $KillsRanged2
@onready var kills_boss_2: Label = $KillsBoss2
@onready var total_time_2: Label = $TotalTime2
@onready var item_list: ItemList = $ItemList
@onready var rich_text_label: RichTextLabel = $RichTextLabel

const SAVE_PATH: String = "user://save_data.json"

var current_page: int = 0
var limit: int = 10

func _exit_tree() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
	Global.reset_progress()

func _ready() -> void:
	Global.count_time = false
	MusicManager.play_music("res://assets/music/DavidKBD - The Last Pack - Guitar - 08 - loopeable.ogg")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	kills_melee_2.text = str(Global.melee_bots_killed)
	kills_ranged_2.text = str(Global.ranged_bots_killed)
	kills_boss_2.text = str(Global.bosses_killed)
	total_time_2.text = str(Global.total_time) # in seconds
	score_2.text = str(Global.calculate_score())
	_lang_setup()
	load_leaderboard(current_page)
	load_player_score()
	submit_score()

func submit_score() -> void:
	var score: int = Global.calculate_score()
	var http := HTTPRequest.new()
	http.request_completed.connect(_on_submit_score_completed)
	add_child(http)
	var url := "%sscore" % [Global.base_url]
	var headers = [
		"Authorization: Bearer %s" % Global.token,
		"Content-Type: application/json"
	]
	var body = JSON.stringify({
		"score": score
	})
	http.request(url, headers, HTTPClient.METHOD_POST, body)
func _on_submit_score_completed() -> void:
	load_leaderboard(current_page)

func load_leaderboard(page: int) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_leaderboard_response)
	
	var url := "%sleaderboard?page=%d&limit=%d" % [Global.base_url, page, limit]
	http.request(url)
func _on_leaderboard_response(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response_code != 200:
		return
	
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
	
	var response: Dictionary = json.data
	var entries: Array = response.get("data", [])
	
	item_list.clear()
	
	for entry in entries:
		var rank = entry.get("rank", 0)
		var name = entry.get("displayName", entry.get("username", "Unknown"))
		var score = entry.get("highscore", 0)
		var text := "#%d  %s  —  %d pts" % [rank, name, score]
		item_list.add_item(text)

func load_player_score() -> void:
	var http:= HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_load_player_response)
	
	var url := "%sinfo" % [Global.base_url]
	var headers := [
		"Authorization: Bearer %s" % Global.token,
        "Content-Type: application/json"
	]
	
	http.request(url, headers)
func _on_load_player_response(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response_code != 200:
		return
	
	var response_text := body.get_string_from_utf8()
	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		return
	var data: Dictionary = json.data
	
	var rank = data.get("rank")
	var name = data.get("displayName", data.get("username", "Unknow"))
	var score = data.get("highscore", 0)
	if rank == null: rank = "U"
	if score == null: score = 0
	
	
	var text :=  "#%s  %s  -  %d pts" % [rank,name,score]
	rich_text_label.text = text

func _on_return_to_menu_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Maps/menu.tscn")

func _on_close_game_btn_pressed() -> void:
	get_tree().quit()

func _lang_setup() -> void:
	if Global.selected_language == "en":
		for label in [$Score, $KillsMelee, $KillsRanged, $KillsBoss, $TotalTime]:
			if label.label_settings:
				var settings = label.label_settings.duplicate()
				settings.font_size = 56
				label.label_settings = settings
		$ReturnToMenuBtn.add_theme_font_size_override("font_size", 56)
		$CloseGameBtn.add_theme_font_size_override("font_size", 56)
		
		$Score.text = "Total score:"
		$KillsMelee.text = "Melee bots killed:"
		$KillsRanged.text = "Ranged bots killed:"
		$KillsBoss.text = "Bosses killed:"
		$TotalTime.text = "Total time:"
		$Label.text = "GLOBAL RANK"
		$ReturnToMenuBtn.text = "RETURN TO MENU"
		$CloseGameBtn.text = "CLOSE GAME"
	elif Global.selected_language == "bg":
		for label in [$Score, $KillsMelee, $KillsRanged, $KillsBoss, $TotalTime]:
			if label.label_settings:
				var settings = label.label_settings.duplicate()
				settings.font_size = 32
				label.label_settings = settings
		
		$ReturnToMenuBtn.add_theme_font_size_override("font_size", 32)
		$CloseGameBtn.add_theme_font_size_override("font_size", 32)
		
		$Score.text = "Общ резултат:"
		$KillsMelee.text = "Убити ботове в близък бой:"
		$KillsRanged.text = "Убити ботове от разстояние:"
		$KillsBoss.text = "Убити босове:"
		$TotalTime.text = "Общо време:"
		$Label.text = "ГЛОБАЛНА КЛАСАЦИЯ"
		$ReturnToMenuBtn.text = "ОБРАТНО КЪМ МЕНЮТО"
		$CloseGameBtn.text = "ЗАТВОРИ ИГРАТА"
