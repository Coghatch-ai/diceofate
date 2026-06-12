# tools/verify_render.gd — godot-verify layer 3: render check (flat-color detector).
extends SceneTree
## Boots a scene, renders ~20 frames, and fails if the output is a flat color
## (the signature of "valid scene, renders nothing" — e.g. a camera pointing
## away from the world, missing sky, no current camera).
##
## Requires a display — run WITHOUT --headless (a window flashes briefly):
##   $GODOT --path . --resolution 640x360 -s tools/verify_render.gd               # main scene
##   $GODOT --path . --resolution 640x360 -s tools/verify_render.gd -- levels/foo.tscn
##
## Output: one VERIFY-RENDER: OK/FAIL line. Exit code 0/1. No images are shown;
## the sampled frame is saved to .godot/verify_render_last.png for human inspection.

const WARMUP_FRAMES := 20
const GRID := 32  # sample a GRID x GRID grid of pixels
const FLAT_SPREAD := 0.005  # max-min luminance below this = flat image

var _frames := 0
var _scene_path := ""


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		_scene_path = user_args[0]
		if not _scene_path.begins_with("res://"):
			_scene_path = "res://" + _scene_path
	else:
		_scene_path = ProjectSettings.get_setting("application/run/main_scene", "")
	if _scene_path == "":
		_fail("no scene argument and no run/main_scene set")
		return
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		_fail("could not load scene")
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var img := root.get_texture().get_image()
	img.save_png("res://.godot/verify_render_last.png")
	var lum_min := 1.0
	var lum_max := 0.0
	var lum_sum := 0.0
	var samples := 0
	# intentional: pixel grid step in whole pixels
	@warning_ignore("integer_division")
	var step_x := maxi(1, img.get_width() / GRID)
	# intentional: pixel grid step in whole pixels
	@warning_ignore("integer_division")
	var step_y := maxi(1, img.get_height() / GRID)
	for y: int in range(0, img.get_height(), step_y):
		for x: int in range(0, img.get_width(), step_x):
			var l := img.get_pixel(x, y).get_luminance()
			lum_min = minf(lum_min, l)
			lum_max = maxf(lum_max, l)
			lum_sum += l
			samples += 1
	var spread := lum_max - lum_min
	var avg := lum_sum / samples
	if spread < FLAT_SPREAD:
		_fail(
			(
				(
					"renders a flat color (avg luminance %.3f, spread %.3f)"
					+ " — nothing visible; check camera direction/current, lights, sky"
				)
				% [avg, spread]
			)
		)
	else:
		print(
			"VERIFY-RENDER: OK — %s (avg luminance %.3f, spread %.3f)" % [_scene_path, avg, spread]
		)
		quit(0)
	return true


func _fail(reason: String) -> void:
	print("VERIFY-RENDER: FAIL — %s: %s" % [_scene_path, reason])
	quit(1)
