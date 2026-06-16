# main.gd — persistent shell: loads and swaps level scenes under %LevelHost.
extends Node

@export_file("*.tscn") var initial_level: String = "res://levels/firing_yard.tscn"

var current_level: Node = null
var _levels: Array[String] = [
	"res://levels/firing_yard.tscn",
]
var _level_index: int = 0

@onready var _level_host: Node = %LevelHost
@onready var _crosshair: Crosshair = %Crosshair
@onready var _arena_hud: ArenaHud = %ArenaHud


func _ready() -> void:
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
		var camera := player.find_child("Camera3D") as Camera3D
		if camera != null:
			camera.make_current()
		player.set_crosshair(_crosshair)

	# Wire WaveManager signals to the persistent HUD (if the level has one).
	_arena_hud.set_kills(0)
	_arena_hud.set_active(0)
	var wave_manager := current_level.find_child("WaveManager") as WaveManager
	if wave_manager != null:
		wave_manager.kills_changed.connect(_arena_hud.set_kills)
		wave_manager.active_changed.connect(_arena_hud.set_active)
