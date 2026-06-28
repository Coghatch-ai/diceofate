# tools/smoke_radar_minimap.gd — L2 headless smoke: blip-projection math for RadarMinimap.
# Asserts correct XY offset for known enemy positions including one directly behind the player.
extends SceneTree

const EPSILON: float = 0.5  # pixel tolerance

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run()
	if _fail == 0:
		print("smoke_radar_minimap: PASS=%d FAIL=0" % _pass)
	else:
		push_error("smoke_radar_minimap: PASS=%d FAIL=%d" % [_pass, _fail])
	quit()


func _run() -> void:
	print("=== RADAR MINIMAP PROJECTION SMOKE ===")

	var config: MinimapConfig = load("res://entities/hud/minimap_config_default.tres")
	_assert(config != null, "config loads")

	# Build a RadarMinimap instance (no scene tree needed — we call _world_to_radar directly).
	var radar: RadarMinimap = RadarMinimap.new()
	radar.config = config

	var radar_radius: float = config.radar_size * 0.5  # 80 px

	# ── Test 1: enemy directly in front (−Z from player facing −Z, yaw=0)
	# Player at origin facing -Z (yaw=0). Enemy 10 m ahead at (0,0,-10).
	# Expected: blip at (0, -px) i.e. up on screen (negative Y).
	var blip1: Vector2 = radar._world_to_radar(
		Vector3(0.0, 0.0, -10.0), Vector3.ZERO, 0.0, radar_radius
	)
	_assert(blip1.x < EPSILON and blip1.x > -EPSILON, "front enemy: x≈0 (got %.2f)" % blip1.x)
	_assert(blip1.y < -1.0, "front enemy: y<0 = up on screen (got %.2f)" % blip1.y)

	# ── Test 2: enemy directly behind (at +Z, yaw=0) → blip at bottom (positive Y)
	var blip2: Vector2 = radar._world_to_radar(
		Vector3(0.0, 0.0, 10.0), Vector3.ZERO, 0.0, radar_radius
	)
	_assert(blip2.x < EPSILON and blip2.x > -EPSILON, "behind enemy: x≈0 (got %.2f)" % blip2.x)
	_assert(blip2.y > 1.0, "behind enemy: y>0 = bottom of radar (got %.2f)" % blip2.y)

	# ── Test 3: enemy to the right (+X) from player facing -Z (yaw=0) → blip right (+X)
	var blip3: Vector2 = radar._world_to_radar(
		Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 0.0, radar_radius
	)
	_assert(blip3.x > 1.0, "right enemy: x>0 (got %.2f)" % blip3.x)
	_assert(blip3.y < EPSILON and blip3.y > -EPSILON, "right enemy: y≈0 (got %.2f)" % blip3.y)

	# ── Test 4: enemy 10 m behind, player yaw=PI (facing +Z)
	# Enemy at (0,0,10), player facing +Z (yaw=PI).
	# After rotation enemy is in FRONT so blip should be at top (negative Y).
	var blip4: Vector2 = radar._world_to_radar(
		Vector3(0.0, 0.0, 10.0), Vector3.ZERO, PI, radar_radius
	)
	_assert(blip4.y < -1.0, "yaw=PI: enemy now in front → blip top (got %.2f)" % blip4.y)

	# ── Test 5: enemy beyond detection_range with clamp_to_edge=true → clamped to ring
	# Enemy 200 m away, range=40 m, radar_radius=80 px.
	var blip5: Vector2 = radar._world_to_radar(
		Vector3(0.0, 0.0, -200.0), Vector3.ZERO, 0.0, radar_radius
	)
	var dist5: float = blip5.length()
	_assert(
		dist5 <= radar_radius + EPSILON,
		"clamp_to_edge: dist≤radar_radius (got %.2f, max %.2f)" % [dist5, radar_radius]
	)
	_assert(
		dist5 > radar_radius - EPSILON - 1.0, "clamp_to_edge: dist≈radar_radius (got %.2f)" % dist5
	)

	# ── Test 6: clamp_to_edge=false → sentinel Vector2.ZERO returned for out-of-range
	config.clamp_to_edge = false
	var blip6: Vector2 = radar._world_to_radar(
		Vector3(0.0, 0.0, -200.0), Vector3.ZERO, 0.0, radar_radius
	)
	_assert(blip6 == Vector2.ZERO, "no-clamp: out-of-range returns Vector2.ZERO (got %s)" % blip6)
	config.clamp_to_edge = true  # restore

	print("=== RESULTS: %d pass / %d fail ===" % [_pass, _fail])


func _assert(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
		print("  PASS: %s" % label)
	else:
		_fail += 1
		push_error("  FAIL: %s" % label)
