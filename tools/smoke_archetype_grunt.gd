# tools/smoke_archetype_grunt.gd — headless L2 smoke: EnemyArchetype slice-1 contract.
# Asserts:
#   1. grunt.tres loads as EnemyArchetype with expected stat values.
#   2. Enemy with grunt archetype assigned has HealthComponent.max_health == archetype.max_health.
#   3. 2 hits on a grunt-archetype enemy → died fires exactly once.
#   4. score_value on the enemy matches archetype.score_value.
#   5. Abilities node present and empty (no behaviours for grunt).
# Run: $GODOT --headless --path . --script tools/smoke_archetype_grunt.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const GRUNT_SCENE := "res://entities/enemy/enemy.tscn"
const GRUNT_ARCHETYPE := "res://archetypes/grunt.tres"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false


func _initialize() -> void:
	print("=== ARCHETYPE GRUNT SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3 and not _done:
		_done = true
		_run_all()
	return false


func _run_all() -> void:
	_test_archetype_loads()
	_test_health_seeded_from_archetype()
	_test_two_hits_fires_died()
	_test_score_matches_archetype()
	_test_abilities_node_present()
	print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


## 1. grunt.tres loads with expected stats.
func _test_archetype_loads() -> void:
	print("\n[TEST] grunt.tres loads as EnemyArchetype")
	var arch := load(GRUNT_ARCHETYPE)
	if not arch is EnemyArchetype:
		_fail("grunt.tres did not load as EnemyArchetype (got %s)" % type_string(typeof(arch)))
		return
	var a := arch as EnemyArchetype
	_assert(a.max_health == 2, "grunt max_health == 2 (got %d)" % a.max_health)
	_assert(a.score_value == 1, "grunt score_value == 1 (got %d)" % a.score_value)
	_assert(a.behaviours.is_empty(), "grunt behaviours empty (got %d)" % a.behaviours.size())


## 2. Enemy with grunt archetype → HealthComponent.max_health seeded correctly.
func _test_health_seeded_from_archetype() -> void:
	print("\n[TEST] HealthComponent.max_health seeded from archetype")
	var arch := load(GRUNT_ARCHETYPE) as EnemyArchetype
	if arch == null:
		_fail("grunt.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("enemy.tscn root not Enemy")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.archetype = arch
	root.add_child(e)
	# _ready() ran — HealthComponent.max_health should equal archetype.max_health.
	var hc := e.get_node_or_null("HealthComponent") as HealthComponent
	if hc == null:
		_fail("HealthComponent node not found on enemy")
		e.queue_free()
		return
	_assert(
		hc.max_health == arch.max_health,
		"hc.max_health == arch.max_health (%d == %d)" % [hc.max_health, arch.max_health]
	)
	if is_instance_valid(e):
		e.queue_free()


## 3. 2 hits on grunt-archetype enemy → died fires exactly once.
func _test_two_hits_fires_died() -> void:
	print("\n[TEST] 2 hits → died fires exactly once")
	var arch := load(GRUNT_ARCHETYPE) as EnemyArchetype
	if arch == null:
		_fail("grunt.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("enemy.tscn root not Enemy")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.archetype = arch
	root.add_child(e)
	var died_count: Array[int] = [0]
	e.died.connect(func(_en: Enemy) -> void: died_count[0] += 1)
	e.on_hit()  # hit 1 — non-fatal (max_health == 2)
	_assert(died_count[0] == 0, "after hit 1: died not yet fired")
	e.on_hit()  # hit 2 — fatal
	_assert(died_count[0] == 1, "after hit 2: died fired exactly once (got %d)" % died_count[0])
	if is_instance_valid(e):
		e.queue_free()


## 4. score_value on enemy matches archetype.score_value after _ready().
func _test_score_matches_archetype() -> void:
	print("\n[TEST] enemy.score_value matches archetype after _ready()")
	var arch := load(GRUNT_ARCHETYPE) as EnemyArchetype
	if arch == null:
		_fail("grunt.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("enemy.tscn root not Enemy")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.archetype = arch
	root.add_child(e)
	_assert(
		e.score_value == arch.score_value,
		"score_value == arch.score_value (%d == %d)" % [e.score_value, arch.score_value]
	)
	if is_instance_valid(e):
		e.queue_free()


## 5. Abilities node present and has no children (grunt has no behaviours).
func _test_abilities_node_present() -> void:
	print("\n[TEST] Abilities node present + empty for grunt")
	var arch := load(GRUNT_ARCHETYPE) as EnemyArchetype
	if arch == null:
		_fail("grunt.tres failed to load")
		return
	var packed := load(GRUNT_SCENE) as PackedScene
	if packed == null:
		_fail("enemy.tscn failed to load")
		return
	var inst := packed.instantiate()
	if not inst is Enemy:
		_fail("enemy.tscn root not Enemy")
		inst.queue_free()
		return
	var e := inst as Enemy
	e.archetype = arch
	root.add_child(e)
	var abilities := e.get_node_or_null("Abilities")
	_assert(abilities != null, "Abilities node exists on enemy")
	if abilities != null:
		_assert(
			abilities.get_child_count() == 0,
			"Abilities has 0 children for grunt (got %d)" % abilities.get_child_count()
		)
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
