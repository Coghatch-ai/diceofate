# tools/smoke_health_component.gd — headless L2 smoke: HealthComponent slice-1 contract.
# Asserts:
#   1. apply_damage reduces _current correctly.
#   2. died emits exactly once at zero (idempotent dead guard).
#   3. health_changed payload: (current: int, max: int) — correct arity + values.
#   4. heal clamps to max_health.
#   5. get_health_percent() returns correct ratio.
#   6. Enemy.died(enemy) still emits via component (external contract preserved).
#   7. Enemy.on_hit() still aliases apply_damage(1) (bare-projectile seam).
# Run: $GODOT --headless --path . --script tools/smoke_health_component.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const GRUNT_SCENE := "res://entities/enemy/enemy.tscn"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== HEALTH COMPONENT SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_apply_damage_reduces_health()
	_test_died_emits_once_at_zero()
	_test_health_changed_payload()
	_test_heal_clamps()
	_test_get_health_percent()
	_test_enemy_died_external_signal()
	_test_enemy_on_hit_alias()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


## 1. apply_damage reduces _current.
func _test_apply_damage_reduces_health() -> void:
	print("\n[TEST] apply_damage reduces _current")
	var hc := HealthComponent.new()
	hc.max_health = 5
	root.add_child(hc)
	# _ready already ran via add_child; reset to sync _current.
	hc.reset()
	hc.apply_damage(2)
	@warning_ignore("unsafe_cast")
	var cur := hc.get("_current") as int
	_assert(cur == 3, "apply_damage(2) on max=5 → _current == 3 (got %d)" % cur)
	hc.queue_free()


## 2. died emits exactly once; second apply_damage after death is a no-op.
func _test_died_emits_once_at_zero() -> void:
	print("\n[TEST] died emits exactly once at zero (dead guard)")
	var hc := HealthComponent.new()
	hc.max_health = 1
	root.add_child(hc)
	hc.reset()
	var died_count: Array[int] = [0]
	hc.died.connect(func() -> void: died_count[0] += 1)
	hc.apply_damage(1)
	hc.apply_damage(1)  # should be no-op
	_assert(died_count[0] == 1, "died emitted exactly once (got %d)" % died_count[0])
	hc.queue_free()


## 3. health_changed fires with (current, max_health) arity + correct values.
func _test_health_changed_payload() -> void:
	print("\n[TEST] health_changed payload (current, max_health)")
	var hc := HealthComponent.new()
	hc.max_health = 4
	root.add_child(hc)
	hc.reset()
	var got_current: Array[int] = [-1]
	var got_max: Array[int] = [-1]
	hc.health_changed.connect(
		func(c: int, m: int) -> void:
			got_current[0] = c
			got_max[0] = m
	)
	hc.apply_damage(1)
	_assert(got_current[0] == 3, "health_changed current == 3 (got %d)" % got_current[0])
	_assert(got_max[0] == 4, "health_changed max == 4 (got %d)" % got_max[0])
	hc.queue_free()


## 4. heal clamps to max_health.
func _test_heal_clamps() -> void:
	print("\n[TEST] heal clamps to max_health")
	var hc := HealthComponent.new()
	hc.max_health = 3
	root.add_child(hc)
	hc.reset()
	hc.apply_damage(2)
	hc.heal(10)  # should clamp to 3
	@warning_ignore("unsafe_cast")
	var cur := hc.get("_current") as int
	_assert(cur == 3, "heal clamps to max_health=3 (got %d)" % cur)
	hc.queue_free()


## 5. get_health_percent() returns correct ratio.
func _test_get_health_percent() -> void:
	print("\n[TEST] get_health_percent() correct ratio")
	var hc := HealthComponent.new()
	hc.max_health = 4
	root.add_child(hc)
	hc.reset()
	hc.apply_damage(1)
	var pct: float = hc.get_health_percent()
	_assert(absf(pct - 0.75) < 0.001, "get_health_percent() == 0.75 (got %f)" % pct)
	hc.queue_free()


## 6. Enemy.died(enemy) still emits — external signal contract preserved.
func _test_enemy_died_external_signal() -> void:
	print("\n[TEST] Enemy.died(enemy) emits on fatal hit (external contract)")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("grunt root not Enemy class")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.health = 1
	root.add_child(e)
	var died_count: Array[int] = [0]
	var died_payload: Array = [null]
	e.died.connect(
		func(en: Enemy) -> void:
			died_count[0] += 1
			died_payload[0] = en
	)
	e.apply_damage(1)
	_assert(died_count[0] == 1, "Enemy.died emitted exactly once (got %d)" % died_count[0])
	# SEAM: died_payload is Array (Variant elements); cast to Node for comparison.
	@warning_ignore("unsafe_cast")
	var payload_node := died_payload[0] as Node
	_assert(payload_node == e, "Enemy.died payload is the enemy node (external 1-arg contract)")
	if is_instance_valid(e):
		e.queue_free()


## 7. Enemy.on_hit() aliases apply_damage(1) — bare-projectile seam.
func _test_enemy_on_hit_alias() -> void:
	print("\n[TEST] Enemy.on_hit() aliases apply_damage(1)")
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("grunt root not Enemy class")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.health = 2
	root.add_child(e)
	var died_count: Array[int] = [0]
	e.died.connect(func(_en: Enemy) -> void: died_count[0] += 1)
	e.on_hit()  # health 2 → 1, non-fatal
	_assert(died_count[0] == 0, "on_hit() non-fatal: died not emitted")
	e.on_hit()  # health 1 → 0, fatal
	_assert(died_count[0] == 1, "on_hit() fatal: died emitted once")
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
