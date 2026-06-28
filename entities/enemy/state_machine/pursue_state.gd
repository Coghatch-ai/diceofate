# entities/enemy/state_machine/pursue_state.gd — cap-aware player pursuit with active fallback.
# At most enemy.pursue_cap enemies pursue simultaneously (static counter shared across all
# instances; 0 = unlimited). Cap-blocked enemies ADVANCE toward the player at a reduced speed
# (blocked_advance_speed) instead of standing idle — ensuring all enemies are always active.
# Debug trace: set project setting debug/enemy_trace = true to log per-enemy state each frame.
class_name PursueState
extends EnemyState

## Repath interval in seconds — throttled so nav server isn't queried every frame.
const REPATH_INTERVAL: float = 0.25
## How often a blocked enemy retries the cap check (hysteresis — prevents rapid toggle).
const RECHECK_INTERVAL: float = 1.0
## Debug trace log interval in seconds (only when debug/enemy_trace is true).
const TRACE_INTERVAL: float = 0.5

## Shared count of enemies currently in the active-pursue slot (not blocked).
static var _pursuing_count: int = 0

var _repath_accum: float = 0.0
# Same one-tick nav race guard as ChaseState.
var _destination_just_set: bool = false
# True when this enemy tried to enter pursue but the cap was full.
var _blocked: bool = false
var _recheck_accum: float = 0.0
# Debug trace accumulator.
var _trace_accum: float = 0.0


func enter() -> void:
	_blocked = false
	_recheck_accum = 0.0
	_trace_accum = TRACE_INTERVAL  # log immediately on entry
	var cap: int = enemy.pursue_cap
	if cap > 0 and _pursuing_count >= cap:
		# Cap full — advance toward player at reduced speed instead of standing still.
		_blocked = true
		_trace_log(
			"BLOCKED cap=%d/%d — advancing at blocked_advance_speed" % [_pursuing_count, cap]
		)
		return
	_pursuing_count += 1
	_repath_accum = REPATH_INTERVAL
	_trace_log("ACTIVE pursuing_count now %d" % _pursuing_count)


func exit() -> void:
	if not _blocked:
		_pursuing_count = maxi(_pursuing_count - 1, 0)
	_blocked = false


func physics_update(delta: float) -> String:
	if _blocked:
		# Recheck cap periodically — claim a slot if one opened.
		_recheck_accum += delta
		if _recheck_accum >= RECHECK_INTERVAL:
			_recheck_accum = 0.0
			var cap: int = enemy.pursue_cap
			if cap <= 0 or _pursuing_count < cap:
				# Slot opened — claim it without re-entering (already in state).
				_pursuing_count += 1
				_blocked = false
				_repath_accum = REPATH_INTERVAL
				_trace_log("UNBLOCKED — claimed slot, pursuing_count=%d" % _pursuing_count)

		# Advance toward player at reduced speed (blocked fallback — never a statue).
		var blocked_target: Node3D = enemy.target()
		if blocked_target != null:
			_repath_accum += delta
			if _repath_accum >= REPATH_INTERVAL:
				_repath_accum = 0.0
				enemy.set_destination(blocked_target.global_position)
				_destination_just_set = true
			if _destination_just_set:
				_destination_just_set = false
				return ""
			enemy.move_along_path(enemy.blocked_advance_speed, delta)
		else:
			enemy.stop(delta)

		_trace_accum += delta
		if _trace_accum >= TRACE_INTERVAL:
			_trace_accum = 0.0
			var dist: float = enemy.distance_to_target()
			var path_dist: float = (
				enemy.nav.distance_to_target() if not enemy.navigation_finished() else 0.0
			)
			_trace_log(
				(
					"BLOCKED-ADVANCING dist=%.1f nav_path_dist=%.1f pursuing_count=%d cap=%d"
					% [dist, path_dist, _pursuing_count, enemy.pursue_cap]
				)
			)
		return ""

	var t: Node3D = enemy.target()
	# Player gone (dead/unloaded) — stop and wait.
	if t == null:
		enemy.stop(delta)
		return ""

	# In attack range — hand off to AttackState.
	if enemy.distance_to_target() <= enemy.attack_range:
		return "AttackState"

	# Throttle repath.
	_repath_accum += delta
	if _repath_accum >= REPATH_INTERVAL:
		_repath_accum = 0.0
		enemy.set_destination(t.global_position)
		_destination_just_set = true

	# Give nav server one tick to compute path after set_destination.
	if _destination_just_set:
		_destination_just_set = false
		return ""

	_trace_accum += delta
	if _trace_accum >= TRACE_INTERVAL:
		_trace_accum = 0.0
		var dist: float = enemy.distance_to_target()
		var path_dist: float = (
			enemy.nav.distance_to_target() if not enemy.navigation_finished() else 0.0
		)
		_trace_log(
			(
				"ACTIVE-PURSUING dist=%.1f nav_path_dist=%.1f pursuing_count=%d"
				% [dist, path_dist, _pursuing_count]
			)
		)

	enemy.move_along_path(enemy.move_speed, delta)
	return ""


## Emit a debug trace line when debug/enemy_trace is enabled.
func _trace_log(msg: String) -> void:
	if not ProjectSettings.get_setting("debug/enemy_trace", false):
		return
	print("[EnemyTrace][%s][PursueState] %s" % [enemy.name, msg])
