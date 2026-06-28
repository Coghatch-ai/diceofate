## tools/capture_floor_hole3.gd — higher camera, wider FOV for floor hole top view
extends SceneTree

var _frame: int = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 40:
		return false
	var img: Image = get_root().get_texture().get_image()
	var base: String = "/Users/arthurnunes/Library/MRHEWBUC-LOCAL/diceofate/game"
	var dest: String = base + "/.xenodot/handoffs/shots/floor_hole_top.png"
	var err: Error = img.save_png(dest)
	if err == OK:
		print("HOLE-CAPTURE: saved ", dest)
	else:
		printerr("HOLE-CAPTURE: save failed err=", err)
	quit()
	return false


func _initialize() -> void:
	var level_scene: PackedScene = load("res://levels/iron_floor.tscn") as PackedScene
	var level: Node = level_scene.instantiate()
	get_root().add_child(level)

	# Camera higher up, looking straight down at the hole at world center (24, -0.2, 16)
	# FloorHoleCutter local pos (0, 0.2, 0) -> world (24, 0, 16)
	var cam: Camera3D = Camera3D.new()
	cam.name = "HoleCam"
	cam.position = Vector3(24, 12, 16)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 35.0
	cam.near = 0.05
	cam.far = 100.0
	get_root().add_child(cam)
	cam.make_current()
