# entities/npc/npc.gd — stationary shootable NPC; despawns on first projectile hit.
class_name Npc
extends StaticBody3D

## Emitted just before queue_free() so listeners can react.
signal died(npc: Npc)


# Called by the projectile via duck-typed on_hit() (godot-travelling-projectile-3d).
# Composition-clean: the NPC reacts to its own hit; the projectile does not own the reaction.
func on_hit() -> void:
	died.emit(self)
	queue_free()
