extends Control

@export var death_particle : PackedScene
@onready var tv_turn_on_transition: CanvasLayer = $TVTurnOnTransition
var turn_on_has_finished: bool = false

@onready var pop_up_menu: Control = $PopUpMenu
@onready var info_panel_1: PopupPanel = $Map/Level1/InfoPanel1
@onready var info_panel_2: PopupPanel = $Map/Level2/InfoPanel2
@onready var info_panel_3: PopupPanel = $Map/Level3/InfoPanel3
@onready var info_panel_4: PopupPanel = $Map/LevelTest/InfoPanel4

@onready var user_info: ColorRect = $UserInfo

@onready var level_1: TextureRect = $Map/Level1
@onready var level_2: TextureRect = $Map/Level2
@onready var level_3: TextureRect = $Map/Level3
@onready var level_test: TextureRect = $Map/LevelTest
const DOT_CIRCLE = preload("res://assets/backgrounds/dot-circle.png")
const DOT_CIRCLE_SMALL = preload("res://assets/backgrounds/dot-circle-small.png")

@onready var map: TextureRect = $Map
@onready var conf: ConfirmationModal = $ConfirmationModal
var tween : Tween

@onready var _center_x = get_viewport().get_visible_rect().size.x / 2
@onready var _center_y = get_viewport().get_visible_rect().size.y / 2
var target_cords : Vector2
var _is_not_centered = false

func _ready():
	Global.count_time = false
	MusicManager.play_music("res://assets/music/DavidKBD - The Last Pack - Guitar - 08 - loopeable.ogg")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.load_save_data()
	tv_turn_on_transition.turn_on_tv()
	tv_turn_on_transition.tv_finished.connect(_finish_tv)
	pop_up_menu.closeGame.connect(_close_game)
	pop_up_menu.changeLang.connect(_lang_setup)
	if !Global.has_unlocked_level_2:
		level_2.modulate = Color(0.6, 0.31, 0.6)
	if !Global.has_unlocked_level_3:
		level_3.modulate = Color(0.6, 0.31, 0.6)
	
	if Global.role == "admin":
		level_test.visible = true
		user_info.visible = true
	elif Global.role == "tester":
		level_test.visible = true
		user_info.visible = false
	else:
		level_test.visible = false
		user_info.visible = false
	
	_lang_setup()

func _input(event):
	# Mouse in viewport coordinates.
	if event is InputEventMouseMotion and turn_on_has_finished:
		_set_target_cords(event)
		tween = create_tween()
		tween.tween_property(map, "position", target_cords, 3)

func _set_target_cords(event) -> void:
	_is_not_centered = false
	if event.position.y > 3 * _center_y / 2:
		_is_not_centered = true
		target_cords.y = -200
	elif event.position.y < _center_y / 2:
		_is_not_centered = true
		target_cords.y = 0
	if event.position.x > 3 * _center_x / 2:
		_is_not_centered = true
		target_cords.x = -405
	elif event.position.x < _center_x / 2:
		_is_not_centered = true
		target_cords.x = 0
	
	if !_is_not_centered:
		target_cords = Vector2(-251, -98)


func _on_button_1_pressed() -> void:
	if Global.selected_language == "en":
		conf.customize(
			"Enter Level 1?",
			"By clicking this you will enter level one.",
			"Enter",
			"Return"
		)
	elif Global.selected_language == "bg":
		conf.customize(
			"Влизане в Ниво 1?",
			"С натискане на бутона ще влезете в първо ниво.",
			"Влез",
			"Назад"
		)
	
	var is_confirmed = await conf.prompt(true)
	
	if is_confirmed:
		_button_pressed_particles(level_1)
		_transition_to_scene("res://scenes/Maps/map_1.tscn")
