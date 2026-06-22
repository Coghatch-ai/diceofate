# tools/lib/cast/knockback_effect.gd — pushes the target away from the instigator's position.
class_name KnockbackEffect
extends Effect


func apply(target: Node, ctx: GameContext) -> void:
	if not target.has_method("apply_knockback"):
		return
	# SEAM: method proven present by has_method check; type not known at compile time.
	@warning_ignore("unsafe_method_access")
	target.apply_knockback(ctx.instigator_pos)
