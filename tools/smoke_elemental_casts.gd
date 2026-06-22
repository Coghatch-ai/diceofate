# tools/smoke_elemental_casts.gd — headless L2 smoke: elemental cast slice B contract.
# Asserts: each of the 5 casts loads with expected element (damage_type + status effect + color);
# firing each effect applies the status to a stub StatusReceiver.
# Run: $GODOT --headless --path . --script tools/smoke_elemental_casts.gd
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
# Named callbacks for tests 10/11 (lambdas are deferred on orphan nodes in headless).
var _t10_fired: bool = false
var _t10_poison: bool = false
var _t11_ended: bool = false


func _initialize() -> void:
	print("=== ELEMENTAL CASTS SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_pistol_cast_electric()
	_test_heavy_cast_fire()
	_test_stun_cast_ice()
	_test_blast_cast_poison()
	_test_rapid_cast_kinetic()
	_test_shock_effect_calls_stub()
	_test_burn_effect_fire_calls_stub()
	_test_slow_effect_calls_stub()
	_test_burn_effect_poison_calls_stub()
	_test_status_receiver_burn_signal()
	_test_status_receiver_burn_ended_signal()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


# ── helpers ───────────────────────────────────────────────────────────────────


func _on_t10_burn_started(is_poison: bool) -> void:
	_t10_fired = true
	_t10_poison = is_poison


func _on_t11_burn_ended() -> void:
	_t11_ended = true


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


func _make_ctx(target: Node) -> GameContext:
	var ctx := GameContext.new()
	ctx.instigator = null
	ctx.target = target
	ctx.hit_pos = Vector3.ZERO
	ctx.hit_normal = Vector3.UP
	ctx.instigator_pos = Vector3.ZERO
	return ctx


## Minimal stub: tracks apply_damage + status seams.
class StubTarget:
	extends Node
	var damage_received: int = 0
	var burn_dps: int = 0
	var burn_duration: float = 0.0
	var burn_type: int = -1
	var slow_factor: float = 0.0
	var slow_duration: float = 0.0
	var shock_duration: float = 0.0

	func apply_damage(amount: int, _type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
		damage_received += amount

	func add_status_burn(dps: int, duration: float, type: DamageType.Kind) -> void:
		burn_dps = dps
		burn_duration = duration
		burn_type = type as int

	func add_status_slow(factor: float, duration: float) -> void:
		slow_factor = factor
		slow_duration = duration

	func add_status_shock(duration: float) -> void:
		shock_duration = duration


## Load a CastData .tres; return null + fail if load fails.
func _load_cast(path: String) -> CastData:
	var res: Resource = load(path)
	if not res is CastData:
		_fail("load %s" % path)
		return null
	return res as CastData


## Return the first Effect of a given class in the effects array; null if absent.
func _find_effect(cast: CastData, class_name_str: String) -> Effect:
	for eff: Effect in cast.effects:
		# SEAM: get_script() returns Variant; cast to GDScript to access get_global_name().
		@warning_ignore("unsafe_cast")
		var scr: GDScript = eff.get_script() as GDScript
		if scr != null and scr.get_global_name() == class_name_str:
			return eff
	return null


## Return the DamageEffect in the effects array; null if absent.
func _find_damage_effect(cast: CastData) -> DamageEffect:
	var eff: Effect = _find_effect(cast, "DamageEffect")
	if eff is DamageEffect:
		return eff as DamageEffect
	return null


# ── tests ─────────────────────────────────────────────────────────────────────


## 1. pistol_cast: damage_type=ELECTRIC, yellow color, ShockEffect present.
func _test_pistol_cast_electric() -> void:
	print("\n[TEST] pistol_cast: ELECTRIC + yellow + ShockEffect")
	var cast: CastData = _load_cast(PISTOL_CAST)
	if cast == null:
		return
	var de: DamageEffect = _find_damage_effect(cast)
	_assert(de != null, "pistol_cast has DamageEffect")
	if de != null:
		_assert(
			de.damage_type == DamageType.Kind.ELECTRIC,
			"pistol_cast damage_type == ELECTRIC (%d)" % de.damage_type
		)
	_assert(
		cast.bullet_color.r > 0.9 and cast.bullet_color.g > 0.9 and cast.bullet_color.b < 0.1,
		"pistol_cast bullet_color yellow (1,1,0)"
	)
	_assert(_find_effect(cast, "ShockEffect") != null, "pistol_cast has ShockEffect")


## 2. heavy_cast: damage_type=FIRE, red color, BurnEffect with type=FIRE present.
func _test_heavy_cast_fire() -> void:
	print("\n[TEST] heavy_cast: FIRE + red + BurnEffect(FIRE)")
	var cast: CastData = _load_cast(HEAVY_CAST)
	if cast == null:
		return
	var de: DamageEffect = _find_damage_effect(cast)
	_assert(de != null, "heavy_cast has DamageEffect")
	if de != null:
		_assert(
			de.damage_type == DamageType.Kind.FIRE,
			"heavy_cast damage_type == FIRE (%d)" % de.damage_type
		)
	_assert(
		cast.bullet_color.r > 0.9 and cast.bullet_color.g < 0.3 and cast.bullet_color.b < 0.3,
		"heavy_cast bullet_color red"
	)
	var be: Effect = _find_effect(cast, "BurnEffect")
	_assert(be != null, "heavy_cast has BurnEffect")
	if be is BurnEffect:
		_assert(
			(be as BurnEffect).damage_type == DamageType.Kind.FIRE,
			"heavy_cast BurnEffect damage_type == FIRE"
		)
	_assert(cast.pierces_barriers, "heavy_cast pierces_barriers still true")


## 3. stun_cast: damage_type=ICE, blue color, SlowEffect present.
func _test_stun_cast_ice() -> void:
	print("\n[TEST] stun_cast: ICE + blue + SlowEffect")
	var cast: CastData = _load_cast(STUN_CAST)
	if cast == null:
		return
	var de: DamageEffect = _find_damage_effect(cast)
	_assert(de != null, "stun_cast has DamageEffect")
	if de != null:
		_assert(
			de.damage_type == DamageType.Kind.ICE,
			"stun_cast damage_type == ICE (%d)" % de.damage_type
		)
	_assert(cast.bullet_color.b > 0.8 and cast.bullet_color.r < 0.5, "stun_cast bullet_color blue")
	_assert(_find_effect(cast, "SlowEffect") != null, "stun_cast has SlowEffect")


## 4. blast_cast: POISON, green color, BurnEffect(POISON), keeps RadiusTargetResolver.
func _test_blast_cast_poison() -> void:
	print("\n[TEST] blast_cast: POISON + green + BurnEffect(POISON) + RadiusResolver")
	var cast: CastData = _load_cast(BLAST_CAST)
	if cast == null:
		return
	var de: DamageEffect = _find_damage_effect(cast)
	_assert(de != null, "blast_cast has DamageEffect")
	if de != null:
		_assert(
			de.damage_type == DamageType.Kind.POISON,
			"blast_cast damage_type == POISON (%d)" % de.damage_type
		)
	_assert(
		cast.bullet_color.g > 0.7 and cast.bullet_color.r < 0.6 and cast.bullet_color.b < 0.3,
		"blast_cast bullet_color green"
	)
	var be: Effect = _find_effect(cast, "BurnEffect")
	_assert(be != null, "blast_cast has BurnEffect")
	if be is BurnEffect:
		_assert(
			(be as BurnEffect).damage_type == DamageType.Kind.POISON,
			"blast_cast BurnEffect damage_type == POISON"
		)
	_assert(cast.resolver is RadiusTargetResolver, "blast_cast keeps RadiusTargetResolver")


## 5. rapid_cast: damage_type=PHYSICAL, white color, no status effect.
func _test_rapid_cast_kinetic() -> void:
	print("\n[TEST] rapid_cast: PHYSICAL + white + no status effect")
	var cast: CastData = _load_cast(RAPID_CAST)
	if cast == null:
		return
	var de: DamageEffect = _find_damage_effect(cast)
	_assert(de != null, "rapid_cast has DamageEffect")
	if de != null:
		_assert(
			de.damage_type == DamageType.Kind.PHYSICAL,
			"rapid_cast damage_type == PHYSICAL (%d)" % de.damage_type
		)
	_assert(
		cast.bullet_color.r > 0.9 and cast.bullet_color.g > 0.9 and cast.bullet_color.b > 0.9,
		"rapid_cast bullet_color white"
	)
	_assert(_find_effect(cast, "ShockEffect") == null, "rapid_cast no ShockEffect")
	_assert(_find_effect(cast, "BurnEffect") == null, "rapid_cast no BurnEffect")
	_assert(_find_effect(cast, "SlowEffect") == null, "rapid_cast no SlowEffect")


## 6. ShockEffect.apply() calls add_status_shock on stub.
func _test_shock_effect_calls_stub() -> void:
	print("\n[TEST] ShockEffect.apply() calls add_status_shock")
	var cast: CastData = _load_cast(PISTOL_CAST)
	if cast == null:
		return
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub)
	var se: Effect = _find_effect(cast, "ShockEffect")
	if se == null:
		_fail("pistol_cast ShockEffect not found for apply test")
		stub.queue_free()
		return
	se.apply(stub, ctx)
	_assert(stub.shock_duration > 0.0, "ShockEffect applied stun_duration > 0 to stub")
	stub.queue_free()


## 7. BurnEffect(FIRE) apply() calls add_status_burn with FIRE type.
func _test_burn_effect_fire_calls_stub() -> void:
	print("\n[TEST] BurnEffect(FIRE) apply() calls add_status_burn(FIRE)")
	var cast: CastData = _load_cast(HEAVY_CAST)
	if cast == null:
		return
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub)
	var be: Effect = _find_effect(cast, "BurnEffect")
	if be == null:
		_fail("heavy_cast BurnEffect not found for apply test")
		stub.queue_free()
		return
	be.apply(stub, ctx)
	_assert(stub.burn_dps > 0, "BurnEffect(FIRE) applied dps > 0")
	_assert(stub.burn_type == DamageType.Kind.FIRE as int, "BurnEffect(FIRE) type == FIRE")
	stub.queue_free()


