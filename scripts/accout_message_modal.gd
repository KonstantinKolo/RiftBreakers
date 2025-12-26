extends Control

@onready var header_label: Label = $Modal/MarginContainer/VBoxContainer/HeaderLabel
@onready var message_label: Label = $Modal/MarginContainer/VBoxContainer/MessageLabel

var is_open: bool = false
var _should_unpause: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_unhandled_key_input(false)
	visible = false
	hide()

func set_text(header: String, message: String) -> void:
	header_label.text = header
	message_label.text = message

func prompt(pause: bool = false) -> void:
	_should_unpause = (get_tree().paused == false) and pause
	if pause:
		get_tree().paused = true
	show()
	is_open = true
	set_process_unhandled_key_input(true)

func close(is_confirmed: bool = false) -> void:
	if is_confirmed:
		confirm()
	else:
		cancel() 

func confirm() -> void:
	_close_modal(true)

func cancel() -> void:
	_close_modal(false)

func _close_modal(is_confirmed: bool) -> void:
	set_process_unhandled_key_input(false)
	set_deferred("is_open", false)
	hide()
	if _should_unpause:
		get_tree().paused = false

func _on_confirm_button_pressed() -> void:
	visible = false
