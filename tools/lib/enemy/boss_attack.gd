# tools/lib/enemy/boss_attack.gd — base class for stateful per-frame boss attack components.
# Mirrors EnemyBehaviour's bind()/seam contract for the BossData.attacks ordered list.
# Each component owns its telegraph + execute + recover lifecycle; boss.gd drives the loop.
class_name BossAttack
extends Node
## Override the lifecycle hooks below. bind() injects the owning Boss ref.
## telegraph_duration() / recover_duration() pull from data for tunables.
## start() is called once when the attack begins executing.
## tick(delta) is called every physics frame during execution; return true when done.


## Called once by Boss after instancing this component under Attacks.
## Store boss ref here; do NOT call get_parent() elsewhere (signals up / calls down).
func bind(_boss: Node) -> void:
	pass


## Seconds to spend in the generic telegraph phase before start() is called.
## Override to read from BossData (injected via bind).
func telegraph_duration() -> float:
	return 0.8


## Called once when the execute phase begins (after telegraph expires).
func start() -> void:
	pass


## Called every physics frame while executing. Return true when the attack is done.
## Boss.gd calls _apply_gravity + move_and_slide each frame; the component drives velocity
## by writing to boss.velocity directly (Boss is the bound type — calls down).
func tick(_delta: float) -> bool:
	return true


## Seconds to spend in recover after tick() returns true.
## Override to read from BossData (injected via bind).
func recover_duration() -> float:
	return 1.0
