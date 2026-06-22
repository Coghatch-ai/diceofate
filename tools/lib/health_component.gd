# tools/lib/health_component.gd — reusable child-Node health component (slice 1+3).
class_name HealthComponent
extends Node
## Owns current + max health for any entity. Signals up; parent calls down.
## Emits health_changed on every apply_damage/heal; emits died exactly once at zero.
## Slice 3: apply_damage accepts an optional DamageType.Kind; resistances Dictionary
## maps DamageType.Kind → float multiplier (default 1.0 = no resistance).

signal died
signal health_changed(current: int, max_health: int)

@export_group("Health")
@export_range(1, 9999, 1) var max_health: int = 2

@export_group("Resistances")
## Map DamageType.Kind (int key) → float multiplier. 0.5 = 50% resistance (half damage).
## Leave empty for no resistance. Example: { DamageType.Kind.FIRE: 0.5 }
@export var resistances: Dictionary = {}

var _current: int = 0
var _dead: bool = false


func _ready() -> void:
	_current = max_health


## Re-seed _current from max_health. Call from parent _ready() after overriding max_health,
## so the component starts at the correct value even when the parent changes max_health
## after child _ready() has already run (bottom-up order).
func reset() -> void:
	_current = max_health
	_dead = false


## Apply damage, optionally typed. Type defaults to PHYSICAL so all slice-1/2 callers
## (on_hit, bare apply_damage(amount)) are unchanged.
## Resistance multiplier is applied before subtraction; result rounds toward 0 (int).
func apply_damage(amount: int, type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
	if _dead:
		return
	var multiplier: float = resistances.get(type, 1.0)
	var effective: int = int(float(amount) * multiplier)
	_current = max(_current - effective, 0)
	health_changed.emit(_current, max_health)
	if _current == 0:
		_dead = true
		died.emit()


func heal(amount: int) -> void:
	if _dead:
		return
	_current = min(_current + amount, max_health)
	health_changed.emit(_current, max_health)


func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(_current) / float(max_health)
