# entities/target/target.gd — static shootable block; despawns on first projectile hit.
class_name Target
extends StaticBody3D

@onready var _health_comp: HealthComponent = $HealthComponent


func _ready() -> void:
	_health_comp.max_health = 1
	_health_comp.reset()
	_health_comp.died.connect(queue_free)


# Called by the projectile via duck-typed on_hit() — aliases apply_damage(1).
func on_hit() -> void:
	apply_damage(1)


## Apply damage. Any non-zero amount destroys the target (one-shot via HealthComponent).
func apply_damage(amount: int) -> void:
	_health_comp.apply_damage(amount)
