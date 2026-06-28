# entities/damageable.gd — Thin CharacterBody3D base shared by Enemy and Boss.
# Owns the score_value field common to both. Signals (died, touched_player) are declared on
# each subclass with their own concrete param type — GDScript strict mode rejects a base
# signal of type Damageable connected to a handler typed Enemy/Boss without touching those
# handler files; keeping signals on subclasses is the no-consumer-edit path.
# on_hit() / apply_damage() contract is documented here but implemented per subclass.
class_name Damageable
extends CharacterBody3D

## Score awarded to the player on kill. Set by archetype / BossData in _ready(); default 1.
@export_range(1, 10000, 1) var score_value: int = 1
