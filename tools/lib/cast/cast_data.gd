# tools/lib/cast/cast_data.gd — authored .tres: list of Effects + a TargetResolver.
# Assigned to Gun.cast_data; stamped onto each spawned Projectile at fire time.
class_name CastData
extends Resource

## Effects to apply on hit, in order.
@export var effects: Array[Effect] = []
## Resolves which nodes receive the effects. Default null -> no targets, no-op.
@export var resolver: TargetResolver
## Tint colour applied to the projectile mesh material at fire time.
## Default yellow matches existing pistol behaviour. Null cast_data -> scene default preserved.
@export var bullet_color: Color = Color(1, 1, 0)
## When true, the projectile ignores magnetic steering (pull fields / bubble zones).
## Allows the bullet to travel straight through a magnet enemy's repulsion bubble.
## Default false = all existing casts stay deflected as before.
@export var pierces_barriers: bool = false
