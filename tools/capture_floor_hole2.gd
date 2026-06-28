## tools/capture_floor_hole2.gd — SceneTree script: top-down CSG hole capture
extends SceneTree

var _frame: int = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 30:
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
	var wenv: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	wenv.environment = env
	get_root().add_child(wenv)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.position = Vector3(0, 10, 0)
	sun.rotation_degrees = Vector3(-60, 0, 0)
	sun.light_energy = 1.0
	get_root().add_child(sun)

	var level_scene: PackedScene = load("res://levels/iron_floor.tscn") as PackedScene
	var level: Node = level_scene.instantiate()
	get_root().add_child(level)

	var cam: Camera3D = Camera3D.new()
	cam.name = "HoleCam"
	cam.position = Vector3(24, 6, 16)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 22.0
	cam.near = 0.05
	cam.far = 50.0
	get_root().add_child(cam)
	cam.make_current()