## 8. SlowEffect.apply() calls add_status_slow on stub.
func _test_slow_effect_calls_stub() -> void:
	print("\n[TEST] SlowEffect.apply() calls add_status_slow")
	var cast: CastData = _load_cast(STUN_CAST)
	if cast == null:
		return
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub)
	var se: Effect = _find_effect(cast, "SlowEffect")
	if se == null:
		_fail("stun_cast SlowEffect not found for apply test")
		stub.queue_free()
		return
	se.apply(stub, ctx)
	_assert(
		stub.slow_factor > 0.0 and stub.slow_factor < 1.0,
		"SlowEffect applied factor in (0,1) to stub"
	)
	_assert(stub.slow_duration > 0.0, "SlowEffect applied duration > 0 to stub")
	stub.queue_free()


## 9. BurnEffect(POISON) apply() calls add_status_burn with POISON type.
func _test_burn_effect_poison_calls_stub() -> void:
	print("\n[TEST] BurnEffect(POISON) apply() calls add_status_burn(POISON)")
	var cast: CastData = _load_cast(BLAST_CAST)
	if cast == null:
		return
	var stub := StubTarget.new()
	root.add_child(stub)
	var ctx := _make_ctx(stub)
	var be: Effect = _find_effect(cast, "BurnEffect")
	if be == null:
		_fail("blast_cast BurnEffect not found for apply test")
		stub.queue_free()
		return
	be.apply(stub, ctx)
	_assert(stub.burn_dps > 0, "BurnEffect(POISON) applied dps > 0")
	_assert(stub.burn_type == DamageType.Kind.POISON as int, "BurnEffect(POISON) type == POISON")
	stub.queue_free()


