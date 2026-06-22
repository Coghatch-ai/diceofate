# tools/smoke_bullet_ammo.gd — headless L2 smoke: Slice-3 per-bullet-type ammo.
# Asserts: ammo loads from CastData, firing consumes ammo, empty ammo blocks shot,
# regen refills over simulated time, per-type pools are independent.
# Run: $GODOT --headless --path . --script tools/smoke_bullet_ammo.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const PISTOL_CAST := "res://entities/weapon/pistol_cast.tres"
const HEAVY_CAST := "res://entities/weapon/heavy_cast.tres"
const STUN_CAST := "res://entities/weapon/stun_cast.tres"
const BLAST_CAST := "res://entities/weapon/blast_cast.tres"
const RAPID_CAST := "res://entities/weapon/rapid_cast.tres"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== SMOKE BULLET AMMO SLICE-3 ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_cast_data_ammo_fields()
	_test_tracker_init_pools()
	_test_consume_decrements()
	_test_empty_blocks_fire()
	_test_regen_refills()
	_test_per_type_pools_independent()
	_test_can_fire_unlimited_when_max_zero()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


# ── helpers ────────────────────────────────────────────────────────────────────


func _pass(label: String) -> void:
	print("  PASS  %s" % label)
	_pass_count += 1


func _fail(label: String) -> void:
	print("  FAIL  %s" % label)
	_fail_count += 1


func _assert(cond: bool, label: String) -> void:
	if cond:
		_pass(label)
	else:
		_fail(label)


func _make_tracker(cast_list: Array[CastData]) -> BulletAmmoTracker:
	var tracker := BulletAmmoTracker.new()
	tracker.casts = cast_list
	tracker.init_pools()
	root.add_child(tracker)
	return tracker


# ── tests ──────────────────────────────────────────────────────────────────────


## S3-01. All 5 CastData .tres have correct ammo fields.
func _test_cast_data_ammo_fields() -> void:
	print("\n[TEST] S3-01. CastData ammo fields correct on all 5 .tres")
	var paths: Array[String] = [PISTOL_CAST, HEAVY_CAST, STUN_CAST, BLAST_CAST, RAPID_CAST]
	var names: Array[String] = ["pistol", "heavy", "stun", "blast", "rapid"]
	var expected_max: Array[int] = [30, 8, 12, 5, 20]
	var expected_cost: Array[int] = [1, 1, 1, 1, 1]
	var expected_regen: Array[float] = [3.0, 0.5, 1.0, 0.4, 2.0]
	for i: int in range(paths.size()):
		var cast := load(paths[i]) as CastData
		if cast == null:
			_fail("S3-01: %s_cast.tres failed to load" % names[i])
			continue
		_assert(
			cast.max_ammo == expected_max[i],
			"S3-01: %s max_ammo == %d" % [names[i], expected_max[i]]
		)
		_assert(
			cast.ammo_cost == expected_cost[i],
			"S3-01: %s ammo_cost == %d" % [names[i], expected_cost[i]]
		)
		_assert(
			is_equal_approx(cast.ammo_regen, expected_regen[i]),
			"S3-01: %s ammo_regen ~= %.1f" % [names[i], expected_regen[i]]
		)


## S3-02. BulletAmmoTracker.init_pools sets all slots to max_ammo.
func _test_tracker_init_pools() -> void:
	print("\n[TEST] S3-02. init_pools seeds all slots at max_ammo")
	var pistol := load(PISTOL_CAST) as CastData
	var heavy := load(HEAVY_CAST) as CastData
	var cast_list: Array[CastData] = [pistol, heavy]
	var tracker := _make_tracker(cast_list)
	_assert(tracker.get_ammo(0) == 30, "S3-02: pistol slot starts at 30")
	_assert(tracker.get_ammo(1) == 8, "S3-02: heavy slot starts at 8")
	tracker.queue_free()


