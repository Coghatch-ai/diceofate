# tools/lib/stat/stat_block.gd — per-instance buff/debuff stat-block component.
class_name StatBlock
extends Node
## Composition child. Owns base values + active StatModifiers; computes derived values.
## Signals up (stat_changed); parent calls down (add_modifier/remove_*). Owns NO HP/timer/resist.
## Derived = base + sum(ADD), then × (1.0 + sum(MULTIPLY)), then clamp.
## Buckets SUMMED once — two +50% MULTIPLY buffs → ×2.0, NOT ×2.25.

## Emitted only when a stat's computed value actually changes (is_equal_approx guard).
signal stat_changed(stat: StringName, value: float)

## Base values per stat. Set in Inspector or via set_base(). e.g. { &"move_speed": 6.0 }.
@export var base_values: Dictionary = {}
## Optional per-stat clamp. Key = stat StringName, value = Vector2(min, max). Absent = (0, INF).
@export var clamp_limits: Dictionary = {}

## Typed: stat -> { source -> StatModifier }.
var _modifiers: Dictionary = {}
## Last emitted value per stat — suppresses no-op stat_changed emissions.
var _last: Dictionary = {}


## Add or refresh a modifier. Same source on the same stat replaces the old entry.
func add_modifier(modifier: StatModifier) -> void:
	var stat: StringName = modifier.stat
	if not _modifiers.has(stat):
		_modifiers[stat] = {}
	# SEAM: _modifiers values are always Dictionary by construction.
	@warning_ignore("unsafe_cast")
	var by_source: Dictionary = _modifiers[stat] as Dictionary
	by_source[modifier.source] = modifier
	_emit_if_changed(stat)


## Remove one source's modifier from one stat.
func remove_modifier(stat: StringName, source: StringName) -> void:
	if _modifiers.has(stat):
		# SEAM: _modifiers values are always Dictionary by construction.
		@warning_ignore("unsafe_cast")
		var by_source: Dictionary = _modifiers[stat] as Dictionary
		by_source.erase(source)
		if by_source.is_empty():
			_modifiers.erase(stat)
	_emit_if_changed(stat)


## Remove every modifier a source applied across all stats (clean buff expiry).
func remove_all_from_source(source: StringName) -> void:
	var affected: Array[StringName] = []
	for stat: StringName in _modifiers.keys():
		# SEAM: _modifiers values are always Dictionary by construction.
		@warning_ignore("unsafe_cast")
		var by_source: Dictionary = _modifiers[stat] as Dictionary
		if by_source.has(source):
			by_source.erase(source)
			affected.append(stat)
	for stat: StringName in affected:
		# SEAM: _modifiers values are always Dictionary by construction; Variant cast required.
		@warning_ignore("unsafe_cast")
		if _modifiers.has(stat) and (_modifiers[stat] as Dictionary).is_empty():
			_modifiers.erase(stat)
	for stat: StringName in affected:
		_emit_if_changed(stat)


## Derived value: base + sum(ADD), then × (1.0 + sum(MULTIPLY)), then clamp.
func get_value(stat: StringName) -> float:
	# SEAM: Dictionary.get() returns Variant; base_values always stores float by contract.
	@warning_ignore("unsafe_cast")
	var base: float = base_values.get(stat, 0.0) as float
	# SEAM: _modifiers values are always Dictionary by construction.
	@warning_ignore("unsafe_cast")
	var by_source: Dictionary = _modifiers.get(stat, {}) as Dictionary
	var add_sum: float = 0.0
	var mult_sum: float = 0.0
	for mod: StatModifier in by_source.values():
		if mod.op == StatModifier.Op.ADD:
			add_sum += mod.value
		else:
			mult_sum += mod.value
	var result: float = (base + add_sum) * (1.0 + mult_sum)
	# SEAM: clamp_limits values are always Vector2 by contract.
	@warning_ignore("unsafe_cast")
	var limits: Vector2 = clamp_limits.get(stat, Vector2(0.0, INF)) as Vector2
	return clampf(result, limits.x, limits.y)


## Change a base value and emit if derived result changes.
func set_base(stat: StringName, value: float) -> void:
	base_values[stat] = value
	_emit_if_changed(stat)


func _emit_if_changed(stat: StringName) -> void:
	var new_val: float = get_value(stat)
	# SEAM: _last values are always float by construction; Variant subscript requires cast.
	@warning_ignore("unsafe_cast")
	var prev: float = _last.get(stat, -INF) as float
	if not _last.has(stat) or not is_equal_approx(prev, new_val):
		_last[stat] = new_val
		stat_changed.emit(stat, new_val)
