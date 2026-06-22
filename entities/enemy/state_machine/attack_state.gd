# entities/enemy/state_machine/attack_state.gd — hold position, attack on cooldown, return to chase.
class_name AttackState
extends EnemyState


func enter() -> void:
	_try_attack()


func physics_update(delta: float) -> String:
	if not is_instance_valid(enemy):
		return ""
	enemy.stop(delta)
	if enemy.distance_to_target() > enemy.attack_range:
		return "ChaseState"
	_try_attack()
	return ""


func _try_attack() -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.attack_timer.is_stopped():
		enemy.perform_attack()
		if is_instance_valid(enemy):
			enemy.attack_timer.start()
