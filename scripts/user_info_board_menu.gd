extends Control

@onready var item_list: ItemList = $MarginContainer/VBoxContainer/ItemList
@onready var username_line: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/UsernameLine
@onready var option_button: OptionButton = $HBoxContainer/OptionButton


var current_page := 1
var limit := 50

func _ready() -> void:
	load_board(current_page)

func load_board(page: int) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_board_response)

	var url := "http://localhost:3000/api/admin/users?page=%d&limit=%d" % [page, limit]
	var headers := [
		"Authorization: Bearer %s" % Global.token,
		"Content-Type: application/json"
	]
	
	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_board_response(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response_code != 200:
		print("Failed to load leaderboard")
		return
	
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("Invalid leaderboard JSON")
		return
	
	var response: Dictionary = json.data
	var entries: Array = response.get("data", [])
	
	item_list.clear()
	
	for entry in entries:
		var name = entry.get("username", "Unknown")
		var score = entry.get("highscore", 0)
		var role = entry.get("role")
		var text := "%s  —  %d pts  —  %s" % [name, score, role]
		item_list.add_item(text)
		item_list.set_item_metadata(item_list.get_item_count() - 1, entry)
func _on_user_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Failed to load user:", response_code, body.get_string_from_utf8())
		return
	
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("Invalid JSON")
		return
	
	var response: Dictionary = json.get_data()
	var user: Dictionary = response.get("user", {})
	
	if user.size() == 0:
		print("User not found")
		return
	# Clear ItemList and show the single user
	item_list.clear()
	var name = user.get("username", "Unknown")
	var score = user.get("highscore", 0)
	var role = user.get("role", "user")
	var text := "%s — %d pts — %s" % [name, score, role]
	item_list.add_item(text)
	item_list.set_item_metadata(item_list.get_item_count() - 1, user)
func _on_set_role_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text := body.get_string_from_utf8()
	if response_code != 200:
		print("Failed to set role:", response_code, body_text)
		return
	var json := JSON.new()
	if json.parse(body_text) != OK:
		print("Invalid JSON response")
		return
	var response: Dictionary = json.get_data()
	load_board(current_page) #update the board
	print("Role updated successfully:", response)


func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var user = item_list.get_item_metadata(index)
	username_line.text = user.get("username", "Unknown")
func _on_search_by_user_button_pressed() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_user_response)
	
	var username: String = username_line.text.strip_edges()
	if username == "": load_board(current_page)
	
	var url := "http://localhost:3000/api/admin/user/%s" % username
	var headers := [
		"Authorization: Bearer %s" % Global.token,
		"Content-Type: application/json"
	]
	
	http.request(url, headers, HTTPClient.METHOD_GET)

func _on_previous_page_button_pressed() -> void:
	if current_page > 1:
		current_page -= 1
		load_board(current_page)
func _on_next_page_button_pressed() -> void:
	current_page += 1
	load_board(current_page)

func _on_assign_role_button_pressed() -> void:
	var selected_role = option_button.text
	var username: String = username_line.text.strip_edges()
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_set_role_response)
	var url := "http://localhost:3000/api/admin/set-role"
	var headers := [
		"Authorization: Bearer %s" % Global.token,
		"Content-Type: application/json"
	]
	var body_dict := {
		"username": username,
		"role": selected_role
	}
	var body_json := JSON.stringify(body_dict)
	http.request(url, headers, HTTPClient.METHOD_POST, body_json)

func _on_return_to_menu_btn_pressed() -> void:
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file("res://Maps/menu.tscn")
