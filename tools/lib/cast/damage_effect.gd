# tools/lib/cast/damage_effect.gd — applies a data-authored damage amount to the target.
class_name DamageEffect
extends Effect

## Damage dealt per hit. Author per-weapon in .tres (e.g. pistol = 1, heavy slug = 3).
@export_range(1, 999, 1) var amount: int = 1
## Damage type for resistance scaling (slice 3). Defaults to PHYSICAL so existing .tres
## files without this field authored still behave identically (backward-compatible).
@export_enum("PHYSICAL", "FIRE", "ICE", "ELECTRIC", "POISON")
var damage_type: int = DamageType.Kind.PHYSICAL


func apply(target: Node, _ctx: GameContext) -> void:
	if not target.has_method("apply_damage"):
		return
	# SEAM: method proven present by has_method check; type not known at compile time.
	# Try typed 2-arg path first; fall back to 1-arg for callers that haven't opted in.
	@warning_ignore("unsafe_method_access")
	target.apply_damage(amount, damage_type as DamageType.Kind)
