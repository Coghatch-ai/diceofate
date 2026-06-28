## tools/capture_floor_hole.gd — capture top-down view of CSG floor hole
extends Node

var _frame: int = 0
var _cam: Camera3D
var _saved: bool = false


func _ready() -> void:
	var level_scene: PackedScene = load("res://levels/iron_floor.tscn") as PackedScene
	var level: Node = level_scene.instantiate()
	add_child(level)
	_cam = Camera3D.new()
	_cam.name = "HoleCam"
	_cam.position = Vector3(24, 6, 16)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.fov = 25.0
	_cam.near = 0.1
	_cam.far = 50.0
	add_child(_cam)
	_cam.make_current()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 30 and not _saved:
		_saved = true
		var img: Image = get_viewport().get_texture().get_image()
		var base: String = "/Users/arthurnunes/Library/MRHEWBUC-LOCAL/diceofate/game"
		var dest: String = base + "/.xenodot/handoffs/shots/floor_hole_top.png"
		img.save_png(dest)
		print("Saved hole top-down: ", dest)
		get_tree().quit()
