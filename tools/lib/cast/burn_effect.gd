# tools/lib/cast/burn_effect.gd — starts a burn/poison DoT on the target via StatusReceiver seam.
class_name BurnEffect
extends Effect

@export_group("Burn")
@export_range(1, 20, 1) var dps: int = 2
@export_range(0.1, 30.0, 0.1) var duration: float = 3.0
## DamageType applied per tick. FIRE for fire; POISON for poison cloud. Defaults FIRE.
@export_enum("PHYSICAL", "FIRE", "ICE", "ELECTRIC", "POISON", "ACID")
var damage_type: int = DamageType.Kind.FIRE


func apply(target: Node, _ctx: GameContext) -> void:
	if not target.has_method("add_status_burn"):
		return
	# SEAM: method proven present by has_method; type not known at compile time.
	@warning_ignore("unsafe_method_access")
	target.add_status_burn(dps, duration, damage_type as DamageType.Kind)
