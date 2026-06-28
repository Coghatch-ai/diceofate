# tools/play_wall_shot.gd — windowed capture + render-health of iron_floor wall.glb.
# Run WITHOUT --headless (needs a display):
#   $GODOT --path . --resolution 1280x720 -s tools/play_wall_shot.gd
# Boots iron_floor, adds a camera at first-person height inside the arena, captures
# two vantages (a wall run + a corner), saves PNGs, and prints render-health metrics.
extends SceneTree

const LEVEL := "res://levels/iron_floor.tscn"
const EYE_H := 1.6
const WARMUP := 28

# Each vantage: [out_png, eye_pos, look_at_target].
var _vantages: Array = [
	# Straight-on at the z=1 wall run (panels overlap 2m → coplanar z-fight test).
	["res://.godot/wall_shot_1.png", Vector3(7.0, EYE_H, 5.0), Vector3(7.0, EYE_H, 1.0)],
	# Grazing along the run to expose seam tearing + wall-base/floor gap.
	["res://.godot/wall_shot_2.png", Vector3(1.5, EYE_H, 4.5), Vector3(13.0, EYE_H, 1.0)]
]

var _frame: int = 0
var _idx: int = 0
var _cam: Camera3D = null
var _captured: int = 0


func _initialize() -> void:
	print("=== WALL SHOT CAPTURE ===")
	var packed := load(LEVEL) as PackedScene
	if packed == null:
		push_error("could not load %s" % LEVEL)
		quit(1)
		return
	root.add_child(packed.instantiate())
	# Lighting: iron_floor relies on Main for camera/env, so supply our own.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.45, 0.5)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.2
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.current = true
	root.add_child(_cam)
	_aim(0)


func _aim(i: int) -> void:
	var v: Array = _vantages[i]
	# SEAM: vantage rows are heterogeneous [String, Vector3, Vector3] literals.
	@warning_ignore("unsafe_cast")
	var eye: Vector3 = v[1] as Vector3
	# SEAM: heterogeneous vantage row.
	@warning_ignore("unsafe_cast")
	var target: Vector3 = v[2] as Vector3
	_cam.global_position = eye
	_cam.look_at(target, Vector3.UP)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < WARMUP:
		return false
	var v: Array = _vantages[_idx]
	# SEAM: heterogeneous vantage row.
	@warning_ignore("unsafe_cast")
	var path: String = v[0] as String
	var img := root.get_texture().get_image()
	img.save_png(path)
	_report(path, img)
	_captured += 1
	_idx += 1
	if _idx >= _vantages.size():
		print("=== DONE: %d vantage(s) captured ===" % _captured)
		quit(0)
		return true
	_aim(_idx)
	_frame = 0
	return false


func _report(path: String, img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var lum_min := 1.0
	var lum_max := 0.0
	var lum_sum := 0.0
	var lum_sq := 0.0
	var samples := 0
	var bins: Array[int] = []
	for _b: int in 10:
		bins.append(0)
	var uniq: Dictionary = {}
	# 4x4 cell means for partial-overlay / half-half detection.
	var cell_sum: Array[float] = []
	var cell_n: Array[int] = []
	for _c: int in 16:
		cell_sum.append(0.0)
		cell_n.append(0)
	# intentional: integer sampling step in whole pixels.
	@warning_ignore("integer_division")
	var step := maxi(1, w / 128)
	for y: int in range(0, h, step):
		for x: int in range(0, w, step):
			var px := img.get_pixel(x, y)
			var l := px.get_luminance()
			lum_min = minf(lum_min, l)
			lum_max = maxf(lum_max, l)
			lum_sum += l
			lum_sq += l * l
			samples += 1
			var bi := clampi(int(l * 10.0), 0, 9)
			bins[bi] = bins[bi] + 1
			var key := "%d_%d_%d" % [int(px.r * 16), int(px.g * 16), int(px.b * 16)]
			uniq[key] = true
			# intentional: integer cell index in 4x4 grid.
			@warning_ignore("integer_division")
			var cx := mini(3, (x * 4) / w)
			# intentional: integer cell index in 4x4 grid.
			@warning_ignore("integer_division")
			var cy := mini(3, (y * 4) / h)
			var ci := cy * 4 + cx
			cell_sum[ci] = cell_sum[ci] + l
			cell_n[ci] = cell_n[ci] + 1
	var mean := lum_sum / float(samples)
	var variance := (lum_sq / float(samples)) - (mean * mean)
	var stdev := sqrt(maxf(0.0, variance))
	var entropy := 0.0
	for b: int in bins:
		if b > 0:
			var p := float(b) / float(samples)
			entropy -= p * (log(p) / log(2.0))
	var cmin := 1.0
	var cmax := 0.0
	for ci: int in 16:
		if cell_n[ci] > 0:
			var cm := cell_sum[ci] / float(cell_n[ci])
			cmin = minf(cmin, cm)
			cmax = maxf(cmax, cm)
	var cell_spread := cmax - cmin
	print(
		(
			(
				"METRICS %s: mean=%.3f stdev=%.3f entropy=%.2f unique=%d cell_spread=%.3f"
				+ " lum=[%.3f,%.3f] samples=%d"
			)
			% [path, mean, stdev, entropy, uniq.size(), cell_spread, lum_min, lum_max, samples]
		)
	)
