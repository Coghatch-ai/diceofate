# tools/smoke_cast.gd — headless L2 smoke: Cast System logic contract (tests 1-13).
# AoE tests 14-16 live in tools/smoke_aoe.gd (RadiusTargetResolver).
# Run: $GODOT --headless --path . --script tools/smoke_cast.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const GRUNT_SCENE := "res://entities/enemy/enemy.tscn"
const PISTOL_CAST := "res://entities/weapon/pistol_cast.tres"
const HEAVY_CAST := "res://entities/weapon/heavy_cast.tres"
const STUN_CAST := "res://entities/weapon/stun_cast.tres"
var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== CAST SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_damage_effect_calls_apply_damage()
	_test_knockback_effect_calls_apply_knockback()
	_test_damage_effect_one_shots_grunt()
	_test_damage_effect_tank_one_cast()
	_test_fallback_on_hit()
	_test_hit_target_resolver()
	_test_pistol_cast_tres_loads()
	_test_heavy_cast_tres_loads()
	_test_e2e_pistol_cast_vs_grunt()
	_test_bullet_color_loads()
	_test_stun_cast_shape()
	_test_light_bolt_vs_tank()
	_test_heavy_slug_vs_tank()
	_test_stun_dart_vs_grunt()
	_test_e2e_heavy_cast_vs_tank()
	_test_heavy_cast_pierces_barriers_true()
	_test_non_piercing_casts_pierces_barriers_false()
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


## 1. DamageEffect.apply() must call apply_damage(amount) on the target.
func _test_damage_effect_calls_apply_damage() -> void:
	print("\n[TEST] DamageEffect.apply() calls target.apply_damage(amount)")
	var eff := DamageEffect.new()
	eff.amount = 5
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub, Vector3.ZERO)
	eff.apply(stub, ctx)
	_assert(stub.damage_received == 5, "DamageEffect amount=5 -> apply_damage(5)")
	stub.queue_free()


## 2. KnockbackEffect.apply() must call apply_knockback(instigator_pos).
func _test_knockback_effect_calls_apply_knockback() -> void:
	print("\n[TEST] KnockbackEffect.apply() calls target.apply_knockback(instigator_pos)")
	var eff := KnockbackEffect.new()
	var stub := StubTarget.new()
	root.add_child(stub)
	var src := Vector3(3.0, 0.0, 1.0)
	var ctx := _make_ctx(stub, src)
	eff.apply(stub, ctx)
	_assert(stub.knockback_called, "KnockbackEffect -> apply_knockback called")
	_assert(
		stub.knockback_from.is_equal_approx(src),
		"KnockbackEffect -> instigator_pos forwarded correctly"
	)
	stub.queue_free()


## 3. DamageEffect(amount=1) one-shots a health=1 enemy: died emitted synchronously.
## (Grunt default is now health=2 for perceptibility; pin to 1 here to test DamageEffect unit.)
func _test_damage_effect_one_shots_grunt() -> void:
	print("\n[TEST] DamageEffect(amount=1) one-shots enemy (health=1) -> died emitted")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var enemy := packed.instantiate() as Enemy
	enemy.health = 1
	root.add_child(enemy)
	var died_count: Array[int] = [0]
	enemy.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var eff := DamageEffect.new()
	eff.amount = 1
	var ctx := _make_ctx(enemy, Vector3.ZERO)
	eff.apply(enemy, ctx)
	_assert(died_count[0] == 1, "DamageEffect(1) -> grunt died signal")


## 4. DamageEffect(amount=3) one-shots health=3 tank in one cast.
func _test_damage_effect_tank_one_cast() -> void:
	print("\n[TEST] DamageEffect(amount=3) one-shots tank (health=3) in one cast")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var tank := packed.instantiate() as Enemy
	tank.health = 3
	root.add_child(tank)
	var died_count: Array[int] = [0]
	tank.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var eff := DamageEffect.new()
	eff.amount = 3
	var ctx := _make_ctx(tank, Vector3.ZERO)
	eff.apply(tank, ctx)
	_assert(died_count[0] == 1, "DamageEffect(3) -> tank (health=3) died in one cast")