func _on_button_2_pressed() -> void:
	if Global.selected_language == "en":
		if Global.has_unlocked_level_2:
			conf.customize(
				"Enter Level 2?",
				"By clicking this you will enter level two.",
				"Enter",
				"Return"
			)
		else:
			conf.customize(
				"Locked level!",
				"You haven't unlocked level two yet.",
				"",
				"Return"
			)
	elif Global.selected_language == "bg":
		if Global.has_unlocked_level_2:
			conf.customize(
				"Влизане в Ниво 2?",
				"С натискане на бутона ще влезете във второ ниво.",
				"Влез",
				"Назад"
			)
		else:
			conf.customize(
				"Заключено ниво!",
				"Все още не сте отключили второ ниво.",
				"",
				"Назад"
			)
	
	var is_confirmed = await conf.prompt(true)
	
	if is_confirmed and Global.has_unlocked_level_2:
		_button_pressed_particles(level_2)
		_transition_to_scene("res://scenes/Maps/map_2.tscn")
	elif is_confirmed:
		conf.cancel()
func _on_button_3_pressed() -> void:
	if Global.selected_language == "en":
		if Global.has_unlocked_level_3:
			conf.customize(
				"Enter Level 3?",
				"By clicking this you will enter level three.",
				"Enter",
				"Return"
			)
		else:
			conf.customize(
				"Locked level!",
				"You haven't unlocked level three yet.",
				"",
				"Return"
			)
	elif Global.selected_language == "bg":
		if Global.has_unlocked_level_3:
			conf.customize(
				"Влизане в Ниво 3?",
				"С натискане на бутона ще влезете в трето ниво.",
				"Влез",
				"Назад"
			)
		else:
			conf.customize(
				"Заключено ниво!",
				"Все още не сте отключили трето ниво.",
				"",
				"Назад"
			)
	
	var is_confirmed = await conf.prompt(true)
	
	
	if is_confirmed and Global.has_unlocked_level_3:
		_button_pressed_particles(level_3)
		_transition_to_scene("res://scenes/Maps/map_3.tscn")
	else:
		conf.cancel()
func _on_button_4_pressed() -> void:
	if Global.selected_language == "en":
		if Global.role == "tester" or Global.role == "admin":
			conf.customize(
				"Enter Level Test?",
				"By clicking this you will enter level test.",
				"Enter",
				"Return"
			)
		else:
			conf.customize(
				"Not allowed!",
				"You don't have permission to play this level.",
				"",
				"Return"
			)
	elif Global.selected_language == "bg":
		if Global.role == "tester" or Global.role == "admin":
			conf.customize(
				"Влизане в Тестово Ниво?",
				"С натискане на бутона ще влезете в тестовото ниво.",
				"Влез",
				"Назад"
			)
		else:
			conf.customize(
				"Нямате достъп!",
				"Нямате разрешение да играете това ниво.",
				"",
				"Назад"
			)
	
	var is_confirmed = await conf.prompt(true)
	
	
	if is_confirmed and (Global.role == "tester" or Global.role == "admin"):
		_button_pressed_particles(level_test)
		_transition_to_scene("res://scenes/Maps/TestScene.tscn")
	else:
		conf.cancel()

func _on_button_1_mouse_entered() -> void:
	_unvisible_info()
	info_panel_1.visible = true
	level_1.texture = DOT_CIRCLE 
	level_1.modulate = Color(1.25, 0.25, 1.2, 1)
func _on_button_1_mouse_exited() -> void:
	level_1.texture = DOT_CIRCLE_SMALL
	level_1.modulate = Color(1.1, 0, 1.2, 1)
func _on_button_2_mouse_entered() -> void:
	_unvisible_info()
	info_panel_2.visible = true
	level_2.texture = DOT_CIRCLE
	if Global.has_unlocked_level_2:
		level_2.modulate = Color(1.25, 0.25, 1.2, 1)
	else:
		level_2.modulate = Color(0.8, 0.37, 0.8)
func _on_button_2_mouse_exited() -> void:
	level_2.texture = DOT_CIRCLE_SMALL
	if Global.has_unlocked_level_2:
		level_2.modulate = Color(1.1, 0, 1.2, 1)
	else:
		level_2.modulate = Color(0.6, 0.31, 0.6)
