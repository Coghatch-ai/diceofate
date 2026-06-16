# entities/enemy/state_machine/attack_state.gd — hold position, attack on cooldown, return to chase.
class_name AttackState
extends EnemyState


func enter() -> void:
	_try_attack()


func physics_update(delta: float) -> String:
	enemy.stop(delta)
	if enemy.distance_to_target() > enemy.attack_range:
		return "ChaseState"
	_try_attack()
	return ""


func _try_attack() -> void:
	if enemy.attack_timer.is_stopped():
		enemy.perform_attack()
		enemy.attack_timer.start()