## 5. Fallback: enemy.on_hit() still kills (no regression when cast_data is null).
## Pin health=1 so a single on_hit() is fatal (unit test for the fallback seam, not balance).
func _test_fallback_on_hit() -> void:
	print("\n[TEST] enemy.on_hit() alias still kills (fallback path)")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var enemy := packed.instantiate() as Enemy
	enemy.health = 1
	root.add_child(enemy)
	var died_count: Array[int] = [0]
	enemy.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	enemy.on_hit()
	_assert(died_count[0] == 1, "on_hit() alias -> died emitted (fallback path)")


## 6. HitTargetResolver returns [ctx.target]; [] when target is null.
func _test_hit_target_resolver() -> void:
	print("\n[TEST] HitTargetResolver.resolve() returns [ctx.target] or [] when null")
	var resolver := HitTargetResolver.new()
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx_hit := _make_ctx(stub, Vector3.ZERO)
	var result_hit: Array[Node] = resolver.resolve(ctx_hit)
	_assert(result_hit.size() == 1 and result_hit[0] == stub, "HitTargetResolver: returns [target]")
	var ctx_null := _make_ctx(null, Vector3.ZERO)
	var result_null: Array[Node] = resolver.resolve(ctx_null)
	_assert(result_null.is_empty(), "HitTargetResolver: returns [] when target null")
	stub.queue_free()


## 7. pistol_cast.tres loads with 2 effects + HitTargetResolver.
func _test_pistol_cast_tres_loads() -> void:
	print("\n[TEST] pistol_cast.tres loads with 2 effects + HitTargetResolver")
	var cast := load(PISTOL_CAST) as CastData
	if cast == null:
		_fail("pistol_cast.tres failed to load or is not CastData")
		return
	_assert(cast.effects.size() == 2, "pistol_cast.tres has 2 effects")
	_assert(cast.resolver is HitTargetResolver, "pistol_cast.tres resolver is HitTargetResolver")
	if cast.effects.size() >= 1 and cast.effects[0] is DamageEffect:
		var dmg := cast.effects[0] as DamageEffect
		_assert(dmg.amount == 1, "pistol_cast.tres DamageEffect.amount == 1")
	else:
		_fail("pistol_cast.tres effects[0] is not DamageEffect")


## 8. heavy_cast.tres: CastData, 2 effects, DamageEffect amount=3, HitTargetResolver.
func _test_heavy_cast_tres_loads() -> void:
	print(
		"\n[TEST] heavy_cast.tres loads as CastData (2 effects, DamageEffect amount=3, HitTargetResolver)"
	)
	var cast := load(HEAVY_CAST) as CastData
	if cast == null:
		_fail("heavy_cast.tres failed to load or is not CastData")
		return
	_assert(cast.effects.size() == 2, "heavy_cast.tres has 2 effects")
	_assert(cast.resolver is HitTargetResolver, "heavy_cast.tres resolver is HitTargetResolver")
	if cast.effects.size() >= 1 and cast.effects[0] is DamageEffect:
		var dmg := cast.effects[0] as DamageEffect
		_assert(dmg.amount == 3, "heavy_cast.tres DamageEffect.amount == 3")
	else:
		_fail("heavy_cast.tres effects[0] is not DamageEffect")