## S3-03. consume() decrements ammo by ammo_cost; can_fire() returns false when empty.
func _test_consume_decrements() -> void:
	print("\n[TEST] S3-03. consume decrements; can_fire false at 0")
	var blast := load(BLAST_CAST) as CastData
	var cast_list: Array[CastData] = [blast]
	var tracker := _make_tracker(cast_list)
	_assert(tracker.get_ammo(0) == 5, "S3-03: blast starts at 5")
	_assert(tracker.can_fire(0), "S3-03: can_fire true at 5")
	for _i: int in range(5):
		tracker.consume(0)
	_assert(tracker.get_ammo(0) == 0, "S3-03: blast at 0 after 5 consumes")
	_assert(not tracker.can_fire(0), "S3-03: can_fire false at 0")
	tracker.queue_free()


## S3-04. Empty ammo -> try_fire returns false (no projectile fired).
## Gun._ready needs scene children; test the ammo gate logic directly via tracker.
func _test_empty_blocks_fire() -> void:
	print("\n[TEST] S3-04. Empty ammo blocks fire (can_fire returns false)")
	var rapid := load(RAPID_CAST) as CastData
	var cast_list: Array[CastData] = [rapid]
	var tracker := _make_tracker(cast_list)
	# Drain all ammo.
	for _i: int in range(rapid.max_ammo):
		tracker.consume(0)
	_assert(tracker.get_ammo(0) == 0, "S3-04: rapid drained to 0")
	_assert(not tracker.can_fire(0), "S3-04: can_fire false -> fire blocked")
	tracker.queue_free()


## S3-05. _process regen refills ammo toward max_ammo over simulated time.
func _test_regen_refills() -> void:
	print("\n[TEST] S3-05. Regen refills ammo over simulated time")
	var stun := load(STUN_CAST) as CastData
	var cast_list: Array[CastData] = [stun]
	var tracker := _make_tracker(cast_list)
	# Drain completely.
	for _i: int in range(stun.max_ammo):
		tracker.consume(0)
	_assert(tracker.get_ammo(0) == 0, "S3-05: stun drained to 0")
	# Simulate 5 seconds of regen (stun regen = 1.0/s, max = 12).
	# Call _process directly with a 5-second delta.
	tracker._process(5.0)
	_assert(tracker.get_ammo(0) == 5, "S3-05: stun regen 5s -> 5 ammo")
	# Simulate another 20s — should clamp at max.
	tracker._process(20.0)
	_assert(tracker.get_ammo(0) == stun.max_ammo, "S3-05: stun clamped at max_ammo")
	tracker.queue_free()


## S3-06. Per-type pools independent: consuming slot 0 doesn't affect slot 1.
func _test_per_type_pools_independent() -> void:
	print("\n[TEST] S3-06. Per-type pools independent")
	var pistol := load(PISTOL_CAST) as CastData
	var heavy := load(HEAVY_CAST) as CastData
	var rapid := load(RAPID_CAST) as CastData
	var cast_list: Array[CastData] = [pistol, heavy, rapid]
	var tracker := _make_tracker(cast_list)
	# Drain pistol (slot 0) completely.
	for _i: int in range(pistol.max_ammo):
		tracker.consume(0)
	_assert(tracker.get_ammo(0) == 0, "S3-06: pistol drained to 0")
	_assert(tracker.get_ammo(1) == heavy.max_ammo, "S3-06: heavy unchanged at %d" % heavy.max_ammo)
	_assert(tracker.get_ammo(2) == rapid.max_ammo, "S3-06: rapid unchanged at %d" % rapid.max_ammo)
	tracker.queue_free()


## S3-07. can_fire returns true when max_ammo == 0 (unlimited / legacy path).
func _test_can_fire_unlimited_when_max_zero() -> void:
	print("\n[TEST] S3-07. max_ammo==0 treated as unlimited")
	var cast := CastData.new()
	cast.max_ammo = 0
	cast.ammo_cost = 1
	cast.ammo_regen = 0.0
	var cast_list: Array[CastData] = [cast]
	var tracker := _make_tracker(cast_list)
	_assert(tracker.can_fire(0), "S3-07: can_fire true when max_ammo==0")
	tracker.consume(0)
	_assert(tracker.can_fire(0), "S3-07: still can_fire after consume when max_ammo==0")
	tracker.queue_free()
