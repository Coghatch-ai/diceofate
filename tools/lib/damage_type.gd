# tools/lib/damage_type.gd — shared DamageType enum for typed damage (slice 3+).
class_name DamageType

## Damage kinds. Extend here only; callers use DamageType.Kind.X.
## Slice A adds ICE, ELECTRIC, POISON (elemental bullet foundation).
enum Kind {
	PHYSICAL = 0,
	FIRE = 1,
	ICE = 2,
	ELECTRIC = 3,
	POISON = 4,
	ACID = 5,
}
