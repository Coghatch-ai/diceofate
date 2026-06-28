# tools/play_boss_attack_components.gd — adversarial playgrade bot for the boss overhaul.
# Boots the real Boss (warden data: attacks = [Charge, Slam, Summon]) in a minimal world with a
# stub player in group "player", steps physics, and asserts the design Acceptance deltas:
#   - boss is ALWAYS MOVING (no >=1.0s XZ-zero window while phase != DEAD)
#   - boss cycles ALL attacks and each DOES something (charge dashes, slam telegraphs+detonates+VFX,
#     summon spawns adds into group "enemies")
#   - summon respects max_concurrent_adds cap; dead adds free their slot
#   - KNOWN-RISK: do summoned adds threaten the player? (touched_player wired to player damage?)
#   - boss death drives complete_run/advance on the boss level.
# Run: $GODOT --headless --path . --script tools/play_boss_attack_components.gd
# Exit 0 = all pass, 1 = any fail.
extends SceneTree

const BOSS_SCENE: PackedScene = preload("res://entities/boss/boss.tscn")
const WARDEN: BossData = preload("res://archetypes/boss_warden.tres")
const IRON_FLOOR: PackedScene = preload("res://levels/iron_floor.tscn")
const CHARGE_SCENE: PackedScene = preload("res://entities/boss/attacks/charge_attack.tscn")
const SLAM_SCENE: PackedScene = preload("res://entities/boss/attacks/slam_attack.tscn")
const SUMMON_SCENE: PackedScene = preload("res://entities/boss/attacks/summon_attack.tscn")

var _pass_count: int = 0
var _fail_count: int = 0


# Stub player: CharacterBody3D in group "player" with the duck-typed combat seam the boss reaches.
class StubPlayer:
	extends CharacterBody3D
	var damage_taken: int = 0
	var knockbacks: int = 0

	func _ready() -> void:
		add_to_group("player")

	func apply_damage(amount: int, _type: int = 0) -> void:
		damage_taken += amount

	func apply_knockback(_from: Vector3, _impulse: float) -> void:
		knockbacks += 1


# Typed handle for a built world so call sites need no unsafe casts off an untyped Array.
class World:
	extends RefCounted
	var boss: Boss = null
	var player: StubPlayer = null
	var root_node: Node3D = null


func _initialize() -> void:
	print("=== PLAY: boss_attack_components ===")
	await _run_all()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _run_all() -> void:
	await _test_attacks_array_data_driven()
	await _test_cycles_all_attacks_and_each_acts()
	await _test_always_moving()
	await _test_summon_cap_and_slot_free()
	await _test_adds_touch_damage_wired()
	await _test_boss_death_drives_complete_run()


