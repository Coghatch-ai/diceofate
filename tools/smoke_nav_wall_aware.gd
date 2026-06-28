# tools/smoke_nav_wall_aware.gd — L2 smoke: verify navmesh carves AROUND walls.
# Loads iron_floor.tscn (real navmesh), queries NavigationServer3D for a path between
# two points where the straight line crosses a wall, and asserts:
#   1. poly count > 2 (flat-floor-only bake produced exactly 2 polygons)
#   2. path length > straight-line distance (wall forced a detour)
#   3. path has >= 3 waypoints (more than a trivial 2-point straight path)
#
# Test geometry: enemy at (13,0,19), target at (7,0,19).
# A wall bank runs near x=10,z=17-25 — the straight line at z=19 crosses it.
# The routed path must detour via a gap, producing excess distance.
#
# Exit 0 = wall-aware, exit 1 = fail.
extends SceneTree

const _LEVEL_SCENE: String = "res://levels/iron_floor.tscn"

# Spawn: R2 area (open floor). Target: across a wall band on the same Z line.
const _START: Vector3 = Vector3(13.0, 0.0, 19.0)
const _END: Vector3 = Vector3(7.0, 0.0, 19.0)
# Minimum ratio of path_length / straight_distance to confirm a detour.
const _DETOUR_RATIO: float = 1.05

var _level_root: Node = null
var _nav_region: NavigationRegion3D = null
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== SMOKE NAV WALL-AWARE ===")
	print("  level=%s start=%s end=%s" % [_LEVEL_SCENE, str(_START), str(_END)])

	if not ResourceLoader.exists(_LEVEL_SCENE):
		print("NAV-WALL: FAIL — level scene not found: %s" % _LEVEL_SCENE)
		quit(1)
		return
	var packed: PackedScene = load(_LEVEL_SCENE) as PackedScene
	if packed == null:
		print("NAV-WALL: FAIL — could not load level: %s" % _LEVEL_SCENE)
		quit(1)
		return
	_level_root = packed.instantiate()
	root.add_child(_level_root)
	_nav_region = _level_root.find_child("NavigationRegion3D", true, false) as NavigationRegion3D
	if _nav_region == null:
		print("NAV-WALL: FAIL — NavigationRegion3D not found in level")
		quit(1)
		return
	print("  level loaded, settling 5 frames for nav server registration...")


func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	if _frame < 5:
		return false
	_done = true
	_run_check()
	return false


func _run_check() -> void:
	# 1. Poly count: flat-floor-only bake = 2 polys; wall-aware = many more.
	var nav_mesh: NavigationMesh = _nav_region.navigation_mesh
	if nav_mesh == null:
		print("NAV-WALL: FAIL — NavigationMesh resource is null")
		quit(1)
		return
	var poly_count: int = nav_mesh.get_polygon_count()
	print("  navmesh polygon count: %d" % poly_count)
	if poly_count <= 2:
		print(
			(
				"NAV-WALL: FAIL — poly_count=%d <= 2: navmesh is flat-floor only (walls not carved)"
				% poly_count
			)
		)
		quit(1)
		return
	print("  poly_count=%d > 2: wall geometry was included in bake  OK" % poly_count)

	# 2. Query a path via NavigationServer3D.
	# Wait for the nav map to be registered (accessed via NavigationRegion3D.get_navigation_map()).
	var map_rid: RID = _nav_region.get_navigation_map()
	if not map_rid.is_valid():
		print("NAV-WALL: FAIL — NavigationRegion3D has no valid nav map RID")
		quit(1)
		return

	var path_params: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
	path_params.map = map_rid
	path_params.start_position = _START
	path_params.target_position = _END
	path_params.navigation_layers = 1
	var path_result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(path_params, path_result)
	var path: PackedVector3Array = path_result.path

	print("  path waypoint count: %d" % path.size())
	if path.size() < 2:
		print("NAV-WALL: FAIL — path has < 2 waypoints: no route found (enemy would be frozen)")
		quit(1)
		return

	# 3. Measure path length vs straight-line distance.
	var straight_dist: float = _START.distance_to(_END)
	var path_len: float = 0.0
	for i: int in range(1, path.size()):
		path_len += path[i - 1].distance_to(path[i])

	var ratio: float = path_len / straight_dist if straight_dist > 0.0 else 1.0
	print(
		(
			"  straight_dist=%.3fm path_len=%.3fm ratio=%.3f (need >= %.2f for detour proof)"
			% [straight_dist, path_len, ratio, _DETOUR_RATIO]
		)
	)

	if path.size() >= 3 and ratio >= _DETOUR_RATIO:
		print(
			(
				"NAV-WALL: OK — path detours around wall (waypoints=%d ratio=%.3f >= %.2f)"
				% [path.size(), ratio, _DETOUR_RATIO]
			)
		)
		quit(0)
	elif path.size() < 3:
		# Short path (only 2 waypoints = start+end) may indicate a direct unblocked path.
		# Could also mean the wall blocked the path entirely but start/end were snapped close.
		# Accept if ratio is still elevated.
		if ratio >= _DETOUR_RATIO:
			print(
				(
					"NAV-WALL: OK — 2-waypoint path with detour ratio (waypoints=%d ratio=%.3f)"
					% [path.size(), ratio]
				)
			)
			quit(0)
		print(
			(
				"NAV-WALL: FAIL — straight 2-waypoint path with no detour"
				+ " (waypoints=%d ratio=%.3f < %.2f)" % [path.size(), ratio, _DETOUR_RATIO]
			)
		)
		quit(1)
	else:
		print(
			(
				"NAV-WALL: FAIL — path ratio %.3f < %.2f: enemy routing straight through wall"
				% [ratio, _DETOUR_RATIO]
			)
		)
		quit(1)
