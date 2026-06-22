# tools/smoke_status_effects.gd — headless smoke: status effects tick correctly.
# Run: $GODOT --headless --path . --script tools/smoke_status_effects.gd
extends SceneTree

const PASS: String = "SMOKE-STATUS: OK"
const FAIL_PREFIX: String = "SMOKE-STATUS: FAIL"

var _fail_count: int = 0
var _root_node: Node


func _init() -> void:
	_root_node = get_root()
	_run()
	if _fail_count == 0:
		print(PASS)
	else:
		print(FAIL_PREFIX + " — %d assertion(s) failed" % _fail_count)
	quit(_fail_count)


func _run() -> void:
	_test_damage_type_kinds()
	_test_burn_inactive_after_duration()
	_test_burn_poison_typed()
	_test_slow_emits_factor_then_restores()
	_test_shock_stuns_then_ends()
	_test_refresh_not_stack_burn()
	_test_refresh_not_stack_slow()
	_test_refresh_not_stack_shock()
	_test_resistance_applied_on_burn_tick()


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		print(FAIL_PREFIX + ": " + msg)
		_fail_count += 1


func _make_sr() -> StatusReceiver:
	var sr := StatusReceiver.new()
	_root_node.add_child(sr)
	return sr


func _test_damage_type_kinds() -> void:
	_assert(DamageType.Kind.PHYSICAL == 0, "PHYSICAL == 0")
	_assert(DamageType.Kind.FIRE == 1, "FIRE == 1")
	_assert(DamageType.Kind.ICE == 2, "ICE == 2")
	_assert(DamageType.Kind.ELECTRIC == 3, "ELECTRIC == 3")
	_assert(DamageType.Kind.POISON == 4, "POISON == 4")
	var hc := HealthComponent.new()
	hc.max_health = 10
	hc.resistances = {
		DamageType.Kind.ICE: 0.5,
		DamageType.Kind.ELECTRIC: 0.0,
		DamageType.Kind.POISON: 2.0,
	}
	_root_node.add_child(hc)
	hc._ready()
	hc.apply_damage(4, DamageType.Kind.ICE)
	_assert(hc.get_health_percent() == 0.8, "ICE resistance 0.5x halves damage")
	hc.apply_damage(100, DamageType.Kind.ELECTRIC)
	_assert(hc.get_health_percent() == 0.8, "ELECTRIC resistance 0 = immune")
	hc.apply_damage(2, DamageType.Kind.POISON)
	_assert(hc.get_health_percent() == 0.4, "POISON weakness 2.0x doubles damage")
	hc.queue_free()


func _test_burn_inactive_after_duration() -> void:
	var proxy := Node.new()
	_root_node.add_child(proxy)
	var sr := StatusReceiver.new()
	proxy.add_child(sr)
	sr.add_status_burn(2, 1.0, DamageType.Kind.FIRE)
	var elapsed: float = 0.0
	while elapsed < 1.1:
		sr._process(0.05)
		elapsed += 0.05
	_assert(not sr._burn_active, "burn inactive after duration")
	proxy.queue_free()


func _test_burn_poison_typed() -> void:
	var sr := _make_sr()
	sr.add_status_burn(1, 2.0, DamageType.Kind.POISON)
	_assert(sr._burn_active, "poison burn active")
	_assert(sr._burn_type == DamageType.Kind.POISON, "burn type is POISON")
	sr.queue_free()


func _test_slow_emits_factor_then_restores() -> void:
	var sr := _make_sr()
	# Use Array wrapper so lambda mutates shared reference (GDScript primitive capture is by value).
	var factors: Array[float] = []
	sr.slow_changed.connect(func(f: float) -> void: factors.append(f))
	sr.add_status_slow(0.4, 0.3)
	_assert(factors.size() == 1, "slow_changed emitted on apply")
	if factors.size() >= 1:
		var diff_a: float = factors[0] - 0.4
		_assert(diff_a > -0.001 and diff_a < 0.001, "slow factor 0.4 emitted")
	var elapsed: float = 0.0
	while elapsed < 0.4:
		sr._process(0.05)
		elapsed += 0.05
	_assert(not sr._slow_active, "slow inactive after duration")
	_assert(factors.size() == 2, "slow_changed emitted on expiry")
	if factors.size() >= 2:
		var diff_b: float = factors[1] - 1.0
		_assert(diff_b > -0.001 and diff_b < 0.001, "restore factor 1.0 emitted on expiry")
	sr.queue_free()


