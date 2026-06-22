# tools/smoke_cast_slice2.gd — headless L2 smoke: Slice-2 bullet-cast + set_active_bullet.
# Run: $GODOT --headless --path . --script tools/smoke_cast_slice2.gd
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
	print("=== CAST SMOKE SLICE-2 ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_rapid_cast_shape()
	_test_rapid_cast_no_knockback()
	_test_all_five_casts_load()
	_test_set_active_bullet_swaps_cast_data()
	_test_set_active_bullet_out_of_range_no_op()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


# ── helpers ───────────────────────────────────────────────────────────────────


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


func _make_ctx(target: Node, instigator_pos: Vector3) -> GameContext:
	var ctx := GameContext.new()
	ctx.instigator = null
	ctx.target = target
	ctx.hit_pos = Vector3.ZERO
	ctx.hit_normal = Vector3.UP
	ctx.instigator_pos = instigator_pos
	return ctx


# Minimal stub: tracks apply_damage / apply_knockback without a full scene.
class StubTarget:
	extends Node
	var damage_received: int = 0
	var knockback_called: bool = false
	var knockback_from: Vector3 = Vector3.ZERO

	func apply_damage(amount: int, _type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
		damage_received += amount

	func apply_knockback(from_pos: Vector3) -> void:
		knockback_called = true
		knockback_from = from_pos


# ── tests ─────────────────────────────────────────────────────────────────────


## S2-16. rapid_cast.tres: 1 effect (DamageEffect only), HitTargetResolver, white color.
func _test_rapid_cast_shape() -> void:
	print("\n[TEST] S2-16. rapid_cast.tres shape (1 effect DamageEffect, HitTargetResolver, white)")
	var cast := load(RAPID_CAST) as CastData
	if cast == null:
		_fail("S2-16: rapid_cast.tres failed to load")
		return
	_assert(cast.effects.size() == 1, "S2-16: rapid_cast has exactly 1 effect")
	_assert(cast.resolver is HitTargetResolver, "S2-16: rapid_cast resolver is HitTargetResolver")
	if cast.effects.size() >= 1:
		_assert(cast.effects[0] is DamageEffect, "S2-16: rapid_cast effects[0] is DamageEffect")
		if cast.effects[0] is DamageEffect:
			var dmg := cast.effects[0] as DamageEffect
			_assert(dmg.amount == 1, "S2-16: rapid_cast DamageEffect.amount == 1")
	_assert(
		cast.bullet_color.is_equal_approx(Color(1, 1, 1, 1)),
		"S2-16: rapid_cast bullet_color is white"
	)


## S2-17. rapid_cast has NO KnockbackEffect; apply vs stub must NOT call apply_knockback.
func _test_rapid_cast_no_knockback() -> void:
	print("\n[TEST] S2-17. rapid_cast has NO KnockbackEffect")
	var cast := load(RAPID_CAST) as CastData
	if cast == null:
		_fail("S2-17: rapid_cast.tres failed to load")
		return
	var has_kb: bool = false
	for eff: Effect in cast.effects:
		if eff is KnockbackEffect:
			has_kb = true
	_assert(not has_kb, "S2-17: rapid_cast contains no KnockbackEffect")
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub, Vector3(5.0, 0.0, 0.0))
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	_assert(not stub.knockback_called, "S2-17: rapid_cast -> apply_knockback NOT called")
	stub.queue_free()


## S2-18. All 5 bullet cast .tres load as CastData with correct bullet_colors.
func _test_all_five_casts_load() -> void:
	print("\n[TEST] S2-18. All 5 bullet casts load as CastData with correct colors")
	var casts: Array[CastData] = []
	var paths: Array[String] = [PISTOL_CAST, HEAVY_CAST, STUN_CAST, BLAST_CAST, RAPID_CAST]
	var labels: Array[String] = ["pistol", "heavy", "stun", "blast", "rapid"]
	var colors: Array[Color] = [
		Color(1, 1, 0, 1),
		Color(1, 0.2, 0.15, 1),
		Color(0.3, 0.6, 1, 1),
		Color(0.4, 0.9, 0.2, 1),
		Color(1, 1, 1, 1),
	]
	for i: int in range(paths.size()):
		var cast := load(paths[i]) as CastData
		if cast == null:
			_fail("S2-18: %s_cast.tres failed to load" % labels[i])
		else:
			casts.append(cast)
			_assert(
				cast.bullet_color.is_equal_approx(colors[i]),
				"S2-18: %s_cast bullet_color correct" % labels[i]
			)
	_assert(casts.size() == 5, "S2-18: all 5 casts loaded successfully")


## S2-19. set_active_bullet(i) swaps cast_data to bullet_casts[i].
## Gun.new() without add_child skips _ready (needs scene children);
## set_active_bullet is pure data — bullet_casts/cast_data/_active_cast are plain vars.
func _test_set_active_bullet_swaps_cast_data() -> void:
	print("\n[TEST] S2-19. set_active_bullet(i) swaps cast_data to bullet_casts[i]")
	var gun := Gun.new()
	var pistol := load(PISTOL_CAST) as CastData
	var heavy := load(HEAVY_CAST) as CastData
	var stun := load(STUN_CAST) as CastData
	var blast := load(BLAST_CAST) as CastData
	var rapid := load(RAPID_CAST) as CastData
	gun.bullet_casts = [pistol, heavy, stun, blast, rapid]
	gun.set_active_bullet(0)
	_assert(gun.cast_data == pistol, "S2-19: index 0 -> pistol_cast")
	gun.set_active_bullet(1)
	_assert(gun.cast_data == heavy, "S2-19: index 1 -> heavy_cast")
	gun.set_active_bullet(2)
	_assert(gun.cast_data == stun, "S2-19: index 2 -> stun_cast")
	gun.set_active_bullet(3)
	_assert(gun.cast_data == blast, "S2-19: index 3 -> blast_cast")
	gun.set_active_bullet(4)
	_assert(gun.cast_data == rapid, "S2-19: index 4 -> rapid_cast")
	gun.free()


## S2-20. set_active_bullet out-of-range / empty array is a no-op (no crash).
func _test_set_active_bullet_out_of_range_no_op() -> void:
	print("\n[TEST] S2-20. set_active_bullet out-of-range / empty is no-op")
	var gun := Gun.new()
	var pistol := load(PISTOL_CAST) as CastData
	gun.bullet_casts = [pistol]
	gun.set_active_bullet(0)
	var before: CastData = gun.cast_data
	gun.set_active_bullet(5)
	_assert(gun.cast_data == before, "S2-20: index 5 on size-1 array -> no-op, cast_data unchanged")
	gun.set_active_bullet(-1)
	_assert(gun.cast_data == before, "S2-20: index -1 -> no-op, cast_data unchanged")
	gun.bullet_casts = []
	gun.set_active_bullet(0)
	_assert(gun.cast_data == before, "S2-20: empty bullet_casts -> no-op, cast_data unchanged")
	gun.free()