func _on_button_3_mouse_entered() -> void:
	_unvisible_info()
	info_panel_3.visible = true
	level_3.scale = Vector2(level_3.scale.x + 0.1, level_3.scale.y + 0.1)
	if Global.has_unlocked_level_3:
		level_3.modulate = Color(1.33, 0.35, 1.28, 1)
	else:
		level_3.modulate = Color(0.8, 0.37, 0.8)
func _on_button_3_mouse_exited() -> void:
	level_3.scale = Vector2(level_3.scale.x - 0.1, level_3.scale.y - 0.1)
	if Global.has_unlocked_level_3:
		level_3.modulate = Color(1.28, 0.35, 1.25, 1)
	else:
		level_3.modulate = Color(0.6, 0.31, 0.6)
func _on_button_4_mouse_entered() -> void:
	_unvisible_info()
	info_panel_4.visible = true
	level_test.scale = Vector2(level_test.scale.x + 0.1, level_test.scale.y + 0.1)
	if Global.role == "tester" or Global.role == "admin":
		level_test.modulate = Color(1.33, 0.35, 1.28, 1)
	else:
		level_test.modulate = Color(0.8, 0.37, 0.8)
func _on_button_4_mouse_exited() -> void:
	level_test.scale = Vector2(level_test.scale.x - 0.1, level_test.scale.y - 0.1)
	if Global.role == "tester" or Global.role == "admin":
		level_test.modulate = Color(1.28, 0.35, 1.25, 1)
	else:
		level_test.modulate = Color(0.6, 0.31, 0.6)

func _button_pressed_particles(level : TextureRect) -> void:
	var _particle = death_particle.instantiate()
	_particle.position = level.global_position
	_particle.position = Vector2(_particle.position.x + 50, _particle.position.y + 40)
	_particle.rotation = level.rotation
	_particle.emitting = true
	get_tree().current_scene.add_child(_particle)

func _close_game() -> void:
	if Global.selected_language == "en":
		conf.customize(
			"Are you certain?",
			"This will close the game.",
			"Quit Game",
			"Return To Game"
		)
	elif Global.selected_language == "bg":
		conf.customize(
			"Сигурни ли сте?",
			"Това ще затвори играта.",
			"Излез от играта",
			"Обратно към играта"
		)
	
	var is_confirmed = await conf.prompt(true)
	
	if is_confirmed:
		get_tree().quit()
func _unvisible_info() -> void:
	info_panel_1.visible = false
	info_panel_2.visible = false
	info_panel_3.visible = false
	info_panel_4.visible = false

func _transition_to_scene(pathToNewScene: String):
	TransitionScene.transition()
	await TransitionScene.on_transition_finished
	get_tree().change_scene_to_file(pathToNewScene)
func _finish_tv() -> void:
	turn_on_has_finished = true

func _lang_setup() -> void:
	if Global.selected_language == "en":
		info_panel_1._lang_setup("Strange portals have appeared all over the city, plunging it into chaos. Get rid of the portals, spawning the enemies, and their Boss.", "CITY")
		info_panel_2._lang_setup("A secret enemy hideout has been found in the wilderness. To neutralize the threat, defeat the enemies and their boss.", "FARM LANDS")
		info_panel_3._lang_setup("The enemies have launched a huge attack on the capital city. Stop them from taking it over and destroy their portal and Boss.", "CAPITAL")
		info_panel_4._lang_setup("Testing level. Created for admins and testers to try new features.", "Test")
		$account_pop_up._lang_setup()
	elif Global.selected_language == "bg":
		info_panel_1._lang_setup("Странни портали се появиха из целия град, потапяйки го в хаос. Отървете се от порталите, пораждащи враговете, и техния Бос.", "ГРАД")
		info_panel_2._lang_setup("Тайно вражеско убежище е открито сред дивата природа. За да неутрализирате заплахата, победете враговете и техния бос.", "ПОЛЯ")
		info_panel_3._lang_setup("Враговете са започнали огромна атака срещу столицата. Спрете ги да я завладеят и унищожете техния портал и Бос.", "СТОЛИЦА")
		info_panel_4._lang_setup("Тестово ниво. Създадено за администратори и тестери за изпробване на нови функции.", "Тест")
		$account_pop_up._lang_setup()
