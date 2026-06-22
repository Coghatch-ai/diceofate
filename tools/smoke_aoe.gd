# tools/smoke_aoe.gd — headless L2 smoke: RadiusTargetResolver + blast_cast AoE contract.
# Tests 14-16: blast_cast.tres shape, AoE resolve (3 inside / 1 outside), AoE apply chain.
# Run: $GODOT --headless --path . --script tools/smoke_aoe.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const BLAST_CAST := "res://entities/weapon/blast_cast.tres"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== AOE SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_blast_cast_shape()
	_test_aoe_hits_inside_misses_outside()
	_test_aoe_all_inside_take_damage()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


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


class StubEnemy3D:
	extends Node3D
	var damage_received: int = 0
	var knockback_called: bool = false

	func apply_damage(amount: int, _type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
		damage_received += amount

	func apply_knockback(_from_pos: Vector3) -> void:
		knockback_called = true


## 14. blast_cast.tres: 3 effects (DamageEffect(2)+Knockback+BurnEffect(POISON)),
## RadiusTargetResolver r=3, green (slice B re-theme).
func _test_blast_cast_shape() -> void:
	print(
		"\n[TEST] 14. blast_cast.tres shape (DamageEffect(2)+Knockback+BurnEffect, RadiusResolver r=3)"
	)
	var cast := load(BLAST_CAST) as CastData
	if cast == null:
		_fail("14: blast_cast.tres failed to load")
		return
	_assert(cast.effects.size() == 3, "14: blast_cast has 3 effects")
	_assert(
		cast.resolver is RadiusTargetResolver, "14: blast_cast resolver is RadiusTargetResolver"
	)
	if cast.effects.size() >= 1:
		_assert(cast.effects[0] is DamageEffect, "14: blast_cast effects[0] is DamageEffect")
		if cast.effects[0] is DamageEffect:
			var dmg := cast.effects[0] as DamageEffect
			_assert(dmg.amount == 2, "14: blast_cast DamageEffect.amount == 2")
	if cast.effects.size() >= 2:
		_assert(cast.effects[1] is KnockbackEffect, "14: blast_cast effects[1] is KnockbackEffect")
	if cast.effects.size() >= 3:
		_assert(cast.effects[2] is BurnEffect, "14: blast_cast effects[2] is BurnEffect(POISON)")
	if cast.resolver is RadiusTargetResolver:
		var rtr := cast.resolver as RadiusTargetResolver
		_assert(rtr.radius == 3.0, "14: blast_cast RadiusTargetResolver.radius == 3.0")
	_assert(
		cast.bullet_color.g > 0.7 and cast.bullet_color.r < 0.6, "14: blast_cast bullet_color green"
	)


## 15. AoE resolve: 3 stubs inside r=3, 1 outside — group fallback (ctx.space=null).
func _test_aoe_hits_inside_misses_outside() -> void:
	print("\n[TEST] 15. AoE RadiusTargetResolver: 3 inside / 1 outside (group fallback)")
	var resolver := RadiusTargetResolver.new()
	resolver.radius = 3.0
	var inside: Array[StubEnemy3D] = []
	for i: int in range(3):
		var s := StubEnemy3D.new()
		s.global_position = Vector3(float(i) * 0.5, 0.0, 0.0)
		s.add_to_group("enemies")
		root.add_child(s)
		inside.append(s)
	var outside := StubEnemy3D.new()
	outside.global_position = Vector3(5.0, 0.0, 0.0)
	outside.add_to_group("enemies")
	root.add_child(outside)
	var ctx := GameContext.new()
	ctx.hit_pos = Vector3.ZERO
	ctx.space = null
	var targets: Array[Node] = resolver.resolve(ctx)
	_assert(targets.size() == 3, "15: resolve returns 3 targets inside radius")
	_assert(not targets.has(outside), "15: outside stub NOT in resolved targets")
	for s: StubEnemy3D in inside:
		s.remove_from_group("enemies")
		s.queue_free()
	outside.remove_from_group("enemies")
	outside.queue_free()


## 16. AoE E2E: blast_cast.tres resolve+apply, 3 inside damaged=2, 1 outside untouched.
func _test_aoe_all_inside_take_damage() -> void:
	print("\n[TEST] 16. AoE E2E: blast_cast resolve+apply: 3 inside / 1 outside")
	var cast := load(BLAST_CAST) as CastData
	if cast == null:
		_fail("16: blast_cast.tres failed to load")
		return
	var inside: Array[StubEnemy3D] = []
	for i: int in range(3):
		var s := StubEnemy3D.new()
		s.global_position = Vector3(float(i) * 0.5, 0.0, 0.0)
		s.add_to_group("enemies")
		root.add_child(s)
		inside.append(s)
	var outside := StubEnemy3D.new()
	outside.global_position = Vector3(5.0, 0.0, 0.0)
	outside.add_to_group("enemies")
	root.add_child(outside)
	var ctx := GameContext.new()
	ctx.instigator = null
	ctx.target = inside[0]
	ctx.hit_pos = Vector3.ZERO
	ctx.hit_normal = Vector3.UP
	ctx.instigator_pos = Vector3(10.0, 0.0, 0.0)
	ctx.space = null
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	var all_inside_damaged: bool = true
	for s: StubEnemy3D in inside:
		if s.damage_received != 2:
			all_inside_damaged = false
	_assert(all_inside_damaged, "16: all 3 inside stubs received damage=2")
	_assert(outside.damage_received == 0, "16: outside stub received no damage")
	_assert(inside[0].knockback_called, "16: knockback reached at least one inside stub")
	for s: StubEnemy3D in inside:
		s.remove_from_group("enemies")
		s.queue_free()
	outside.remove_from_group("enemies")
	outside.queue_free()
