# entities/enemy/state_machine/patrol_state.gd — walk waypoint loop; hand off to chase on sight.
class_name PatrolState
extends EnemyState

var _index: int = 0
var _waiting: bool = false
var _timer_connected: bool = false
# Guard: NavigationAgent3D.is_navigation_finished() returns true on the same frame
# target_position is set (path not yet computed by the nav server). Skip the finished
# check for one physics frame after each set_destination() call.
var _destination_just_set: bool = false
# Set when enter() fires before enemy._ready() has populated patrol_waypoints (runtime
# spawn race: StateMachine._ready() calls enter() before Enemy._ready() resolves NodePaths).
# physics_update retries _go_to_current once waypoints are available.
var _needs_initial_destination: bool = false


func enter() -> void:
	_waiting = false
	if enemy.patrol_waypoints.is_empty():
		# Enemy._ready() hasn't run yet — waypoints not resolved. Defer the initial
		# destination call; physics_update will trigger it once waypoints are populated.
		_needs_initial_destination = true
	else:
		# Defer one additional frame so the NavigationServer can register the agent
		# and compute its first path before we read is_navigation_finished(). Without
		# this extra defer, runtime-spawned enemies (added via add_child at runtime)
		# have their NavigationAgent3D unregistered on the first physics tick, causing
		# is_navigation_finished() to return true immediately → _start_wait() fires →
		# enemy stands idle cycling the wait timer forever without moving.
		_go_to_current.call_deferred()


func exit() -> void:
	if _timer_connected:
		enemy.patrol_wait_timer.timeout.disconnect(_on_wait_done)
		_timer_connected = false


func physics_update(delta: float) -> String:
	if enemy.distance_to_target() <= enemy.detect_range and enemy.can_see_target():
		return "ChaseState"
	# Retry deferred initial destination now that enemy._ready() has run.
	if _needs_initial_destination and not enemy.patrol_waypoints.is_empty():
		_needs_initial_destination = false
		_go_to_current()
	if enemy.patrol_waypoints.is_empty() or _waiting:
		enemy.stop(delta)
		return ""
	# Skip the finished check for one frame after set_destination() — the nav server
	# needs one physics tick to compute the path; is_navigation_finished() returns true
	# before that, which would mistakenly trigger the wait timer.
	if _destination_just_set:
		_destination_just_set = false
		enemy.move_along_path(enemy.patrol_speed, delta)
		return ""
	if enemy.navigation_finished():
		_start_wait()
		enemy.stop(delta)
		return ""
	enemy.move_along_path(enemy.patrol_speed, delta)
	return ""


func _start_wait() -> void:
	if _waiting:
		return
	_waiting = true
	if not _timer_connected:
		enemy.patrol_wait_timer.timeout.connect(_on_wait_done)
		_timer_connected = true
	enemy.patrol_wait_timer.start()


func _on_wait_done() -> void:
	_waiting = false
	_index = (_index + 1) % enemy.patrol_waypoints.size()
	_go_to_current()


func _go_to_current() -> void:
	if enemy.patrol_waypoints.is_empty():
		return
	enemy.set_destination(enemy.patrol_waypoints[_index].global_position)
	_destination_just_set = true
