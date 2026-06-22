# tools/lib/cast/hit_target_resolver.gd — returns the body the projectile directly hit.
class_name HitTargetResolver
extends TargetResolver


func resolve(ctx: GameContext) -> Array[Node]:
	if ctx.target == null:
		return []
	return [ctx.target]
