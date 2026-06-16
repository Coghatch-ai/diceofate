# entities/enemy/state_machine/state_machine.gd — node-based FSM driving the active enemy state.
class_name EnemyStateMachine
extends Node

@export var initial_state: EnemyState

var current_state: EnemyState
var _states: Dictionary = {}


func _ready() -> void:
	var enemy_owner := owner as Enemy
	var first_state: EnemyState = null
	for child in get_children():
		if child is EnemyState:
			var state := child as EnemyState
			_states[state.name] = state
			state.enemy = enemy_owner
			state.state_machine = self
			if first_state == null:
				first_state = state
	# Prefer the exported initial_state; fall back to first registered state.
	var start: EnemyState = initial_state if initial_state != null else first_state
	if start != null:
		current_state = start
		# Defer enter() so Enemy._ready() has already run and patrol_waypoints are populated.
		# StateMachine is a child of Enemy, so _ready() fires here first (bottom-up);
		# call_deferred waits until the full _ready() chain finishes before calling enter().
		current_state.enter.call_deferred()


func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	var next: String = current_state.physics_update(delta)
	if next != "":
		transition_to(next)


func transition_to(state_name: String) -> void:
	if not _states.has(state_name):
		push_error("EnemyStateMachine: unknown state '%s'" % state_name)
		return
	current_state.exit()
	# SEAM: dictionary values are Variant; we know they are EnemyState by construction.
	@warning_ignore("unsafe_cast")
	current_state = _states[state_name] as EnemyState
	current_state.enter()
