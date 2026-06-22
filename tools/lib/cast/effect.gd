# tools/lib/cast/effect.gd — base Resource for a single cast effect; subclass to add behaviour.
class_name Effect
extends Resource


## Apply this effect to target. No-op base; override in concrete subclasses.
## target: the Node returned by TargetResolver.resolve() for this effect application.
## ctx: the GameContext built by Projectile on hit.
func apply(_target: Node, _ctx: GameContext) -> void:
	pass
