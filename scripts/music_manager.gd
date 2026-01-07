extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer

var current_track: AudioStream = null
var next_track: AudioStream = null
var fade_time: float = 1.0  # default fade duration in seconds

func _ready():
	# Play a default track on startup
	if not music_player.playing:
		play_music("res://assets/music/DavidKBD - The Last Pack - Guitar - 08 - loopeable.ogg")

# Call this to change music with fade
func play_music(path: String, custom_fade_time: float = 1.0) -> void:
	var new_track = load(path) as AudioStream
	if new_track == current_track:
		return  # already playing
	
	fade_time = custom_fade_time
	next_track = new_track

	if music_player.playing:
		_fade_out_then_switch()
	else:
		_start_new_track()

# INTERNAL: fade out, then switch to next_track
var current_tween: Tween = null  # store active tween

func _fade_out_then_switch() -> void:
	if current_tween:
		current_tween.kill()
		current_tween = null
	
	current_tween = create_tween()
	current_tween.tween_property(music_player, "volume_db", -80, fade_time)  # absolute
	current_tween.tween_callback(func():
		_start_new_track()
	)

func _start_new_track() -> void:
	if next_track:
		music_player.stream = next_track
		current_track = next_track
		next_track = null
	
	music_player.play()
	music_player.volume_db = -80  # start muted

	current_tween = create_tween()
	current_tween.tween_property(music_player, "volume_db", 0, fade_time)  # absolute
