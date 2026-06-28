# tools/lib/cast/buff_effect.gd — applies a StatModifier to a target's StatBlock on hit.
class_name BuffEffect
extends Effect
## On hit: pushes a StatModifier onto the target's StatBlock via apply_buff(modifier, duration).
## Duration/expiry owned by StatusReceiver — on expiry it calls remove_all_from_source(source).
## This Effect does NOT tick or time.

@export var modifier: StatModifier
## Seconds the buff lasts. Routed to the target's StatusReceiver via apply_buff.
@export_range(0.1, 60.0, 0.1) var duration: float = 5.0


func apply(target: Node, _ctx: GameContext) -> void:
	if target.has_method("apply_buff"):
		# SEAM: apply_buff(modifier, duration) proven by has_method; duck-typed.
		@warning_ignore("unsafe_method_access")
		target.apply_buff(modifier, duration)
