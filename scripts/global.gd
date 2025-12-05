extends Node

signal scoreChanged
signal triggeredMap

var has_unlocked_level_2: bool = false
var has_unlocked_level_3: bool = false
var has_cleared_game: bool = false

var melee_bots_killed: int = 0
var ranged_bots_killed: int = 0
var bosses_killed: int = 0 # for the game instance
var total_time: int = 0 # in seconds
var second_timer: float = 0.0
var count_time: bool = false

var has_dynamite_unlocked: bool = false
var has_rifle_unlocked: bool = false

signal signalFPS
signal signalPlayerFPS
var show_fps: bool = false
var fps_label: Label = Label.new()

func _ready() -> void:
	signalFPS.connect(fps_handle)
	signalPlayerFPS.connect(fps_handle_player)
	triggeredMap.connect(_on_map_triggered)

func _process(delta: float) -> void:
	if count_time:
		second_timer += delta
		if second_timer >= 1.0:
			second_timer = 0.0
			total_time += 1
		if total_time % 60 == 0: #runs every minute
			scoreChanged.emit()
	if show_fps and is_instance_valid(fps_label):
		fps_label.text = "FPS: %s" % [Engine.get_frames_per_second()]

func _on_map_triggered() -> void:
	count_time = !count_time

func on_ranged_killed() -> void:
	ranged_bots_killed += 1
	scoreChanged.emit()
func on_melee_killed() -> void:
	melee_bots_killed += 1
	scoreChanged.emit()
func on_boss_killed() -> void:
	bosses_killed += 1
	scoreChanged.emit()
func calculate_score() -> int:
#   +10 points per melee kill
#   +15 points per ranged kill
#   +50 points for boss
#   -20 point per minute played
	var total_score: int = Global.melee_bots_killed * 10 \
					+ Global.ranged_bots_killed * 15 \
					+ Global.bosses_killed * 50 \
					- int(Global.total_time / 60) * 20
	return total_score

func fps_handle() -> void:
	if !show_fps:
		show_fps = true
		display_fps()
	else:
		show_fps = false
		display_fps()
func fps_handle_player() -> void:
	if !show_fps:
		show_fps = true
		display_fps_player()
	else:
		show_fps = false
		display_fps_player()

func display_fps() -> void:
	var current_scene = get_tree().current_scene
	if show_fps:
		current_scene.add_child(fps_label)
	else:
		current_scene.remove_child(fps_label)
func display_fps_player() -> void:
	var current_scene = get_tree().current_scene
	var player = null
	for child in current_scene.get_children():
		if child.is_in_group("player"): player = child
	
	if player == null: assert("global.gd: Player not found in the current scene!") 
	var mounting_point = player.get_child(2).get_child(0).get_child(0)
	if !is_instance_valid(fps_label):
		fps_label = Label.new()
	if show_fps:
		mounting_point.add_child(fps_label)
	else:
		mounting_point.remove_child(fps_label)