func _test_shock_stuns_then_ends() -> void:
	var sr := _make_sr()
	# Array wrappers for lambda mutation.
	var started: Array[int] = [0]
	var ended: Array[int] = [0]
	sr.shock_started.connect(func() -> void: started[0] += 1)
	sr.shock_ended.connect(func() -> void: ended[0] += 1)
	sr.add_status_shock(0.2)
	_assert(sr._shock_active, "shock active after add")
	_assert(started[0] == 1, "shock_started emitted once")
	var elapsed: float = 0.0
	while elapsed < 0.3:
		sr._process(0.05)
		elapsed += 0.05
	_assert(not sr._shock_active, "shock inactive after duration")
	_assert(ended[0] == 1, "shock_ended emitted once")
	sr.queue_free()


func _test_refresh_not_stack_burn() -> void:
	var sr := _make_sr()
	sr.add_status_burn(2, 1.0, DamageType.Kind.FIRE)
	sr._process(0.5)
	sr.add_status_burn(2, 1.0, DamageType.Kind.FIRE)
	var diff_bt: float = sr._burn_timer - 1.0
	_assert(diff_bt > -0.001 and diff_bt < 0.001, "burn timer reset on refresh")
	_assert(sr._burn_dps == 2, "burn dps unchanged on refresh")
	sr.queue_free()


func _test_refresh_not_stack_slow() -> void:
	var sr := _make_sr()
	var emit_count: Array[int] = [0]
	sr.slow_changed.connect(func(_f: float) -> void: emit_count[0] += 1)
	sr.add_status_slow(0.4, 1.0)
	sr._process(0.5)
	sr.add_status_slow(0.4, 1.0)
	var diff_st: float = sr._slow_timer - 1.0
	_assert(diff_st > -0.001 and diff_st < 0.001, "slow timer reset on refresh")
	_assert(emit_count[0] == 2, "slow_changed emitted on each apply (refresh)")
	sr.queue_free()


func _test_refresh_not_stack_shock() -> void:
	var sr := _make_sr()
	var start_count: Array[int] = [0]
	sr.shock_started.connect(func() -> void: start_count[0] += 1)
	sr.add_status_shock(0.5)
	sr._process(0.2)
	sr.add_status_shock(0.5)
	var diff_sht: float = sr._shock_timer - 0.5
	_assert(diff_sht > -0.001 and diff_sht < 0.001, "shock timer reset on refresh")
	_assert(start_count[0] == 1, "shock_started emitted only once on refresh")
	sr.queue_free()


func _test_resistance_applied_on_burn_tick() -> void:
	# StatusReceiver parented under HealthComponent → _tick_burn calls hc.apply_damage.
	# FIRE resistance 0.5. Use 20 dps so each 0.1s tick accumulates 2 → int(2)*0.5 = 1 net.
	# 10 ticks over 1.0s = ~10 net damage (with resistance). Without resistance = ~20.
	var hc := HealthComponent.new()
	hc.max_health = 200
	hc.resistances = {DamageType.Kind.FIRE: 0.5}
	_root_node.add_child(hc)
	hc._ready()
	var sr := StatusReceiver.new()
	hc.add_child(sr)
	sr.add_status_burn(20, 1.0, DamageType.Kind.FIRE)
	var elapsed: float = 0.0
	while elapsed < 1.1:
		sr._process(0.1)
		elapsed += 0.1
	var hp_lost: int = 200 - int(hc.get_health_percent() * 200.0)
	# Without resistance: ~20 dmg. With 0.5 resist: ~10. Accept 6–14 for rounding.
	_assert(
		hp_lost >= 6 and hp_lost <= 14,
		"fire resistance halves burn damage (got %d, want ~10)" % hp_lost
	)
	hc.queue_free()
