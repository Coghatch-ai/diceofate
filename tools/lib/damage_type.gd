# tools/lib/damage_type.gd — shared DamageType enum for typed damage (slice 3).
class_name DamageType

## Two damage types for slice 3. Extend here (never in callers) when new types land.
enum Kind {
	PHYSICAL = 0,
	FIRE = 1,
}