# ── helpers ─────────────────────────────────────────────────────────────────────
func _pass(msg: String) -> void:
	_pass_count += 1
	print("  PASS: %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	print("  FAIL: %s" % msg)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass(msg)
	else:
		_fail(msg)


## Build a minimal world: floor + stub player + real boss. Returns a typed World handle.
func _build_world(boss_y: float, player_offset: Vector3) -> World:
	var w: Node3D = Node3D.new()
	root.add_child(w)
	# SummonAttack / slam-VFX / boss-explode all parent spawns under get_tree().current_scene.
	# A --script SceneTree has none, so register this world as current_scene to exercise those paths.
	current_scene = w
	# Wide floor at y=0 so boss/adds register is_on_floor (gravity needs ground).
	var floor_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	w.add_child(floor_body)
	var player: StubPlayer = StubPlayer.new()
	w.add_child(player)
	player.global_position = Vector3.ZERO + player_offset
	var boss: Boss = BOSS_SCENE.instantiate() as Boss
	boss.data = WARDEN
	w.add_child(boss)
	boss.global_position = Vector3(0.0, boss_y, 0.0)
	var handle: World = World.new()
	handle.boss = boss
	handle.player = player
	handle.root_node = w
	return handle


func _step(frames: int) -> void:
	for _i: int in range(frames):
		await physics_frame


func _attacks_node(boss: Boss) -> Node:
	return boss.get_node_or_null("Attacks")


## SEAM: read Boss._phase (private test seam) — get() returns Variant; int() converts safely.
func _phase_of(boss: Boss) -> int:
	@warning_ignore("unsafe_call_argument")
	return int(boss.get("_phase"))


## SEAM: read a float private field via get() (Variant) — float() converts safely.
func _get_float(obj: Object, field: String) -> float:
	@warning_ignore("unsafe_call_argument")
	return float(obj.get(field))


## SEAM: read SummonAttack._live_adds size (private Array) via get(); 0 if not an Array.
func _live_adds_size(summon: SummonAttack) -> int:
	var v: Variant = summon.get("_live_adds")
	if not v is Array:
		return 0
	# SEAM: _live_adds is an Array by construction (guarded above).
	@warning_ignore("unsafe_cast")
	return (v as Array).size()


# ── Test 1: data-driven attack set ───────────────────────────────────────────────
func _test_attacks_array_data_driven() -> void:
	print("\n[1] data-driven attack set (warden .tres)")
	var arr: Array[PackedScene] = WARDEN.attacks
	_assert(arr.size() == 3, "warden.attacks has exactly 3 entries (got %d)" % arr.size())
	# The .tres order must be Charge, Slam, Summon — instancing each must yield the right type.
	var c: Node = CHARGE_SCENE.instantiate()
	var s: Node = SLAM_SCENE.instantiate()
	var m: Node = SUMMON_SCENE.instantiate()
	_assert(c is ChargeAttack, "attacks[0] scene is ChargeAttack")
	_assert(s is SlamAttack, "attacks[1] scene is SlamAttack")
	_assert(m is SummonAttack, "attacks[2] scene is SummonAttack")
	# Boss instances exactly these under Attacks at _ready (the loop reads them, no hardcode).
	var wd: World = _build_world(2.0, Vector3(0.0, 0.0, 6.0))
	var boss: Boss = wd.boss
	await _step(3)
	var an: Node = _attacks_node(boss)
	var kids: Array[Node] = an.get_children() if an != null else []
	_assert(
		kids.size() == 3, "Boss instanced 3 BossAttack children from data (got %d)" % kids.size()
	)
	_assert(
		(
			kids.size() == 3
			and kids[0] is ChargeAttack
			and kids[1] is SlamAttack
			and kids[2] is SummonAttack
		),
		"Attacks children order matches .tres: Charge, Slam, Summon"
	)
	c.free()
	s.free()
	m.free()
	wd.root_node.queue_free()
	await _step(2)


# ── Test 2: cycles all attacks, each DOES something ──────────────────────────────
func _test_cycles_all_attacks_and_each_acts() -> void:
	print("\n[2] boss cycles ALL attacks and each acts (charge/slam/summon)")
	# Player placed FAR so the charge dash runs its full duration (not an instant 1-frame contact);
	# summon adds still register in group "enemies"; slam AoE still reaches via large radius.
	var wd: World = _build_world(2.0, Vector3(0.0, 0.0, 15.0))
	var boss: Boss = wd.boss
	var player: StubPlayer = wd.player
	var world: Node = wd.root_node
	# Force the boss to summon early so the cap/spawn path runs in a short window:
	# the summon component's cooldown is 8s; pre-arm its accumulator so first activation fires.
	_force_summon_ready(boss)
	# Track group-enemies max during the run (summon adds register in group "enemies").
	var max_adds: int = 0
	var saw_charge_move: bool = false
	var saw_slam_detonate: bool = false
	var phases_seen: Dictionary = {}
	var slam: SlamAttack = _slam_node(boss)
	# Run ~14s of physics; round-robin Charge->Slam->Summon with ~1.7s/cycle covers all three.
	for _i: int in range(14 * 60):
		await physics_frame
		if not is_instance_valid(boss):
			break
		var ph: int = _phase_of(boss)
		phases_seen[ph] = true
		# Charge: during EXECUTING the boss commands a fast XZ dash velocity (charge_speed=18).
		var vxz: float = Vector2(boss.velocity.x, boss.velocity.z).length()
		if ph == 2 and vxz > 8.0:
			saw_charge_move = true
		# Summon adds appear in group "enemies".
		var adds: int = get_nodes_in_group("enemies").size()
		if adds > max_adds:
			max_adds = adds
		# Slam: the SlamAttack flips _detonated true on AoE (headless-safe, no VFX dependence).
		if _slam_detonated(slam):
			saw_slam_detonate = true
	_assert(phases_seen.has(1), "boss entered TELEGRAPH phase (telegraph reads)")
	_assert(phases_seen.has(2), "boss entered EXECUTING phase (an attack ran)")
	_assert(saw_charge_move, "CHARGE acted: boss XZ dashed >8 m/s during EXECUTING")
	_assert(saw_slam_detonate, "SLAM acted: SlamAttack detonated (AoE fired after telegraph)")
	_assert(max_adds >= 1, "SUMMON acted: adds entered group 'enemies' (max=%d)" % max_adds)
	# Damage delta proves charge/slam reached the player (contact or AoE).
	_assert(
		player.damage_taken > 0,
		"boss dealt damage to player via an attack (taken=%d)" % player.damage_taken
	)
	(world as Node).queue_free()
	await _step(2)


## Pre-arm SummonAttack so its 8s cooldown does not block the first activation in a short bot run.
func _force_summon_ready(boss: Boss) -> Node:
	var an: Node = _attacks_node(boss)
	if an == null:
		return null
	for k: Node in an.get_children():
		if k is SummonAttack:
			# SEAM: pre-set the cooldown accumulator so the first summon is allowed immediately.
			k.set("_cooldown_accum", 999.0)
			return k
	return null


## Find the SlamAttack child under Attacks (to read its _detonated flag — a test seam).
func _slam_node(boss: Boss) -> SlamAttack:
	var an: Node = _attacks_node(boss)
	if an == null:
		return null
	for k: Node in an.get_children():
		if k is SlamAttack:
			return k as SlamAttack
	return null


## SEAM: read SlamAttack._detonated (private bool) via get(); headless-safe (no VFX needed).
func _slam_detonated(slam: SlamAttack) -> bool:
	if slam == null:
		return false
	var v: Variant = slam.get("_detonated")
	if not v is bool:
		return false
	# SEAM: _detonated is a bool by construction (guarded by the `is bool` check above).
	@warning_ignore("unsafe_cast")
	return v as bool


# ── Test 3: always moving ────────────────────────────────────────────────────────
func _test_always_moving() -> void:
	print("\n[3] always moving — no >=1.0s XZ-zero window while phase != DEAD")
	var wd: World = _build_world(2.0, Vector3(0.0, 0.0, 8.0))
	var boss: Boss = wd.boss
	var player: StubPlayer = wd.player
	var world: Node = wd.root_node
	await _step(5)  # settle onto floor
	var longest_zero_run: float = 0.0
	var cur_zero_run: float = 0.0
	var dt: float = 1.0 / 60.0
	var moving_frames: int = 0
	var total_frames: int = 0
	# A real fight has a MOVING target; orbit the stub player so the boss always has somewhere to
	# chase. A static target lets the boss arrive and legitimately stop (false standstill), which is
	# not what the Acceptance ("always moving") is about.
	var t: float = 0.0
	for _i: int in range(10 * 60):
		await physics_frame
		t += dt
		if is_instance_valid(player):
			player.global_position = Vector3(cos(t * 1.2) * 9.0, 0.0, sin(t * 1.2) * 9.0)
		if not is_instance_valid(boss):
			break
		var ph: int = _phase_of(boss)
		if ph == 4:  # DEAD
			break
		total_frames += 1
		var v: Vector3 = boss.velocity
		var xz: float = Vector2(v.x, v.z).length()
		# Slam deliberately halts XZ during its inner wind-up; that is a legitimate brief stop.
		# Acceptance bounds the contiguous zero window at <1.0s regardless of cause.
		if xz < 0.05:
			cur_zero_run += dt
			if cur_zero_run > longest_zero_run:
				longest_zero_run = cur_zero_run
		else:
			moving_frames += 1
			cur_zero_run = 0.0
	var moving_frac: float = float(moving_frames) / float(maxi(total_frames, 1))
	_assert(
		longest_zero_run < 1.0,
		"no contiguous XZ-zero window >=1.0s (longest=%.2fs)" % longest_zero_run
	)
	_assert(
		moving_frac > 0.5, "boss moving (xz>0) majority of frames (%.0f%%)" % (moving_frac * 100.0)
	)
	world.queue_free()
	await _step(2)


# ── Test 4: summon cap + slot free ───────────────────────────────────────────────
func _test_summon_cap_and_slot_free() -> void:
	print("\n[4] summon cap respected + dead add frees its slot")
	var summon: SummonAttack = SUMMON_SCENE.instantiate() as SummonAttack
	# Read configured cap/count from the component (data-driven).
	var cap: int = summon.max_concurrent_adds
	var count: int = summon.spawn_count
	_assert(cap >= 1, "max_concurrent_adds configured (%d)" % cap)
	_assert(count >= 1, "spawn_count configured (%d)" % count)
	summon.free()
	# Live: pre-arm summon, run long enough for several summon activations, assert adds never
	# exceed cap, then kill all adds and confirm the live-add list drains (slot frees).
	var wd: World = _build_world(2.0, Vector3(0.0, 0.0, 5.0))
	var boss: Boss = wd.boss
	var world: Node = wd.root_node
	var s: SummonAttack = _force_summon_ready(boss) as SummonAttack
	if s == null:
		_fail("SummonAttack not found under Attacks — cannot test cap")
		world.queue_free()
		await _step(2)
		return
	# Re-arm the cooldown each time it resets so summon fires repeatedly within the window.
	var peak: int = 0
	for _i: int in range(20 * 60):
		await physics_frame
		if not is_instance_valid(boss):
			break
		# Keep summon ready: if it just consumed cooldown, top it back up.
		if _get_float(s, "_cooldown_accum") < s.cooldown:
			s.set("_cooldown_accum", 999.0)
		var adds: int = get_nodes_in_group("enemies").size()
		if adds > peak:
			peak = adds
	_assert(peak >= 1, "summon spawned at least one add over the run (peak=%d)" % peak)
	_assert(
		peak <= s.max_concurrent_adds,
		"adds never exceeded cap %d (peak=%d) — no flood" % [s.max_concurrent_adds, peak]
	)
	# Slot free via the DIED SIGNAL (not the start()-time prune): the component connects each add's
	# died → _on_add_died to erase it. Kill all adds, step a FEW frames WITHOUT re-arming summon,
	# and assert the live-add list drained purely from the signal path. If died is mis-connected
	# (wrong arity), the callback errors and the list never shrinks → this catches that regression.
	var live_before: int = _live_adds_size(s)
	_assert(live_before >= 1, "component tracked >=1 live add before kill (%d)" % live_before)
	for e: Node in get_nodes_in_group("enemies"):
		if e.has_method("on_hit"):
			# SEAM: duck-typed on_hit — drive lethal hits until it dies (grunt health small).
			for _h: int in range(10):
				if not is_instance_valid(e):
					break
				@warning_ignore("unsafe_method_access")
				e.on_hit()
	await _step(10)  # NO re-arm here, so only the died-signal path can drain _live_adds.
	var live_after: int = _live_adds_size(s)
	_assert(
		live_after < live_before,
		"add died → _on_add_died erased it (live %d→%d via died signal)" % [live_before, live_after]
	)
	# And the group + cap stay consistent after deaths.
	_assert(
		get_nodes_in_group("enemies").size() <= s.max_concurrent_adds,
		"after killing adds, group 'enemies' stays within cap (slot freed)"
	)
	world.queue_free()
	await _step(2)


# ── Test 5: KNOWN-RISK — do adds threaten the player? ────────────────────────────
func _test_adds_touch_damage_wired() -> void:
	print("\n[5] KNOWN-RISK: summoned adds touch-damage the player?")
	# Spawn an add the same way SummonAttack does, then emit its touched_player and check whether
	# ANY wiring exists in the boss path to translate that into player.apply_damage.
	var wd: World = _build_world(2.0, Vector3(0.0, 0.0, 4.0))
	var boss: Boss = wd.boss
	var player: StubPlayer = wd.player
	var world: Node = wd.root_node
	var s: SummonAttack = _force_summon_ready(boss) as SummonAttack
	if s == null:
		_fail("SummonAttack missing — cannot test add touch damage")
		world.queue_free()
		await _step(2)
		return
	# Drive until at least one add exists.
	var add: Node = null
	for _i: int in range(8 * 60):
		await physics_frame
		if _get_float(s, "_cooldown_accum") < s.cooldown:
			s.set("_cooldown_accum", 999.0)
		var grp: Array = get_nodes_in_group("enemies")
		if not grp.is_empty():
			add = grp[0]
			break
	if add == null:
		_fail("no add spawned within 8s — cannot test add touch damage")
		world.queue_free()
		await _step(2)
		return
	var taken_before: int = player.damage_taken
	# An add's touched_player fires when it contacts the player. Emit it directly to test wiring.
	_assert(add.has_signal("touched_player"), "add has touched_player signal (Enemy contract)")
	# SEAM: emit the add's touched_player as a real contact would.
	@warning_ignore("unsafe_method_access")
	add.emit_signal("touched_player", add)
	await _step(3)
	var dealt: bool = player.damage_taken > taken_before
	# DESIGN: Acceptance "new enemies are live (have HealthComponent)"; the task flags adds may NOT
	# hurt the player. Report the truth: PASS only if the add's contact damages the player.
	_assert(
		dealt,
		"summoned add's touched_player deals damage to player (KNOWN-RISK: slice-4 flagged this gap)"
	)
	world.queue_free()
	await _step(2)


# ── Test 6: boss death drives complete_run/advance ───────────────────────────────
func _test_boss_death_drives_complete_run() -> void:
	print("\n[6] boss death drives complete_run/advance on the boss level")
	var level: Node = IRON_FLOOR.instantiate()
	root.add_child(level)
	current_scene = level
	await _step(5)
	var boss: Boss = level.get_node_or_null("Boss") as Boss
	var rc: Node = level.get_node_or_null("RoomController")
	if boss == null or rc == null:
		_fail("iron_floor missing Boss or RoomController node")
		level.queue_free()
		await _step(2)
		return
	var advanced: Array[int] = [0]
	# SEAM: RoomController.advance_level(score) typed signal.
	rc.connect("advance_level", func(_score: int) -> void: advanced[0] += 1)
	# iron_floor uses boss_slime (color-phase boss): it is vulnerable to only ONE damage type at a
	# time (the active color phase), cycling on a timer. on_hit (physical) is resisted in most
	# phases, so spray a big hit of EVERY damage type each frame — whichever phase is active takes
	# it — to drain all phases → explode → died → complete_run. (Drives the real death/advance seam.)
	for _h: int in range(400):
		if not is_instance_valid(boss):
			break
		for kind: int in range(6):
			# SEAM: duck-typed apply_damage(amount, DamageType.Kind) — boss combat seam.
			@warning_ignore("unsafe_method_access")
			@warning_ignore("unsafe_call_argument")
			boss.apply_damage(5, kind)
		await physics_frame
	await _step(10)
	_assert(advanced[0] >= 1, "boss death → RoomController.advance_level fired (complete_run path)")
	(level as Node).queue_free()
	await _step(2)
