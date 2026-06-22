# tools/lib/cast/slow_effect.gd — starts a movement slow on the target via StatusReceiver seam.
class_name SlowEffect
extends Effect

@export_group("Slow")
## Speed multiplier while chilled. 0.4 = 40% of normal speed.
@export_range(0.05, 0.95, 0.05) var slow_factor: float = 0.4
@export_range(0.1, 30.0, 0.1) var duration: float = 2.5


func apply(target: Node, _ctx: GameContext) -> void:
	if not target.has_method("add_status_slow"):
		return
	# SEAM: method proven present by has_method; type not known at compile time.
	@warning_ignore("unsafe_method_access")
	target.add_status_slow(slow_factor, duration)
