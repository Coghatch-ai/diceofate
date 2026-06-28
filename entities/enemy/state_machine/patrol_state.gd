# entities/enemy/state_machine/patrol_state.gd — walk to entry waypoint; hand off to pursuit.
# Enemies enter here on spawn and walk toward the assigned quadrant waypoint.
# On arrival (or on player sighting), transitions to PursueState for active hunting.
# Debug trace: set project setting debug/enemy_trace = true to log per-enemy state each frame.
class_name PatrolState
extends EnemyState

## Debug trace log interval in seconds (only when debug/enemy_trace is true).
const TRACE_INTERVAL: float = 1.0

# Guard: NavigationAgent3D.is_navigation_finished() returns true on the same frame
# target_position is set (path not yet computed by the nav server). Skip the finished
# check for one physics frame after each set_destination() call.
var _destination_just_set: bool = false
# Set when enter() fires before enemy._ready() has populated patrol_waypoints (runtime
# spawn race: StateMachine._ready() calls enter() before Enemy._ready() resolves NodePaths).
# physics_update retries _go_to_current once waypoints are available.
var _needs_initial_destination: bool = false
# Debug trace accumulator.
var _trace_accum: float = 0.0


func enter() -> void:
	_trace_accum = TRACE_INTERVAL  # log immediately on entry
	_trace_log(
		(
			"enter — waypoints=%d nav_finished=%s"
			% [enemy.patrol_waypoints.size(), str(enemy.navigation_finished())]
		)
	)
	if enemy.patrol_waypoints.is_empty():
		# Enemy._ready() hasn't run yet — waypoints not resolved. Defer the initial
		# destination call; physics_update will trigger it once waypoints are populated.
		_needs_initial_destination = true
	else:
		# Defer one additional frame so the NavigationServer can register the agent
		# and compute its first path before we read is_navigation_finished(). Without
		# this extra defer, runtime-spawned enemies (added via add_child at runtime)
		# have their NavigationAgent3D unregistered on the first physics tick, causing
		# is_navigation_finished() to return true immediately → enemy never moves.
		_go_to_current.call_deferred()


func physics_update(delta: float) -> String:
	if enemy.distance_to_target() <= enemy.detect_range and enemy.can_see_target():
		_trace_log("detect → PursueState dist=%.1f" % enemy.distance_to_target())
		return "PursueState"
	# Retry deferred initial destination now that enemy._ready() has run.
	if _needs_initial_destination and not enemy.patrol_waypoints.is_empty():
		_needs_initial_destination = false
		_go_to_current()
	if enemy.patrol_waypoints.is_empty():
		enemy.stop(delta)
		return ""
	# Skip the finished check for one frame after set_destination() — the nav server
	# needs one physics tick to compute the path; is_navigation_finished() returns true
	# before that, which would mistakenly trigger an immediate PursueState transition.
	if _destination_just_set:
		_destination_just_set = false
		enemy.move_along_path(enemy.patrol_speed, delta)
		return ""
	# Waypoint reached — transition to active pursuit.
	if enemy.navigation_finished():
		_trace_log("waypoint_reached → PursueState")
		return "PursueState"

	_trace_accum += delta
	if _trace_accum >= TRACE_INTERVAL:
		_trace_accum = 0.0
		_trace_log(
			(
				"patrolling dist_to_player=%.1f nav_finished=%s"
				% [enemy.distance_to_target(), str(enemy.navigation_finished())]
			)
		)

	enemy.move_along_path(enemy.patrol_speed, delta)
	return ""


func _go_to_current() -> void:
	if enemy.patrol_waypoints.is_empty():
		return
	enemy.set_destination(enemy.patrol_waypoints[0].global_position)
	_destination_just_set = true
	_trace_log("set_destination wp[0]=%s" % str(enemy.patrol_waypoints[0].global_position))


## Emit a debug trace line when debug/enemy_trace is enabled.
func _trace_log(msg: String) -> void:
	if not ProjectSettings.get_setting("debug/enemy_trace", false):
		return
	print("[EnemyTrace][%s][PatrolState] %s" % [enemy.name, msg])
