extends Node3D

@onready var smoke: GPUParticles3D = $Smoke
@onready var fire: GPUParticles3D = $Fire
@onready var fire_sound: AudioStreamPlayer3D = $FireSound

func shoot():
	smoke.emitting = true
	fire.emitting = true
	fire_sound.play()
	
	await get_tree().create_timer(0.8).timeout
	queue_free()
