extends Control

@export var menu_size = 0.7
@export var lerp_speed = 0.2

const SAVE_PATH := "user://login_data.json"

@onready var account_box: ColorRect = $"../AccountBox"
@onready var username_field: TextEdit = $VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/UsernameField
@onready var password_field: LineEdit = $VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/PasswordField
@onready var display_name_field: TextEdit = $VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer3/DisplayNameField
@onready var label_logged_username: Label = $VBoxContainer/SettingsBody/MarginContainer/VBoxContainer/HBoxContainer3/LabelLoggedUsername
@onready var user_info: ColorRect = $"../UserInfo"
@onready var level_test: TextureRect = $"../Map/LevelTest"

@onready var accout_message_modal: Control = $"../AccoutMessageModal"

var _popped_up = false

# Only Y anchors matter for vertical movement
var _up_anchor_y = -menu_size   # Hidden above the screen
var _down_anchor_y: float = 0          # Fully visible at top
var _target_anchor_y = -menu_size

func _ready() -> void:
	account_box.is_clicked.connect(_open_pop_up)
	if Global.username != "":
		label_logged_username.text = Global.username
	
	# Start hidden above the screen
	anchor_top = _up_anchor_y
	anchor_bottom = _up_anchor_y + menu_size


func _process(delta: float) -> void:
	# Smooth vertical animation
	anchor_top = lerp(anchor_top, _target_anchor_y, lerp_speed)
	anchor_bottom = anchor_top + menu_size

func _on_close_pressed() -> void:
	_open_pop_up()

func _open_pop_up() -> void:
	if !_popped_up:
		_target_anchor_y = _down_anchor_y   # Slide down into view
	else:
		_target_anchor_y = _up_anchor_y     # Slide back up off-screen
	_popped_up = !_popped_up


func _on_login_button_pressed() -> void:
	var username: String = username_field.text.strip_edges()
	var password: String = password_field.text.strip_edges()

	if username.is_empty() or password.is_empty():
		print("Username and password must be filled")
		return
	
	var body := {
		"username": username,
		"password": password
	}
	var json_body: String = JSON.stringify(body)
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	var url := "http://localhost:3000/api/auth/login"
	var headers := [
		"Content-Type: application/json"
	]
	# Send POST request
	var err := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		print("HTTPRequest error:", err)
func _on_register_button_pressed() -> void:
	var username: String = username_field.text.strip_edges()
	var password: String = password_field.text.strip_edges()
	var display_name: String = display_name_field.text.strip_edges()

	if username.is_empty() or password.is_empty() or display_name.is_empty():
		print("Username, password and display name must be filled")
		return
	var body := {
		"username": username,
		"password": password,
		"displayName": display_name
	}
	var json_body: String = JSON.stringify(body)
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	var url := "http://localhost:3000/api/auth/register"
	var headers := [
		"Content-Type: application/json"
	]
	# Send POST request
	var err := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		print("HTTPRequest error:", err)

func save_login_data(username: String, token: String = "", displayName: String = "", role: String = "user") -> void:
	var data := {
		"username": username,
		"token": token,
		"displayName": displayName,
		"role": role
	}
	
	if role == "admin":
		level_test.visible = true
		user_info.visible = true
	elif role == "tester":
		level_test.visible = true
		user_info.visible = false
	else:
		level_test.visible = false
		user_info.visible = false
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("Failed to open save file")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	Global.load_login_data()
	print("Login data saved")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	if response_code == 200:
		_set_logged_in_username(body)
		_set_logged_in_data(body)
		accout_message_modal.set_text("Request successful", "You have successfully logged in!")
		accout_message_modal.show()
		print("Request successful:",  response_text)
	else:
		accout_message_modal.set_text("Request failed", response_text)
		accout_message_modal.show()
		print("Request failed:", response_code, response_text)
func _set_logged_in_data(body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		print("Failed to parse JSON")
		return
	var data: Dictionary = json.data
	if data.has("username") && data.has("token") && data.has("displayName") && data.has("role"):
		save_login_data(data["username"], data["token"], data["displayName"], data["role"])
		_delete_local_data()
	else:
		print("Username, token, displayName or role not found in response:", data)
func _set_logged_in_username(body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		print("Failed to parse JSON")
		return
	var data: Dictionary = json.data
	if data.has("username"):
		label_logged_username.text = data["username"]
	else:
		print("Username not found in response:", data)
	print("USERNAME SET")

func _delete_local_data() -> void: #Delete users locally start data and strat a new session
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
			print("Save file deleted.")
	else:
		print("No save file to delete.")
	Global.reset_progress()
