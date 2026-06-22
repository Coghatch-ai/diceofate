# tools/lib/shield_component.gd — overflow shield absorbing damage before HealthComponent (slice 3).
class_name ShieldComponent
extends Node
## Sibling of HealthComponent. Call absorb(amount) first; it consumes up to _current_shield
## and returns the leftover (overflow) to be forwarded to HealthComponent.apply_damage().
## Opt-in: entities without this node skip shield logic entirely.

signal shield_changed(current: int, max_shield: int)

@export_group("Shield")
@export_range(0, 9999, 1) var max_shield: int = 0

var _current_shield: int = 0


func _ready() -> void:
	_current_shield = max_shield


## Re-seed from max_shield. Call from parent _ready() after setting max_shield.
func reset() -> void:
	_current_shield = max_shield


## Absorb up to _current_shield points of damage.
## Returns overflow (amount not absorbed) to pass on to HealthComponent.
func absorb(amount: int) -> int:
	if _current_shield <= 0:
		return amount
	var absorbed: int = min(_current_shield, amount)
	_current_shield -= absorbed
	shield_changed.emit(_current_shield, max_shield)
	return amount - absorbed


func get_shield_percent() -> float:
	if max_shield <= 0:
		return 0.0
	return float(_current_shield) / float(max_shield)