## 10. StatusReceiver emits burn_started when add_status_burn first called.
func _test_status_receiver_burn_signal() -> void:
	print("\n[TEST] StatusReceiver.burn_started emitted on first burn")
	# Named method (not lambda) — lambdas on orphan nodes are deferred in headless Godot 4.
	_t10_fired = false
	_t10_poison = false
	var sr := StatusReceiver.new()
	sr.burn_started.connect(_on_t10_burn_started)
	sr.add_status_burn(2, 3.0, DamageType.Kind.FIRE)
	_assert(_t10_fired, "burn_started signal fired on first burn")
	_assert(not _t10_poison, "burn_started is_poison=false for FIRE type")
	sr.free()


## 11. StatusReceiver emits burn_ended after timer expires.
func _test_status_receiver_burn_ended_signal() -> void:
	print("\n[TEST] StatusReceiver.burn_ended emitted after expiry")
	_t11_ended = false
	var sr := StatusReceiver.new()
	sr.burn_ended.connect(_on_t11_burn_ended)
	# Set very short duration and tick past it manually.
	sr.add_status_burn(1, 0.01, DamageType.Kind.POISON)
	# Tick enough to expire (process with large delta).
	sr._tick_burn(1.0)
	_assert(_t11_ended, "burn_ended signal fired after expiry")
	sr.free()