## E2E-A. pistol_cast.tres resolve+apply vs grunt: died + knockback (both effects fired).
## Pin health=1 so pistol dmg=1 is fatal (grunt default is now 2 for perceptibility).
func _test_e2e_pistol_cast_vs_grunt() -> void:
	print("\n[TEST] E2E-A: pistol_cast.tres resolve+apply vs grunt -> died + knockback")
	var cast := load(PISTOL_CAST) as CastData
	if cast == null:
		_fail("E2E-A: pistol_cast.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("E2E-A: enemy.tscn failed to load")
		return
	var grunt := packed.instantiate() as Enemy
	grunt.health = 1
	root.add_child(grunt)
	var died_count: Array[int] = [0]
	grunt.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var ctx := GameContext.new()
	ctx.instigator = null
	ctx.target = grunt
	ctx.hit_pos = Vector3.ZERO
	ctx.hit_normal = Vector3.UP
	ctx.instigator_pos = Vector3(5.0, 0.0, 0.0)
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	_assert(died_count[0] == 1, "E2E-A: pistol_cast.tres -> grunt died signal emitted once")
	_assert(grunt._stun_timer > 0.0, "E2E-A: pistol_cast.tres -> apply_knockback reached")


## 9. bullet_color loads on each CastData: yellow/red/cyan + correct effect counts.
func _test_bullet_color_loads() -> void:
	print("\n[TEST] 9. bullet_color loads on pistol/heavy/stun CastData")
	var pistol := load(PISTOL_CAST) as CastData
	var heavy := load(HEAVY_CAST) as CastData
	var stun := load(STUN_CAST) as CastData
	if pistol == null:
		_fail("9: pistol_cast.tres failed to load")
	else:
		_assert(
			pistol.bullet_color.is_equal_approx(Color(1, 1, 0, 1)),
			"9: pistol_cast bullet_color is yellow"
		)
		_assert(pistol.effects.size() == 2, "9: pistol_cast has 2 effects")
	if heavy == null:
		_fail("9: heavy_cast.tres failed to load")
	else:
		_assert(
			heavy.bullet_color.is_equal_approx(Color(1, 0.2, 0.15, 1)),
			"9: heavy_cast bullet_color is red"
		)
		_assert(heavy.effects.size() == 2, "9: heavy_cast has 2 effects")
	if stun == null:
		_fail("9: stun_cast.tres failed to load")
	else:
		_assert(
			stun.bullet_color.is_equal_approx(Color(0.2, 0.8, 1, 1)),
			"9: stun_cast bullet_color is cyan"
		)
		_assert(stun.effects.size() == 2, "9: stun_cast has 2 effects")


## 10. stun_cast: 2 effects, DamageEffect(1)+KnockbackEffect, HitTargetResolver.
func _test_stun_cast_shape() -> void:
	print("\n[TEST] 10. stun_cast shape (2 effects, DamageEffect(1)+Knockback, HitTargetResolver)")
	var cast := load(STUN_CAST) as CastData
	if cast == null:
		_fail("10: stun_cast.tres failed to load")
		return
	_assert(cast.effects.size() == 2, "10: stun_cast has 2 effects")
	_assert(cast.resolver is HitTargetResolver, "10: stun_cast resolver is HitTargetResolver")
	if cast.effects.size() >= 1:
		_assert(cast.effects[0] is DamageEffect, "10: stun_cast effects[0] is DamageEffect")
		if cast.effects[0] is DamageEffect:
			var dmg := cast.effects[0] as DamageEffect
			_assert(dmg.amount == 1, "10: stun_cast DamageEffect.amount == 1")
	if cast.effects.size() >= 2:
		_assert(cast.effects[1] is KnockbackEffect, "10: stun_cast effects[1] is KnockbackEffect")


## 11. Light Bolt (pistol_cast, amount=1): NOT one-shot vs tank; dies on 3rd cast.
func _test_light_bolt_vs_tank() -> void:
	print("\n[TEST] 11. Light Bolt vs tank (health=3): NOT one-shot; dies on 3rd cast")
	var cast := load(PISTOL_CAST) as CastData
	if cast == null:
		_fail("11: pistol_cast.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("11: enemy.tscn failed to load")
		return
	var tank := packed.instantiate() as Enemy
	tank.health = 3
	root.add_child(tank)
	var died_count: Array[int] = [0]
	tank.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var ctx1 := _make_ctx(tank, Vector3(5.0, 0.0, 0.0))
	var targets1: Array[Node] = cast.resolver.resolve(ctx1)
	for t: Node in targets1:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx1)
	_assert(died_count[0] == 0, "11: Light Bolt cast 1 -> tank alive (died NOT emitted)")
	var ctx2 := _make_ctx(tank, Vector3(5.0, 0.0, 0.0))
	var targets2: Array[Node] = cast.resolver.resolve(ctx2)
	for t: Node in targets2:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx2)
	_assert(died_count[0] == 0, "11: Light Bolt cast 2 -> tank alive (died NOT emitted)")
	var ctx3 := _make_ctx(tank, Vector3(5.0, 0.0, 0.0))
	var targets3: Array[Node] = cast.resolver.resolve(ctx3)
	for t: Node in targets3:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx3)
	_assert(died_count[0] == 1, "11: Light Bolt cast 3 -> tank died on 3rd cast")


