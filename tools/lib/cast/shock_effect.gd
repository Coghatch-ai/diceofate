# tools/lib/cast/shock_effect.gd — applies a brief electric stun on the target via StatusReceiver.
class_name ShockEffect
extends Effect

@export_group("Shock")
@export_range(0.05, 5.0, 0.05) var stun_duration: float = 0.4


func apply(target: Node, _ctx: GameContext) -> void:
	if not target.has_method("add_status_shock"):
		return
	# SEAM: method proven present by has_method; type not known at compile time.
	@warning_ignore("unsafe_method_access")
	target.add_status_shock(stun_duration)
