# tools/smoke_blast_court_wave.gd — headless smoke: Blast Court WaveManager wiring.
# Asserts:
#   1. SpawnMarker0..23 exist, are Marker3D, lie on the perimeter ring, are unique positions.
#   2. WaveManager.spawn_marker_paths count == 24.
#   3. EnemyWP0..2 exist and are Marker3D; patrol_waypoint_paths count == 3.
#   4. WaveManager.spawn_pos matches the documented player spawn (25.5, 1, 25.5).
# Score-increment assert skipped: enemy.gd broken by concurrent build (burn VFX seam
# incomplete) — Enemy class fails to resolve, so _on_enemy_died stub is unrunnable headlessly.
# Exit 0 = pass. Exit 1 = fail.
extends SceneTree


func _init() -> void:
	_run()
	quit(0)


func _run() -> void:
	# ── 1. Load scene ────────────────────────────────────────────────────────────
	var packed := load("res://levels/blast_court.tscn") as PackedScene
	_assert(packed != null, "failed to load blast_court.tscn")
	var scene_root: Node = packed.instantiate()
	_assert(scene_root != null, "failed to instantiate blast_court.tscn")

	# ── 2. WaveManager present + path arrays sized correctly ─────────────────────
	var wm: WaveManager = scene_root.get_node_or_null("WaveManager") as WaveManager
	_assert(wm != null, "WaveManager node not found under BlastCourt")
	_assert(
		wm.spawn_marker_paths.size() == 24,
		"expected 24 spawn_marker_paths, got %d" % wm.spawn_marker_paths.size()
	)
	_assert(
		wm.patrol_waypoint_paths.size() == 3,
		"expected 3 patrol_waypoint_paths, got %d" % wm.patrol_waypoint_paths.size()
	)

	# ── 3. Spawn markers exist, are Marker3D, on perimeter, unique ───────────────
	var positions: Array[Vector3] = []
	for i: int in range(24):
		var marker: Node = scene_root.get_node_or_null("SpawnMarker%d" % i)
		_assert(marker != null, "SpawnMarker%d not found" % i)
		var m3d: Marker3D = marker as Marker3D
		_assert(m3d != null, "SpawnMarker%d is not a Marker3D" % i)
		var pos: Vector3 = m3d.position
		var on_edge: bool = pos.x <= 3.0 or pos.x >= 69.0 or pos.z <= 3.0 or pos.z >= 45.0
		_assert(on_edge, "SpawnMarker%d pos %s not on perimeter edge" % [i, pos])
		_assert(not positions.has(pos), "SpawnMarker%d pos %s duplicates earlier marker" % [i, pos])
		positions.append(pos)

	# ── 4. Patrol waypoints exist and are Marker3D ───────────────────────────────
	for i: int in range(3):
		var wp: Node = scene_root.get_node_or_null("EnemyWP%d" % i)
		_assert(wp != null, "EnemyWP%d not found" % i)
		_assert(wp is Marker3D, "EnemyWP%d is not a Marker3D" % i)

	# ── 5. WaveManager spawn_pos matches documented player spawn ─────────────────
	var expected_spawn := Vector3(25.5, 1.0, 25.5)
	_assert(
		wm.spawn_pos.is_equal_approx(expected_spawn),
		"spawn_pos expected %s, got %s" % [expected_spawn, wm.spawn_pos]
	)

	scene_root.queue_free()
	print("smoke_blast_court_wave: PASS")


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		push_error("smoke_blast_court_wave: FAIL — %s" % msg)
		quit(1)
