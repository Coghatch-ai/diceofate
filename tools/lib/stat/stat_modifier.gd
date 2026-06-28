# tools/lib/stat/stat_modifier.gd — one buff/debuff change to one stat (authored .tres or runtime).
class_name StatModifier
extends Resource

enum Op {
	ADD,  ## Flat: contributes to the additive bucket (base + sum(ADD)).
	MULTIPLY,  ## Percent: contributes to the mult bucket. value 0.5 = +50%; -0.3 = -30%.
}

## Stat id this modifier targets (e.g. &"move_speed"). snake_case StringName.
@export var stat: StringName = &""
## ADD (flat bucket) or MULTIPLY (percent bucket).
@export var op: Op = Op.ADD
## ADD: flat amount. MULTIPLY: fraction where 0.0 is neutral, 0.5 = +50%, -0.3 = -30%.
@export_range(-100.0, 100.0, 0.01) var value: float = 0.0
## Opaque owner key. Same source REFRESHES (one slot); different sources STACK.
## Convention: &"kind:name" e.g. &"buff:haste", &"debuff:armor_break".
@export var source: StringName = &""
