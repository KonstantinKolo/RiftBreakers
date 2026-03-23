extends Control

@onready var item_list: ItemList = $MarginContainer/VBoxContainer/ItemList
@onready var scoreLabel: Label = $ScoreColorRect/HBoxContainer/Score
@onready var placeLabel: Label = $PlaceColorRect/HBoxContainer/Place

var current_page: int = 1
var limit: int = 50

func _ready() -> void:
	_lang_setup()
	load_leaderboard(current_page)
	load_user_info()

func load_user_info() -> void:
	if Global.token == null || Global.token == "":
		return
	
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
	var score = data.get("highscore", 0)
	if rank == null: rank = "U"
	if score == null: score = 0
	
	scoreLabel.text = str(score)
	placeLabel.text = str(rank)


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

func _on_previous_page_button_pressed() -> void:
	if current_page > 1:
		current_page -= 1
		load_leaderboard(current_page)
func _on_next_page_button_pressed() -> void:
	current_page += 1
	load_leaderboard(current_page)

func _on_return_to_menu_btn_pressed() -> void:
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://scenes/Maps/menu.tscn")

func _lang_setup() -> void:
	if Global.selected_language == "en":
		$MarginContainer/VBoxContainer/HBoxContainer/PreviousPageButton.text = "PREVIOUS PAGE"
		$MarginContainer/VBoxContainer/HBoxContainer/NextPageButton.text = "NEXT PAGE"
		$ScoreColorRect/HBoxContainer/ScoreLabel.text = "Your High Score:"
		$PlaceColorRect/HBoxContainer/PlaceLabel.text = "Your Place:"
		$ReturnToMenuBtn.text = "RETURN TO MENU"
	elif Global.selected_language == "bg":
		$MarginContainer/VBoxContainer/HBoxContainer/PreviousPageButton.text = "ПРЕДИШНА СТРАНИЦА"
		$MarginContainer/VBoxContainer/HBoxContainer/NextPageButton.text = "СЛЕДВАЩА СТРАНИЦА"
		$ScoreColorRect/HBoxContainer/ScoreLabel.text = "Най-висок резултат:"
		$PlaceColorRect/HBoxContainer/PlaceLabel.text = "Вашето място:"
		$ReturnToMenuBtn.text = "ОБРАТНО КЪМ МЕНЮТО"
