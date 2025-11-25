extends Node3D

# TODO make it unavailable for access to levels when the boss is alive

@export var current_level: int

@onready var portal: MeshInstance3D = $StarGate5/Portal
@onready var deactivated: MeshInstance3D = $StarGate5/Deactivated
@onready var activated: MeshInstance3D = $StarGate5/Activated
@onready var area_teleport: Area3D = $AreaTeleport

@onready var progress_bar: ProgressBar = $SubViewport/ProgressBar
var target_visible: bool = false

@onready var players_camera: Node = get_node("/root/Node3D/Player/camera_mount/Camera3D")

@onready var explosion_scene: PackedScene = preload("res://scenes/ParticleEffects/explosion.tscn")

@export var map_path: String

@export var is_spawn: bool = false
var in_spawn_range: bool = false
@export var map_max_enemy_count: int = 10
@export var spawn_speed: float = 7.0
@export var spawn_distance: float = 0.5
@export var despawn_distance : float = 100.0
@export var teleport_delay: float= 2.0  
@export var enemy_type: PackedScene
var spawned_enemies: Array[CharacterBody3D] = []

const MAX_HEALTH: int = 300
var health: int = MAX_HEALTH
var time: float = 0.0
var spawn_timer: float = 0.0
var is_teleporting: bool = false
var player_in_portal: bool = false
var reverse_anim_bool: bool = false

func _ready() -> void:
	portal.visible = true
	deactivated.visible = false
	activated.visible = true
	
	progress_bar.visible = false
	progress_bar.value = health
	
	if area_teleport:
		area_teleport.body_entered.connect(_on_portal_body_entered)

func _process(delta: float) -> void:
	time += delta
	if activated.material_overlay and activated.material_overlay.next_pass and \
	   activated.material_overlay.next_pass is ShaderMaterial:
		activated.material_overlay.next_pass.set("shader_parameter/time", time)
	
	if is_spawn and health > 0 and in_spawn_range:
		spawn_timer += delta
		if spawn_timer >= spawn_speed && get_enemy_count() < map_max_enemy_count:
			_spawn_enemy()
			spawn_timer = 0.0

# Teleport functionality
func _on_portal_body_entered(body: Node) -> void:
	if map_path == "" or map_path == null:
		push_warning("No map_path assigned for teleportation.")
		return
	if current_level == 1 and !Global.has_unlocked_level_2: return
	if current_level == 2 and !Global.has_unlocked_level_3: return
	if current_level == 3 and !Global.has_cleared_game: return
	if is_teleporting: return
	if is_spawn: return
	
	if body.is_in_group("player"):
		is_teleporting = true
		player_in_portal = true
		var scene_res = load(map_path)
		if not scene_res:
			push_error("Failed to load map: " + str(map_path))
			is_teleporting = false
			return
		
		if is_inside_tree():
			get_tree().change_scene_to_packed(scene_res)

func _spawn_enemy() -> void:
	if enemy_type == null:
		push_warning("No enemy_type assigned to spawner: " + str(self.name))
		return
	
	# Calculate spawn position relative to portal
	var forward_dir = -global_transform.basis.z.normalized()
	var spawn_position = global_transform.origin + forward_dir * spawn_distance

	var enemy_instance = enemy_type.instantiate()
	enemy_instance.global_transform.origin = spawn_position
	if is_inside_tree():
		get_tree().current_scene.add_child(enemy_instance)
	
	spawned_enemies.append(enemy_instance)
	
	# make the enemy face the player
	if players_camera:
		var dir_to_player = (players_camera.global_transform.origin - enemy_instance.global_transform.origin).normalized()
		var look_rotation = Basis.looking_at(dir_to_player)
		enemy_instance.global_transform.basis = look_rotation
func get_enemy_count() -> int:
	var count = 0
	if !is_inside_tree(): return 0
	for node in get_tree().current_scene.get_children():
		if node.scene_file_path == enemy_type.resource_path:
			count += 1
	return count

func deactivate() -> void:
	portal.visible = false
func activate() -> void:
	portal.visible = true

# Empty so the general functionality of enemies will work here
func show_target() -> void:
	return
func hide_target() -> void:
	return
# Methods to change the material overlay
func change_mat_overlay(ENEMY_OUTLINE, ENEMY_STATIC_MATERIAL) -> void:
	activated.material_overlay = ENEMY_OUTLINE
	activated.material_overlay.next_pass = ENEMY_STATIC_MATERIAL
func remove_mat_overlay() -> void:
	activated.material_overlay = null
# Method to show the health bar
func show_health_bar() -> void:
	if progress_bar and is_spawn:
		progress_bar.visible = true
# Method to hide the health bar
func hide_health_bar() -> void:
	if progress_bar and health == MAX_HEALTH:
		progress_bar.visible = false

func hurt(hit_points: int) -> void:
	if !is_spawn:
		return
	
	show_health_bar()
	if hit_points < health:
		health -= hit_points
		progress_bar.value = health
	else:
		if progress_bar.value == 0: return
		
		health = 0
		progress_bar.value = health
		destroy()

func _return_health() -> int:
	return health

func destroy() -> void:
	var bodies = $Radius.get_overlapping_bodies()
	for obj in bodies:
		if obj.has_method("hurt"):
			obj.hurt(50)
		elif obj.get_parent().is_in_group("obstacles"):
			obj.get_parent().queue_free()
	
	var explosion = explosion_scene.instantiate()
	if is_inside_tree():
		get_tree().root.add_child(explosion)
	explosion.global_position = global_position + Vector3(0, 2, 0)
	explosion.explode()
	
	portal.visible = false
	activated.visible = false
	deactivated.visible = true
	
	hide_health_bar()
	
	return

#detects when the player goes in and out of range
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		in_spawn_range = true
		if spawned_enemies.size() == 0:
			#spawn some initial enemies
			_spawn_enemy()
			if is_inside_tree():
				await get_tree().create_timer(1.0).timeout
				_spawn_enemy()
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		in_spawn_range = false
		_despawn_enemies_later(body)
func _despawn_enemies_later(player: Node3D) -> void:
	# despawns enemies if player is far away
	# saves FPS
	while player and player.global_position.distance_to(global_position) <= despawn_distance and is_inside_tree():
		await get_tree().process_frame
	
	#some enemies may have died so we will check if they still exist
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
