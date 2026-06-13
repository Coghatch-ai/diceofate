# main.gd — persistent shell: loads and swaps level scenes under %LevelHost.
extends Node

@export_file("*.tscn") var initial_level: String = "res://levels/blockout_01.tscn"

var current_level: Node = null
var _levels: Array[String] = [
	"res://levels/basic_room.tscn",
	"res://levels/blockout_01.tscn",
	"res://levels/blockout_02.tscn",
	"res://levels/blockout_03.tscn",
	"res://levels/open_world.tscn"
]
var _level_index: int = 0

@onready var _level_host: Node = %LevelHost


func _ready() -> void:
	_level_index = _levels.find(initial_level)
	if _level_index == -1:
		_level_index = 0
	load_level(initial_level)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_level"):
		_level_index = (_level_index + 1) % _levels.size()
		load_level(_levels[_level_index])


func load_level(path: String) -> void:
	if current_level != null:
		# free(), not queue_free(): one frame of two live levels conflicts camera/WorldEnvironment
		current_level.free()
		current_level = null
	current_level = (load(path) as PackedScene).instantiate()
	_level_host.add_child(current_level)

	# Find the player and wire it to the camera rig
	var player := current_level.find_child("Player") as Player
	if player != null:
		var rig: CameraRig = %CameraRig
		rig.target = player
		player.camera_rig = rig
