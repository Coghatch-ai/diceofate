# main.gd — persistent shell: loads and swaps level scenes under %LevelHost.
extends Node

@export_file("*.tscn") var initial_level: String = "res://levels/firing_yard.tscn"

var current_level: Node = null
var _levels: Array[String] = [
	"res://levels/firing_yard.tscn",
	"res://levels/ruined_warehouse.tscn",
]
var _level_index: int = 0
var _result_showing: bool = false

@onready var _level_host: Node = %LevelHost
@onready var _crosshair: Crosshair = %Crosshair
@onready var _arena_hud: ArenaHud = %ArenaHud


func _ready() -> void:
	# Must process while paused so _input handles the restart action on the end screen.
	process_mode = PROCESS_MODE_ALWAYS
	if _levels.is_empty() or initial_level.is_empty():
		return
	_level_index = _levels.find(initial_level)
	if _level_index == -1:
		_level_index = 0
	load_level(_levels[_level_index])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_level"):
		if _levels.is_empty():
			return
		_level_index = (_level_index + 1) % _levels.size()
		load_level(_levels[_level_index])

	if _result_showing and event.is_action_pressed("restart"):
		get_tree().paused = false
		_result_showing = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_arena_hud.hide_result()
		load_level(_levels[_level_index])


func load_level(path: String) -> void:
	if current_level != null:
		# free(), not queue_free(): one frame of two live levels conflicts camera/WorldEnvironment
		current_level.free()
		current_level = null
	current_level = (load(path) as PackedScene).instantiate()
	_level_host.add_child(current_level)

	# If the level ships an FPS player, make its eye-camera current in the SubViewport
	# and inject the persistent HUD crosshair for fire/hit feedback.
	# The orthographic CameraRig remains in the scene tree but is inert for FPS levels.
	var player := current_level.find_child("Player") as Player
	if player != null:
		var camera := player.find_child("Camera3D", true, false) as Camera3D
		if camera != null:
			camera.make_current()
		player.set_crosshair(_crosshair)
		player.set_ammo_hud(_arena_hud)

	# Wire WaveManager signals to the persistent HUD (if the level has one).
	# Guard score reset: when RunStateData.active is in flight the carried score_changed emit
	# from _seed_start will update the HUD — zeroing here would flash 0 before it fires.
	if not RunStateData.active:
		_arena_hud.set_score(0)
	_arena_hud.set_active(0)
	var wave_manager := current_level.find_child("WaveManager") as WaveManager
	if wave_manager != null:
		wave_manager.score_changed.connect(_arena_hud.set_score)
		wave_manager.active_changed.connect(_arena_hud.set_active)
		wave_manager.lives_changed.connect(_arena_hud.set_lives)
		wave_manager.run_lost.connect(_on_run_ended.bind(false))
		wave_manager.advance_level.connect(_on_advance_level)
		_arena_hud.set_lives(wave_manager.lives)


func _on_advance_level(score: int, lives: int) -> void:
	RunStateData.active = true
	RunStateData.score = score
	RunStateData.lives = lives
	_level_index = (_level_index + 1) % _levels.size()
	# Deferred: signal may arrive from inside an enemy's own physics/attack callback.
	# Calling load_level() synchronously frees the level (and the enemy) while still
	# executing inside perform_attack() — create_tween() on a freed instance crashes.
	load_level.call_deferred(_levels[_level_index])


func _on_run_ended(score: int, won: bool) -> void:
	_result_showing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_arena_hud.show_result(won, score)
