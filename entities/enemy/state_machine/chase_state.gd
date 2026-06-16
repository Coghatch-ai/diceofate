# entities/enemy/state_machine/chase_state.gd — pursue player; branch to attack or back to patrol.
class_name ChaseState
extends EnemyState

const REPATH_INTERVAL: float = 0.25

var _repath_accum: float = 0.0
var _destination_just_set: bool = false


func enter() -> void:
	_repath_accum = REPATH_INTERVAL


func physics_update(delta: float) -> String:
	var dist: float = enemy.distance_to_target()
	if dist >= enemy.escape_range or not enemy.can_see_target():
		return "PatrolState"
	if dist <= enemy.attack_range:
		return "AttackState"
	_repath_accum += delta
	if _repath_accum >= REPATH_INTERVAL:
		_repath_accum = 0.0
		var t: Node3D = enemy.target()
		if t != null:
			enemy.set_destination(t.global_position)
			_destination_just_set = true
	# Skip one frame after set_destination() so the nav server can compute the path.
	if _destination_just_set:
		_destination_just_set = false
		return ""
	enemy.move_along_path(enemy.move_speed, delta)
	return ""