## 12. Heavy Slug (heavy_cast, amount=3) one-shots tank (health=3) AND reaches knockback.
func _test_heavy_slug_vs_tank() -> void:
	print("\n[TEST] 12. Heavy Slug vs tank (health=3): one-shot + knockback")
	var cast := load(HEAVY_CAST) as CastData
	if cast == null:
		_fail("12: heavy_cast.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("12: enemy.tscn failed to load")
		return
	var tank := packed.instantiate() as Enemy
	tank.health = 3
	root.add_child(tank)
	var died_count: Array[int] = [0]
	tank.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var ctx := _make_ctx(tank, Vector3(5.0, 0.0, 0.0))
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	_assert(died_count[0] == 1, "12: Heavy Slug -> tank (health=3) died in one cast")
	_assert(tank._stun_timer > 0.0, "12: Heavy Slug -> apply_knockback reached (_stun_timer > 0)")


## 13. Stun Dart (stun_cast, amount=1) kills a health=1 enemy AND reaches knockback.
## Pin health=1 (grunt default is now 2 for perceptibility; unit test for stun seam).
func _test_stun_dart_vs_grunt() -> void:
	print("\n[TEST] 13. Stun Dart vs enemy (health=1): died + knockback")
	var cast := load(STUN_CAST) as CastData
	if cast == null:
		_fail("13: stun_cast.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("13: enemy.tscn failed to load")
		return
	var grunt := packed.instantiate() as Enemy
	grunt.health = 1
	root.add_child(grunt)
	var died_count: Array[int] = [0]
	grunt.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var ctx := _make_ctx(grunt, Vector3(5.0, 0.0, 0.0))
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	_assert(died_count[0] == 1, "13: Stun Dart -> grunt (health=1) died")
	_assert(grunt._stun_timer > 0.0, "13: Stun Dart -> apply_knockback reached (_stun_timer > 0)")


## 14. heavy_cast.tres has pierces_barriers = true (data contract).
func _test_heavy_cast_pierces_barriers_true() -> void:
	print("\n[TEST] 14. heavy_cast.tres pierces_barriers == true")
	var cast := load(HEAVY_CAST) as CastData
	if cast == null:
		_fail("14: heavy_cast.tres failed to load")
		return
	_assert(cast.pierces_barriers, "14: heavy_cast.tres pierces_barriers is true")


## 15. pistol/stun casts have pierces_barriers = false (default; non-piercing stays blocked).
func _test_non_piercing_casts_pierces_barriers_false() -> void:
	print("\n[TEST] 15. pistol_cast / stun_cast pierces_barriers == false (default)")
	var pistol := load(PISTOL_CAST) as CastData
	var stun := load(STUN_CAST) as CastData
	if pistol == null:
		_fail("15: pistol_cast.tres failed to load")
	else:
		_assert(not pistol.pierces_barriers, "15: pistol_cast.tres pierces_barriers is false")
	if stun == null:
		_fail("15: stun_cast.tres failed to load")
	else:
		_assert(not stun.pierces_barriers, "15: stun_cast.tres pierces_barriers is false")


## E2E-B. heavy_cast.tres resolve+apply vs tank (health=3): died in one cast (amount=3).
func _test_e2e_heavy_cast_vs_tank() -> void:
	print("\n[TEST] E2E-B: heavy_cast.tres resolve+apply vs tank (health=3) -> died in one cast")
	var cast := load(HEAVY_CAST) as CastData
	if cast == null:
		_fail("E2E-B: heavy_cast.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("E2E-B: enemy.tscn failed to load")
		return
	var tank := packed.instantiate() as Enemy
	tank.health = 3
	root.add_child(tank)
	var died_count: Array[int] = [0]
	tank.died.connect(func(_e: Enemy) -> void: died_count[0] += 1)
	var ctx := GameContext.new()
	ctx.instigator = null
	ctx.target = tank
	ctx.hit_pos = Vector3.ZERO
	ctx.hit_normal = Vector3.UP
	ctx.instigator_pos = Vector3(5.0, 0.0, 0.0)
	var targets: Array[Node] = cast.resolver.resolve(ctx)
	for t: Node in targets:
		for eff: Effect in cast.effects:
			eff.apply(t, ctx)
	_assert(died_count[0] == 1, "E2E-B: heavy_cast.tres amount=3 -> tank died in one cast")
