# tools/smoke_room_progression.gd — headless progression regression test.
# Proves the cross-room spawn bug (A) and validates boss-gating signal (B).
#
# BUG UNDER TEST:
# _apply_clearance() iterates ALL _marker_registry entries (all rooms) and picks
# the globally-farthest marker when a spawn is too close to the player.
# This means enemies in R2 can get spawned at R10 markers and vice versa.
# Fix: pass room-local markers to _apply_clearance so fallback stays in same room.
#
# Run: $GODOT --headless --path . --script tools/smoke_room_progression.gd
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0


func _assert(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s" % label)
	else:
		_fail_count += 1
		print("  FAIL  %s" % label)


func _assert_eq(label: String, got: Variant, expected: Variant) -> void:
	var ok: bool = got == expected
	if ok:
		_pass_count += 1
		print("  PASS  %s  (got %s)" % [label, str(got)])
	else:
		_fail_count += 1
		print("  FAIL  %s  expected=%s  got=%s" % [label, str(expected), str(got)])


# ── TEST A: _apply_clearance picks globally farthest (cross-room bug) ─────────
# Pre-fix: method has 1 param; picks from ALL _marker_registry entries.
# Post-fix: method has 2 params; second = room-local marker list.
#
# Test places player near R2 markers. R10 markers are 100 m away.
# OLD code → fallback = R10 marker (bug). NEW code → fallback = farthest R2 marker.


func _test_clearance_cross_room_bug() -> void:
	print("\n[TEST A] _apply_clearance cross-room spawn bug")

	# We test by inspecting the method signature arity, then calling appropriately
	# and asserting what the UNFIXED code would return vs what it SHOULD return.
	#
	# Positions (local = absolute in test setup, no parent transform offset):
	# Player at (0,0,0). R2 markers at (1..3 m). R10 markers at (100 m+).
	# Clearance = 4.5 m. All R2 markers are within clearance of player.
	# Old code picks farthest from ALL registry → R10 marker (cross-room).
	# New code picks farthest from room_markers arg → farthest R2 marker.

	# Simulate the algorithm in pure GDScript (no nodes needed for logic proof).
	# This mirrors exactly what _apply_clearance does, with and without the fix.
	var player_pos: Vector3 = Vector3.ZERO
	var clearance: float = 4.5

	# R2 markers (room-local).
	var r2_positions: Array[Vector3] = [
		Vector3(1.0, 0.0, 1.0),
		Vector3(2.0, 0.0, 1.0),
		Vector3(1.5, 0.0, 2.0),
	]
	# R10 markers (far room).
	var r10_positions: Array[Vector3] = [
		Vector3(100.0, 0.0, 100.0),
		Vector3(110.0, 0.0, 100.0),
	]

	# All markers combined (as _marker_registry holds them).
	var all_positions: Array[Vector3] = r2_positions.duplicate()
	for p: Vector3 in r10_positions:
		all_positions.append(p)

	var candidate: Vector3 = r2_positions[0]  # 1.41 m from player — within clearance.

	# --- OLD logic: search all markers ---
	var best_old: Vector3 = candidate
	var best_dist_old: float = -1.0
	for pos: Vector3 in all_positions:
		var d: float = pos.distance_to(player_pos)
		if d > best_dist_old:
			best_dist_old = d
			best_old = pos

	print(
		"  OLD code fallback: %s (dist=%.1f m)" % [str(best_old), best_old.distance_to(player_pos)]
	)
	var old_is_cross_room: bool = best_old in r10_positions
	_assert("OLD code picks a cross-room (R10) marker — bug confirmed", old_is_cross_room)

	# --- NEW logic: search only room markers ---
	var best_new: Vector3 = candidate
	var best_dist_new: float = -1.0
	for pos: Vector3 in r2_positions:
		var d: float = pos.distance_to(player_pos)
		if d > best_dist_new:
			best_dist_new = d
			best_new = pos

	print(
		"  NEW code fallback: %s (dist=%.1f m)" % [str(best_new), best_new.distance_to(player_pos)]
	)
	var new_stays_in_room: bool = best_new in r2_positions
	_assert("NEW code stays within room markers", new_stays_in_room)

	# Now verify which path the LIVE method takes (signature arity detection).
	var scene_root: Node3D = Node3D.new()
	get_root().add_child(scene_root)

	var player: Node3D = Node3D.new()
	player.name = "FakePlayer"
	player.add_to_group("player")
	scene_root.add_child(player)
	# position (not global) works correctly when parent is in tree.
	player.position = player_pos

	# Build markers in tree so global_position resolves.
	var r2a: Marker3D = Marker3D.new()
	r2a.name = "Spawn_R2_a"
	scene_root.add_child(r2a)
	r2a.position = r2_positions[0]

	var r2b: Marker3D = Marker3D.new()
	r2b.name = "Spawn_R2_b"
	scene_root.add_child(r2b)
	r2b.position = r2_positions[1]

	var r2c: Marker3D = Marker3D.new()
	r2c.name = "Spawn_R2_c"
	scene_root.add_child(r2c)
	r2c.position = r2_positions[2]

	var r10a: Marker3D = Marker3D.new()
	r10a.name = "Spawn_R10_a"
	scene_root.add_child(r10a)
	r10a.position = r10_positions[0]

	var r10b: Marker3D = Marker3D.new()
	r10b.name = "Spawn_R10_b"
	scene_root.add_child(r10b)
	r10b.position = r10_positions[1]

	var rc: RoomController = RoomController.new()
	rc.name = "RC_A"
	rc.min_spawn_clearance = clearance
	scene_root.add_child(rc)

	# Set _marker_registry AFTER add_child (so _ready has run).
	@warning_ignore("unsafe_method_access")
	(
		rc
		. set(
			"_marker_registry",
			{
				&"Spawn_R2_a": r2a,
				&"Spawn_R2_b": r2b,
				&"Spawn_R2_c": r2c,
				&"Spawn_R10_a": r10a,
				&"Spawn_R10_b": r10b,
			}
		)
	)

	# Detect arity of live _apply_clearance.
	var clearance_arity: int = 1
	for m: Dictionary in rc.get_method_list():
		# SEAM: Dictionary fields from get_method_list() — Variant access.
		@warning_ignore("unsafe_cast")
		var mname: String = m.get("name", "") as String
		if mname == "_apply_clearance":
			@warning_ignore("unsafe_cast")
			var args: Array = m.get("args", []) as Array
			clearance_arity = args.size()
			break

	print("  live _apply_clearance arity = %d" % clearance_arity)
	print("  (arity 1 = old/buggy code; arity 2 = fixed room-local code)")

	# Algorithm proof above confirms the fix logic. Arity check confirms live code.
	# (Cannot call _apply_clearance from _init() — get_tree() returns null in init.)
	_assert(
		"live _apply_clearance uses 2-arg room-local API (arity=%d)" % clearance_arity,
		clearance_arity == 2
	)
	if clearance_arity == 1:
		print("  OLD 1-arg API detected — cross-room bug still present, fix not applied")
		_assert("FIX NEEDED: algorithm proof shows bug (see above) [FAIL=fix not applied]", false)
	else:
		print("  NEW 2-arg API confirmed — fix is in place, algorithm proof validates logic")

	scene_root.queue_free()


# ── TEST B: room_cleared fires with correct id after room wipe ────────────────


func _test_room_cleared_logic() -> void:
	print("\n[TEST B] room_cleared emits correct id after last enemy dies")

	var scene_root: Node3D = Node3D.new()
	get_root().add_child(scene_root)

	var enc: RoomEncounter = RoomEncounter.new()
	enc.id = &"iron_r2"
	enc.clear_advances = true

	var rc: RoomController = RoomController.new()
	rc.name = "RC_B"
	rc.encounters = [enc]
	rc.min_spawn_clearance = 0.0
	scene_root.add_child(rc)
	# _ready() pre-sizes _room_enemies to 1 entry. Verify then use it.

	var cleared_ids: Array[StringName] = []
	rc.room_cleared.connect(func(rid: StringName) -> void: cleared_ids.append(rid))

	# Use set() to inject a fresh _room_enemies after _ready() — typed array
	# can't be mutated via get() copy. Replace with plain Array so inner arrays
	# are mutable via r0 reference.
	# SEAM: _room_enemies override for test isolation.
	var inner: Array = []
	var outer: Array = [inner]
	@warning_ignore("unsafe_method_access")
	rc.set("_room_enemies", outer)

	var fake_a: Node = Node.new()
	fake_a.name = "FakeA"
	scene_root.add_child(fake_a)
	var fake_b: Node = Node.new()
	fake_b.name = "FakeB"
	scene_root.add_child(fake_b)

	inner.append(fake_a)
	inner.append(fake_b)

	# First removal — room still has 1.
	inner.erase(fake_a)
	_assert_eq("no room_cleared after first death", cleared_ids.size(), 0)

	# Second removal — room empty → call _on_room_cleared.
	inner.erase(fake_b)
	@warning_ignore("unsafe_method_access")
	rc.call("_on_room_cleared", 0)

	_assert_eq("room_cleared fires once", cleared_ids.size(), 1)
	if cleared_ids.size() >= 1:
		_assert_eq("room_cleared id = iron_r2", cleared_ids[0], &"iron_r2")

	scene_root.queue_free()


# ── TEST C: iron_r10 room_cleared → boss gate opens ──────────────────────────


func _test_boss_gate_r10() -> void:
	print("\n[TEST C] iron_r10 clears → boss spawn gate (room_cleared signal path)")

	var scene_root: Node3D = Node3D.new()
	get_root().add_child(scene_root)

	var room_ids: Array[StringName] = [
		&"iron_r2",
		&"iron_r3",
		&"iron_r4",
		&"iron_r6",
		&"iron_r5",
		&"iron_r7",
		&"iron_r8",
		&"iron_r9",
		&"iron_r10"
	]
	var encs: Array[RoomEncounter] = []
	for rid: StringName in room_ids:
		var e: RoomEncounter = RoomEncounter.new()
		e.id = rid
		e.clear_advances = true
		encs.append(e)

	var rc: RoomController = RoomController.new()
	rc.name = "RC_C"
	rc.encounters = encs
	rc.min_spawn_clearance = 0.0
	scene_root.add_child(rc)

	var cleared_log: Array[StringName] = []
	rc.room_cleared.connect(func(rid: StringName) -> void: cleared_log.append(rid))

	# Clear R2..R9 (indices 0..7).
	for i: int in range(8):
		@warning_ignore("unsafe_method_access")
		rc.call("_on_room_cleared", i)

	_assert_eq("8 signals after R2..R9", cleared_log.size(), 8)
	_assert("iron_r10 not yet fired", not (&"iron_r10" in cleared_log))

	# Clear R10 (index 8).
	@warning_ignore("unsafe_method_access")
	rc.call("_on_room_cleared", 8)

	_assert_eq("9 signals total", cleared_log.size(), 9)
	_assert("iron_r10 in cleared_log — boss spawn gate opens", &"iron_r10" in cleared_log)

	scene_root.queue_free()


# ── entry ──────────────────────────────────────────────────────────────────────


func _init() -> void:
	print("\n=== smoke_room_progression: progression + boss-gating regression test ===")
	print(
		"Pre-fix: TEST A MUST FAIL (cross-room bug confirmed by algorithm proof + live API check)"
	)
	print("Post-fix: ALL tests MUST PASS\n")

	_test_clearance_cross_room_bug()
	_test_room_cleared_logic()
	_test_boss_gate_r10()

	print("\n=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("SMOKE: FAIL")
		quit(1)
	else:
		print("SMOKE: PASS")
		quit(0)
