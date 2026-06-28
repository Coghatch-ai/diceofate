# entities/enemy/state_machine/attack_state.gd — hold position, attack on cooldown, return to chase.
class_name AttackState
extends EnemyState


func enter() -> void:
	# Start the attack timer immediately on entry with a random offset so that
	# multiple enemies entering AttackState in the same frame cannot all fire
	# simultaneously (prevents instant multi-enemy burst kill on first contact).
	# The timer is one_shot — next fire is queued by _try_attack after each attack.
	if is_instance_valid(enemy) and enemy.attack_timer.is_stopped():
		var jitter: float = randf_range(0.0, enemy.attack_cooldown)
		enemy.attack_timer.start(jitter)


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
