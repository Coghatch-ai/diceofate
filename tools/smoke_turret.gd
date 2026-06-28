# tools/smoke_turret.gd — L2 headless smoke: TurretController rotate-to-aim + fire-gate seam.
# Asserts:
#   1. acquire() returns nearest in-range visible enemy in ANY direction (360°, no rear cone).
#   2. acquire() rejects enemy beyond max_range.
#   3. acquire() returns nearest when multiple enemies at different distances.
#   4. pivot ROTATES toward target over successive frames (angle-to-target decreases, not instant).
#   5. NO fire on frame 1 when target starts 90°+ off pivot forward (fire-when-aligned gate).
#   6. Fire DOES happen once pivot is manually snapped to aligned (_run_cycle path).
#   7. _run_cycle() no-ops (no fire) when no target in group.
#   8. Mount hierarchy correct: TurretViewModel under TurretPivot so Muzzle rotates with aim.
# Run: $GODOT --headless --path . --script tools/smoke_turret.gd
# Exit 0 = all pass, 1 = any failure. No render/draw-call asserts.
extends SceneTree

const TURRET_SCENE := "res://entities/weapon/shoulder_turret.tscn"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== TURRET SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_acquire_any_direction()
	_test_acquire_rejects_out_of_range()
	_test_acquire_nearest_of_multiple()
	_test_pivot_rotates_not_instant()
	_test_no_fire_when_misaligned()
	_test_fire_when_aligned()
	_test_noop_no_target()
	_test_mount_hierarchy()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


