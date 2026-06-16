# entities/enemy/state_machine/state.gd — base class for one enemy behaviour state.
class_name EnemyState
extends Node
## Override the lifecycle hooks. physics_update returns the next state's
## node name to transition, or "" to stay.

var enemy: Enemy
var state_machine: EnemyStateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> String:
	return ""
