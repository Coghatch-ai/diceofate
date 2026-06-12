extends Node

@export_file("*.tscn") var initial_level: String = "res://levels/basic_room.tscn"

var current_level: Node = null
@onready var _level_host: Node = %LevelHost

func _ready() -> void:
	load_level(initial_level)

func load_level(path: String) -> void:
	if current_level != null:
		current_level.free()  # synchronous: queue_free() leaves both levels alive one frame → camera/WorldEnvironment conflicts
		current_level = null
	current_level = (load(path) as PackedScene).instantiate()
	_level_host.add_child(current_level)

	# Find the player and assign to camera rig target
	var player := current_level.find_child("Player")
	if player:
		%CameraRig.target = player
		player.camera_rig = %CameraRig
