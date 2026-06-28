# tools/lib/status_receiver.gd — ticks active status effects (burn/slow/shock) per frame.
class_name StatusReceiver
extends Node
## Composition child. Effects call add_status_X() to START a status (stateless start);
## this node owns the timer state and ticks outcomes each _process frame.
## Signals up; parent wires slow_changed / shock_started / shock_ended to its own seams.
## Refresh-not-stack: re-applying a status resets its timer, no stacking math.

## Emitted when slow factor changes. factor < 1.0 = slowed; factor == 1.0 = restored.
signal slow_changed(factor: float)
## Emitted when shock/stun begins.
signal shock_started
## Emitted when shock/stun ends.
signal shock_ended
## Emitted when burn/poison starts. is_poison true = POISON type (green aura).
signal burn_started(is_poison: bool)
## Emitted when burn/poison ends (timer expired, not refresh).
signal burn_ended

# ── Burn state ────────────────────────────────────────────────────────────────
var _burn_active: bool = false
var _burn_dps: int = 0
var _burn_duration: float = 0.0
var _burn_timer: float = 0.0
var _burn_type: DamageType.Kind = DamageType.Kind.FIRE
# Fractional damage accumulator so integer ticks don't lose sub-integer remainder.
var _burn_accum: float = 0.0

# ── Slow state ────────────────────────────────────────────────────────────────
var _slow_active: bool = false
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0

# ── Shock state ───────────────────────────────────────────────────────────────
var _shock_active: bool = false
var _shock_timer: float = 0.0


func _process(delta: float) -> void:
	_tick_burn(delta)
	_tick_slow(delta)
	_tick_shock(delta)


# ── Public API (called by BurnEffect / SlowEffect / ShockEffect via duck-typed seam) ──


## Start or refresh a burn/poison DoT. Re-calling resets the timer (no stack).
func add_status_burn(dps: int, duration: float, type: DamageType.Kind) -> void:
	var was_active: bool = _burn_active
	_burn_dps = dps
	_burn_duration = duration
	_burn_timer = duration
	_burn_type = type
	_burn_accum = 0.0
	_burn_active = true
	if not was_active:
		burn_started.emit(type == DamageType.Kind.POISON)


## Start or refresh a movement slow. Re-calling resets timer and emits new factor.
func add_status_slow(factor: float, duration: float) -> void:
	var was_active: bool = _slow_active
	_slow_factor = factor
	_slow_timer = duration
	_slow_active = true
	# Always emit so parent re-applies the factor even on refresh.
	slow_changed.emit(_slow_factor)
	if not was_active:
		pass  # first apply — factor already emitted above


## Start or refresh a shock/stun. Re-calling resets timer.
func add_status_shock(duration: float) -> void:
	var was_active: bool = _shock_active
	_shock_timer = duration
	_shock_active = true
	if not was_active:
		shock_started.emit()


## Register a timed buff expiry. On timer end calls stat_block.remove_all_from_source(source).
func add_status_buff(stat_block: StatBlock, source: StringName, duration: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(stat_block.remove_all_from_source.bind(source))


# ── Tick helpers ──────────────────────────────────────────────────────────────


func _tick_burn(delta: float) -> void:
	if not _burn_active:
		return
	_burn_timer -= delta
	if _burn_timer <= 0.0:
		_burn_active = false
		_burn_accum = 0.0
		burn_ended.emit()
		return
	# Accumulate fractional damage; apply whole-integer ticks to preserve remainder.
	_burn_accum += float(_burn_dps) * delta
	var ticks: int = int(_burn_accum)
	if ticks > 0:
		_burn_accum -= float(ticks)
		var parent: Node = get_parent()
		if parent != null and parent.has_method("apply_damage"):
			# SEAM: apply_damage(amount, type) proven by has_method; duck-typed.
			@warning_ignore("unsafe_method_access")
			parent.apply_damage(ticks, _burn_type)


func _tick_slow(delta: float) -> void:
	if not _slow_active:
		return
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_active = false
		_slow_factor = 1.0
		slow_changed.emit(1.0)


func _tick_shock(delta: float) -> void:
	if not _shock_active:
		return
	_shock_timer -= delta
	if _shock_timer <= 0.0:
		_shock_active = false
		shock_ended.emit()
