# entities/target/target.gd — static shootable block; despawns on first projectile hit.
class_name Target
extends StaticBody3D


# Called by the projectile via duck-typed on_hit() when body_entered fires on the projectile.
# Composition-clean: the target reacts to its own hit; the projectile does not own the reaction.
func on_hit() -> void:
	queue_free()
