## tools/verify_floor_hole.gd — one-shot render of iron_floor from above to verify CSG hole
extends SceneTree


func _init() -> void:
	pass


func _ready() -> void:
	var level_scene: PackedScene = load("res://levels/iron_floor.tscn") as PackedScene
	if level_scene == null:
		printerr("Could not load iron_floor.tscn")
		quit(1)
		return
	var level: Node = level_scene.instantiate()
	get_root().add_child(level)

	# Add a camera pointing straight down at floor center (24, -0.2, 16)
	# Camera at y=8, looking down
	var cam: Camera3D = Camera3D.new()
	cam.name = "HoleVerifyCam"
	cam.position = Vector3(24, 8, 16)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 30.0
	cam.near = 0.1
	cam.far = 100.0
	get_root().add_child(cam)
	cam.make_current()

	# Wait a few frames for CSG to process
	await create_timer(0.5).timeout
	var vp: Viewport = get_root()
	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("Failed to capture viewport image")
		quit(1)
		return
	var out_path: String = "res://.xenodot/handoffs/shots/floor_hole_top.png"
	var err: int = img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		printerr("Failed to save image: ", err)
		quit(1)
		return
	print("Saved: ", out_path)
	quit(0)
