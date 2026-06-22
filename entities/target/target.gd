# entities/target/target.gd — static shootable block; despawns on first projectile hit.
class_name Target
extends StaticBody3D


# Called by the projectile via duck-typed on_hit() — aliases apply_damage(1).
func on_hit() -> void:
	apply_damage(1)


## Apply damage. Any non-zero amount destroys the target (one-shot block).
func apply_damage(_amount: int) -> void:
	queue_free()
