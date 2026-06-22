# tools/lib/enemy/enemy_behaviour.gd — base class for stateful per-frame enemy behaviour components.
class_name EnemyBehaviour
extends Node
## Override bind(enemy) to receive the owning Enemy ref and do setup (add_to_group, init timers).
## Override do_attack() to replace the default melee-lunge (attack behaviour role).
## Override drive_move(speed, delta) / drive_stop(delta) / wants_nav_velocity() for movement role.
## Override pre_set_destination(point) to transform the nav target before it is sent to the agent.
## Override blocks_nav_velocity() to suppress _on_nav_velocity_computed during owned movement.


## Called once by Enemy after instancing this behaviour under Abilities.
## Store enemy ref here; do NOT call get_parent() elsewhere (signals up / calls down).
func bind(_enemy: Node) -> void:
	pass


## Attack role: called instead of default melee-lunge when present.
## Override in slice-2 components (ShooterAttack, MagnetBehaviour, FlyingMovement, etc.).
func do_attack() -> void:
	pass


## Movement role: called instead of default gravity walk when wants_nav_velocity() == true.
func drive_move(_speed: float, _delta: float) -> void:
	pass


## Movement role: called instead of default stop() when wants_nav_velocity() == true.
func drive_stop(_delta: float) -> void:
	pass


## Return true to take over movement from the default gravity-nav path.
## Default false = default nav walk used.
func wants_nav_velocity() -> bool:
	return false


## Return true to suppress _on_nav_velocity_computed (movement behaviour owns velocity then).
## Default false = nav velocity applied normally.
func blocks_nav_velocity() -> bool:
	return false


## Transform the destination point before it is passed to NavigationAgent3D.target_position.
## Default: return point unchanged. FlyingMovement clamps Y to floor level.
func pre_set_destination(point: Vector3) -> Vector3:
	return point