## Stub enemy Node3D in "enemies" group.
func _make_enemy(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.global_position = pos
	n.add_to_group("enemies")
	return n


## Build TargetAcquisitionConfig with LOS disabled (no geometry in headless scene).
func _make_cfg(half_angle: float, max_range_val: float) -> TargetAcquisitionConfig:
	var cfg := TargetAcquisitionConfig.new()
	cfg.target_group = "enemies"
	cfg.arc_half_angle_deg = half_angle
	cfg.max_range = max_range_val
	cfg.los_required = false
	cfg.selection_rule = TargetAcquisitionConfig.SelectionRule.NEAREST
	return cfg


## Load, instantiate and wire turret. Returns [turret, ctrl] or [] on failure.
func _make_turret() -> Array:
	var packed := load(TURRET_SCENE) as PackedScene
	if packed == null:
		_fail("shoulder_turret.tscn failed to load")
		return []
	var turret := packed.instantiate() as Gun
	if turret == null:
		_fail("shoulder_turret root is not a Gun node")
		return []
	root.add_child(turret)
	turret.projectile_scene = null
	var ctrl := turret.get_node_or_null(^"TurretController") as TurretController
	if ctrl == null:
		_fail("TurretController not found in shoulder_turret.tscn")
		turret.queue_free()
		return []
	ctrl.gun = turret
	ctrl.turret_muzzle = turret.get_node_or_null(^"TurretPivot/TurretViewModel/Muzzle") as Marker3D
	ctrl.turret_pivot = turret.get_node_or_null(^"TurretPivot") as Node3D
	return [turret, ctrl]


# ---------------------------------------------------------------------------
# 1. 360° acquisition — enemy in FRONT (not rear) must be acquired.
# ---------------------------------------------------------------------------
func _test_acquire_any_direction() -> void:
	print("\n[TEST 1] acquire() returns enemy in front (non-rear direction), 180° half-angle")
	var origin := Node3D.new()
	root.add_child(origin)
	origin.global_position = Vector3.ZERO
	origin.rotation_degrees = Vector3(0.0, 0.0, 0.0)  # forward = -Z
	# Enemy directly in front (-Z) — old rear-only cone would reject this.
	var enemy := _make_enemy(Vector3(0.0, 0.0, -5.0))
	var result: Node3D = TargetAcquisitionConfig.acquire(origin, _make_cfg(180.0, 30.0))
	_assert(result == enemy, "acquire() returns enemy in front with 180° half-angle")
	origin.free()
	enemy.free()


# ---------------------------------------------------------------------------
# 2. Beyond max_range → null.
# ---------------------------------------------------------------------------
func _test_acquire_rejects_out_of_range() -> void:
	print("\n[TEST 2] acquire() rejects enemy beyond max_range")
	var origin := Node3D.new()
	root.add_child(origin)
	origin.global_position = Vector3.ZERO
	var enemy := _make_enemy(Vector3(0.0, 0.0, -50.0))
	var result: Node3D = TargetAcquisitionConfig.acquire(origin, _make_cfg(180.0, 30.0))
	_assert(result == null, "acquire() returns null for out-of-range enemy")
	origin.free()
	enemy.free()


# ---------------------------------------------------------------------------
# 3. Nearest of multiple enemies returned.
# ---------------------------------------------------------------------------
func _test_acquire_nearest_of_multiple() -> void:
	print("\n[TEST 3] acquire() returns nearest of multiple enemies")
	var origin := Node3D.new()
	root.add_child(origin)
	origin.global_position = Vector3.ZERO
	var near := _make_enemy(Vector3(3.0, 0.0, 0.0))
	var far := _make_enemy(Vector3(10.0, 0.0, 0.0))
	var result: Node3D = TargetAcquisitionConfig.acquire(origin, _make_cfg(180.0, 30.0))
	_assert(result == near, "acquire() returns nearest enemy (3m vs 10m)")
	origin.free()
	near.free()
	far.free()


# ---------------------------------------------------------------------------
# 4. Pivot ROTATES toward target over frames — angle decreases, not instant snap.
# ---------------------------------------------------------------------------
func _test_pivot_rotates_not_instant() -> void:
	print("\n[TEST 4] pivot rotates toward target over successive frames (angle decreases)")
	var nodes := _make_turret()
	if nodes.is_empty():
		return
	var turret: Gun = nodes[0]
	var ctrl: TurretController = nodes[1]

	# Place enemy 90° off pivot's initial forward (pivot faces -Z, enemy at +X).
	var enemy := _make_enemy(Vector3(10.0, 0.0, 0.0))
	turret.global_position = Vector3.ZERO

	# Pivot starts facing -Z (default).
	var pivot: Node3D = ctrl.turret_pivot
	if pivot == null:
		_fail("turret_pivot is null — cannot test rotation")
		enemy.free()
		turret.queue_free()
		return

	# Force-acquire target so ctrl knows about it.
	ctrl._current_target = enemy

	var forward_before: Vector3 = -pivot.global_transform.basis.z
	var dir_to_target: Vector3 = (enemy.global_position - pivot.global_position).normalized()
	var angle_before: float = rad_to_deg(forward_before.angle_to(dir_to_target))

	# Run one physics tick at delta=0.1 — with turn_rate=180°/s, max rotation=18°.
	# A 90° gap should NOT be closed instantly.
	ctrl._physics_process(0.1)

	var forward_after: Vector3 = -pivot.global_transform.basis.z
	var angle_after: float = rad_to_deg(forward_after.angle_to(dir_to_target))

	_assert(
		angle_after < angle_before,
		(
			"angle-to-target decreased after one physics tick (%.1f° -> %.1f°)"
			% [angle_before, angle_after]
		)
	)
	_assert(
		angle_after > 0.5,
		"pivot did NOT snap instantly to target in one tick (angle_after=%.1f°)" % angle_after
	)

	enemy.free()
	if is_instance_valid(turret):
		turret.queue_free()


# ---------------------------------------------------------------------------
# 5. NO fire when misaligned (90°+ off) — fire-gate holds on frame 1.
# ---------------------------------------------------------------------------
func _test_no_fire_when_misaligned() -> void:
	print("\n[TEST 5] NO fire when pivot is 90°+ off target forward (fire-gate)")
	var nodes := _make_turret()
	if nodes.is_empty():
		return
	var turret: Gun = nodes[0]
	var ctrl: TurretController = nodes[1]

	# Enemy at +X, pivot facing -Z → ~90° misaligned.
	var enemy := _make_enemy(Vector3(10.0, 0.0, 0.0))
	turret.global_position = Vector3.ZERO
	ctrl._current_target = enemy
	ctrl._fire_timer = 0.0  # cooldown cleared so only alignment gate blocks

	var fire_count: Array[int] = [0]
	ctrl.turret_fired.connect(func() -> void: fire_count[0] += 1)

	# One tick — rotation partial, still misaligned beyond tolerance, must NOT fire.
	ctrl._physics_process(0.016)

	_assert(fire_count[0] == 0, "turret did NOT fire on first tick when 90° misaligned")

	enemy.free()
	if is_instance_valid(turret):
		turret.queue_free()


# ---------------------------------------------------------------------------
# 6. Fire DOES happen when aligned (_run_cycle snaps pivot then fires).
# ---------------------------------------------------------------------------
func _test_fire_when_aligned() -> void:
	print("\n[TEST 6] fire happens when pivot is aligned (_run_cycle snap path)")
	var nodes := _make_turret()
	if nodes.is_empty():
		return
	var turret: Gun = nodes[0]
	var ctrl: TurretController = nodes[1]

	var enemy := _make_enemy(Vector3(0.0, 0.0, 5.0))
	turret.global_position = Vector3.ZERO

	var fire_count: Array[int] = [0]
	ctrl.turret_fired.connect(func() -> void: fire_count[0] += 1)

	ctrl._fire_timer = 0.0  # cooldown clear

	if not ctrl.has_method("_run_cycle"):
		_fail("TurretController missing _run_cycle seam")
		enemy.free()
		turret.queue_free()
		return

	@warning_ignore("unsafe_method_access")
	ctrl._run_cycle()

	_assert(fire_count[0] == 1, "turret_fired emitted once after _run_cycle() with aligned target")

	enemy.free()
	if is_instance_valid(turret):
		turret.queue_free()


# ---------------------------------------------------------------------------
# 7. _run_cycle() no-ops when no enemies in group.
# ---------------------------------------------------------------------------
func _test_noop_no_target() -> void:
	print("\n[TEST 7] _run_cycle() no-ops when no enemies in group")
	var nodes := _make_turret()
	if nodes.is_empty():
		return
	var turret: Gun = nodes[0]
	var ctrl: TurretController = nodes[1]

	var fire_count: Array[int] = [0]
	ctrl.turret_fired.connect(func() -> void: fire_count[0] += 1)
	ctrl._fire_timer = 0.0

	if not ctrl.has_method("_run_cycle"):
		_fail("TurretController missing _run_cycle seam")
		turret.queue_free()
		return

	@warning_ignore("unsafe_method_access")
	ctrl._run_cycle()

	_assert(fire_count[0] == 0, "turret_fired NOT emitted when no target acquired")

	if is_instance_valid(turret):
		turret.queue_free()


# ---------------------------------------------------------------------------
# 8. Mount hierarchy: TurretViewModel is under TurretPivot so Muzzle rotates with aim.
#    Muzzle must be reachable at TurretPivot/TurretViewModel/Muzzle.
# ---------------------------------------------------------------------------
func _test_mount_hierarchy() -> void:
	print(
		"\n[TEST 8] mount hierarchy: TurretViewModel child of TurretPivot, Muzzle rotates with aim"
	)
	var packed := load(TURRET_SCENE) as PackedScene
	if packed == null:
		_fail("shoulder_turret.tscn failed to load")
		return
	var turret := packed.instantiate() as Gun
	if turret == null:
		_fail("shoulder_turret root is not Gun")
		return
	root.add_child(turret)

	var pivot: Node3D = turret.get_node_or_null(^"TurretPivot") as Node3D
	_assert(pivot != null, "TurretPivot exists as direct child of ShoulderTurret")

	var view_model: Node3D = turret.get_node_or_null(^"TurretPivot/TurretViewModel") as Node3D
	_assert(view_model != null, "TurretViewModel is child of TurretPivot (rotates with aim)")

	var muzzle: Marker3D = (
		turret.get_node_or_null(^"TurretPivot/TurretViewModel/Muzzle") as Marker3D
	)
	_assert(muzzle != null, "Muzzle reachable at TurretPivot/TurretViewModel/Muzzle")

	# TurretViewModel must NOT be a direct child of ShoulderTurret root (old broken layout).
	var vm_at_root: Node3D = turret.get_node_or_null(^"TurretViewModel") as Node3D
	_assert(
		vm_at_root == null,
		"TurretViewModel is NOT a direct child of ShoulderTurret (would break aim tracking)"
	)

	turret.queue_free()


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass(msg)
	else:
		_fail(msg)


func _pass(msg: String) -> void:
	_pass_count += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	print("  FAIL: %s" % msg)
