# tools/smoke_player_health.gd — headless smoke: player HP model (slice 2).
# Asserts: touch applies 25 dmg, HP→0 triggers died, pickup heals, health_changed drives HUD.
# Exit 0 = pass. Exit 1 = fail (prints reason).
extends SceneTree

const TOUCH_DMG: int = 25
const HEAL_AMT: int = 40
const MAX_HP: int = 100

# Counters written by signal callbacks — must be instance vars (not locals)
# so GDScript closures capture the correct reference.
var _changed_count: int = 0
var _last_cur: int = -1
var _last_max: int = -1
var _died_count: int = 0
var _arity_cur: int = -1
var _arity_max: int = -1


func _init() -> void:
	_run()
	quit(0)


func _run() -> void:
	# ── 1. HealthComponent basic contract ────────────────────────────────────
	var hc: HealthComponent = HealthComponent.new()
	hc.max_health = MAX_HP
	hc.reset()

	hc.health_changed.connect(_on_health_changed)
	hc.died.connect(_on_died)

	# Single touch: 100 → 75.
	hc.apply_damage(TOUCH_DMG)
	_assert(hc._current == 75, "after 1 touch: expected 75, got %d" % hc._current)
	_assert(_changed_count == 1, "health_changed not emitted on touch")
	_assert(_last_cur == 75, "health_changed current wrong: %d" % _last_cur)
	_assert(_last_max == MAX_HP, "health_changed max wrong: %d" % _last_max)

	# Pickup heal: 75 → 100 (clamp to max).
	_changed_count = 0
	hc.heal(HEAL_AMT)
	_assert(hc._current == 100, "after heal: expected 100, got %d" % hc._current)
	_assert(_changed_count == 1, "health_changed not emitted on heal")

	# Heal beyond max clamps: 100 + 40 → 100.
	_changed_count = 0
	hc.heal(HEAL_AMT)
	_assert(hc._current == MAX_HP, "over-heal should clamp to max_health")

	# 4 touches → 0 HP → died emitted exactly once.
	hc.apply_damage(TOUCH_DMG)
	hc.apply_damage(TOUCH_DMG)
	hc.apply_damage(TOUCH_DMG)
	hc.apply_damage(TOUCH_DMG)
	_assert(hc._current == 0, "after 4 touches: expected 0, got %d" % hc._current)
	_assert(_died_count == 1, "died should fire exactly once, fired %d" % _died_count)

	# Re-entry guard: extra damage after dead must not re-emit died.
	hc.apply_damage(TOUCH_DMG)
	_assert(_died_count == 1, "died re-emitted after dead — guard broken")

	# ── 2. heal is no-op when dead ───────────────────────────────────────────
	_changed_count = 0
	hc.heal(HEAL_AMT)
	_assert(hc._current == 0, "heal on dead component changed HP")
	_assert(_changed_count == 0, "health_changed emitted on dead heal")

	# ── 3. health_changed arity: (current: int, max_health: int) ─────────────
	var hc2: HealthComponent = HealthComponent.new()
	hc2.max_health = 50
	hc2.reset()
	hc2.health_changed.connect(_on_arity_check)
	hc2.apply_damage(10)
	_assert(_arity_cur == 40, "health_changed arity cur wrong: %d" % _arity_cur)
	_assert(_arity_max == 50, "health_changed arity max wrong: %d" % _arity_max)

	print("smoke_player_health: PASS")


func _on_health_changed(cur: int, mx: int) -> void:
	_changed_count += 1
	_last_cur = cur
	_last_max = mx


func _on_died() -> void:
	_died_count += 1


func _on_arity_check(cur: int, mx: int) -> void:
	_arity_cur = cur
	_arity_max = mx


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		push_error("smoke_player_health: FAIL — %s" % msg)
		quit(1)
