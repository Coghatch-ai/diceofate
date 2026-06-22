# tools/lib/cast/target_resolver.gd — base Resource; resolves a list of Nodes to apply effects to.
class_name TargetResolver
extends Resource


## Return the list of target Nodes for this cast. No-op base returns empty array.
## Override in concrete subclasses (e.g. HitTargetResolver, RadiusResolver).
func resolve(_ctx: GameContext) -> Array[Node]:
	return []
