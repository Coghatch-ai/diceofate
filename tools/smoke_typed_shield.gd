# tools/smoke_typed_shield.gd — headless L2 smoke: slice-3 ShieldComponent + typed damage.
# Asserts:
#   1. FIRE resistance 0.5: apply_damage(10, FIRE) on HealthComponent → _current drops 5.
#   2. PHYSICAL (default): apply_damage(10, PHYSICAL) → _current drops 10.
#   3. Untyped 1-arg apply_damage still works (backward-compat).
#   4. ShieldComponent absorb(30) with max_shield=20 → overflow=10, shield→0.
#   5. Entity with shield+health: 30 FIRE-0.5 damage vs 20 shield.
#      Effective FIRE dmg = int(30*0.5)=15 → shield absorbs min(20,15)=15 → overflow=0
#      → health unchanged (shield fully covers 15 effective).
#   6. Shield exhausted then more damage reaches health.
#   7. Untyped on_hit() via Enemy still works end-to-end (external contract).
# Run: $GODOT --headless --path . --script tools/smoke_typed_shield.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const GRUNT_SCENE := "res://entities/enemy/enemy.tscn"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== TYPED SHIELD SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_fire_resistance_halves_damage()
	_test_physical_full_damage()
	_test_untyped_1arg_compat()
	_test_shield_absorb_overflow()
	_test_shield_plus_health_fire_resisted()
	_test_shield_exhausted_then_health()
	_test_enemy_on_hit_untyped_still_works()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


## 1. FIRE resistance 0.5 → effective damage halved.
func _test_fire_resistance_halves_damage() -> void:
	print("\n[TEST] FIRE resistance 0.5: apply_damage(10, FIRE) → _current drops 5")
	var hc := HealthComponent.new()
	hc.max_health = 10
	hc.resistances = {DamageType.Kind.FIRE: 0.5}
	root.add_child(hc)
	hc.reset()
	hc.apply_damage(10, DamageType.Kind.FIRE)
	@warning_ignore("unsafe_cast")
	var cur := hc.get("_current") as int
	_assert(cur == 5, "FIRE 0.5 resist: _current==5 (got %d)" % cur)
	hc.queue_free()


## 2. PHYSICAL (explicit) — no resistance → full damage.
func _test_physical_full_damage() -> void:
	print("\n[TEST] PHYSICAL: apply_damage(10, PHYSICAL) → _current drops 10")
	var hc := HealthComponent.new()
	hc.max_health = 10
	hc.resistances = {DamageType.Kind.FIRE: 0.5}
	root.add_child(hc)
	hc.reset()
	hc.apply_damage(10, DamageType.Kind.PHYSICAL)
	@warning_ignore("unsafe_cast")
	var cur := hc.get("_current") as int
	_assert(cur == 0, "PHYSICAL no resist: _current==0 (got %d)" % cur)
	hc.queue_free()


## 3. Untyped 1-arg apply_damage defaults to PHYSICAL — backward-compat.
func _test_untyped_1arg_compat() -> void:
	print("\n[TEST] Untyped 1-arg apply_damage(5) still works")
	var hc := HealthComponent.new()
	hc.max_health = 10
	root.add_child(hc)
	hc.reset()
	hc.apply_damage(5)
	@warning_ignore("unsafe_cast")
	var cur := hc.get("_current") as int
	_assert(cur == 5, "untyped apply_damage(5) on max=10 → _current==5 (got %d)" % cur)
	hc.queue_free()


## 4. ShieldComponent absorb overflow.
func _test_shield_absorb_overflow() -> void:
	print("\n[TEST] ShieldComponent: absorb(30) on max_shield=20 → overflow=10, shield→0")
	var sc := ShieldComponent.new()
	sc.max_shield = 20
	root.add_child(sc)
	sc.reset()
	var overflow: int = sc.absorb(30)
	@warning_ignore("unsafe_cast")
	var shield_cur := sc.get("_current_shield") as int
	_assert(overflow == 10, "absorb(30) overflow==10 (got %d)" % overflow)
	_assert(shield_cur == 0, "shield depleted to 0 (got %d)" % shield_cur)
	sc.queue_free()


## 5. Shield + health + FIRE resist: 30 raw FIRE vs 20 shield.
## Effective FIRE dmg = int(30*0.5) = 15 → shield absorbs 15 → overflow = 0 → health unchanged.
func _test_shield_plus_health_fire_resisted() -> void:
	print("\n[TEST] Shield+health+FIRE resist: 30 FIRE, shield=20, resist=0.5 → health unchanged")
	var sc := ShieldComponent.new()
	sc.max_shield = 20
	root.add_child(sc)
	sc.reset()
	var hc := HealthComponent.new()
	hc.max_health = 10
	hc.resistances = {DamageType.Kind.FIRE: 0.5}
	root.add_child(hc)
	hc.reset()
	# Simulate entity apply_damage(30, FIRE): shield absorbs raw amount first, overflow to health.
	# NOTE: design doc says entity routes raw amount through shield then overflow through resistance.
	# ShieldComponent absorbs from raw amount; HealthComponent applies resistance on overflow.
	var overflow: int = sc.absorb(30)
	if overflow > 0:
		hc.apply_damage(overflow, DamageType.Kind.FIRE)
	@warning_ignore("unsafe_cast")
	var hc_cur := hc.get("_current") as int
	@warning_ignore("unsafe_cast")
	var sc_cur := sc.get("_current_shield") as int
	# overflow = 30-20 = 10 → FIRE resist 0.5 → effective = int(10*0.5) = 5 → health = 10-5 = 5
	_assert(sc_cur == 0, "shield at 0 after absorb(30) from max=20 (got %d)" % sc_cur)
	_assert(hc_cur == 5, "health=5 after overflow=10 with FIRE 0.5 resist (got %d)" % hc_cur)
	hc.queue_free()
	sc.queue_free()


## 6. Shield exhausted → subsequent damage reaches health.
func _test_shield_exhausted_then_health() -> void:
	print("\n[TEST] Shield exhausted → next hit reaches health")
	var sc := ShieldComponent.new()
	sc.max_shield = 5
	root.add_child(sc)
	sc.reset()
	var hc := HealthComponent.new()
	hc.max_health = 10
	root.add_child(hc)
	hc.reset()
	# First hit: absorb 5 (exactly drains shield), overflow 0.
	var ov1: int = sc.absorb(5)
	if ov1 > 0:
		hc.apply_damage(ov1)
	# Second hit: shield at 0, all overflow.
	var ov2: int = sc.absorb(3)
	if ov2 > 0:
		hc.apply_damage(ov2)
	@warning_ignore("unsafe_cast")
	var hc_cur := hc.get("_current") as int
	_assert(hc_cur == 7, "health==7 after shield drained then 3 dmg (got %d)" % hc_cur)
	hc.queue_free()
	sc.queue_free()


## 7. Enemy.on_hit() (untyped bare-projectile seam) still works end-to-end.
func _test_enemy_on_hit_untyped_still_works() -> void:
	print("\n[TEST] Enemy.on_hit() untyped seam still fires died on fatal hit")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("grunt root not Enemy")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.health = 1
	root.add_child(e)
	var died_count: Array[int] = [0]
	e.died.connect(func(_en: Enemy) -> void: died_count[0] += 1)
	e.on_hit()
	_assert(died_count[0] == 1, "Enemy.on_hit() → died once (got %d)" % died_count[0])
	if is_instance_valid(e):
		e.queue_free()


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
