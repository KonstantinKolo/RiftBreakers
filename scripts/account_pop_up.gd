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
		return
	
	var body := {
		"username": username,
		"password": password
	}
	var json_body: String = JSON.stringify(body)
	
	var http := HTTPRequest.new()
	add_child(http)
	http.set_tls_options(TLSOptions.client_unsafe())
	http.request_completed.connect(_on_request_completed)
	var url := "%sauth/login" % [Global.base_url]
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
		return
func _on_register_button_pressed() -> void:
	var username: String = username_field.text.strip_edges()
	var password: String = password_field.text.strip_edges()
	var display_name: String = display_name_field.text.strip_edges()

	if username.is_empty() or password.is_empty() or display_name.is_empty():
		# Username, password and display name must be filled
		return
	var body := {
		"username": username,
		"password": password,
		"displayName": display_name
	}
	var json_body: String = JSON.stringify(body)
	
	var http := HTTPRequest.new()
	add_child(http)
	http.set_tls_options(TLSOptions.client_unsafe())
	http.request_completed.connect(_on_request_completed)
	var url := "%sauth/register" % [Global.base_url]
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
		return

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
		return
	file.store_string(JSON.stringify(data))
	file.close()
	Global.load_login_data()

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if accout_message_modal == null:
		push_error("accout_message_modal is null!")
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		accout_message_modal.set_text("Connection failed", "Could not reach the server. Check your internet connection.")
		accout_message_modal.show()
		return
	
	var response_text := body.get_string_from_utf8()
	if response_code == 200:
		_set_logged_in_username(body)
		_set_logged_in_data(body)
		accout_message_modal.set_text("Request successful", "You have successfully logged in!")
		accout_message_modal.show()
	else:
		var error_message := response_text
		var json := JSON.new()
		if json.parse(response_text) == OK:
			var data = json.data
			if data is Dictionary and data.has("error"):
				error_message = data["error"]
		accout_message_modal.set_text("Request failed", error_message)
		accout_message_modal.show()
func _set_logged_in_data(body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		#Failed to parse JSON
		return
	var data: Dictionary = json.data
	if data.has("username") && data.has("token") && data.has("displayName") && data.has("role"):
		save_login_data(data["username"], data["token"], data["displayName"], data["role"])
		_delete_local_data()
func _set_logged_in_username(body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		return
	var data: Dictionary = json.data
	if data.has("username"):
		label_logged_username.text = data["username"]
	#USERNAME SET

func _delete_local_data() -> void: #Delete users locally start data and strat a new session
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("save_data.json")
	Global.reset_progress()
