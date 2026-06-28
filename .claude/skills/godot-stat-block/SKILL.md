---
name: godot-stat-block
description: Typed buff/debuff modifier stat-block for the DiceOfFate FPS POC (Godot 4.6, strict-typed GDScript) — a StatModifier `.tres` (stat id + ADD|MULTIPLY + value + source) plus a StatBlock Node component holding a typed Dictionary[StringName stat -> Dictionary[StringName source -> StatModifier]]; a derived value recomputes as base + sum(ADD), then × (1 + sum(MULTIPLY)), then clamp — buckets are SUMMED then applied once (NOT sequentially compounded) — and emits stat_changed(stat, value) only when the result changes, with refresh-by-source semantics. Use when a task needs buffed/debuffed numeric stats — "buff move speed", "debuff resistance", "speed boost", "slow as a stat", "additive + multiplicative modifiers", "stat modifier", "derived stat", "stack vs refresh a buff", "recompute a stat on change" — or when a bullet/cast must apply a temporary stat change. It LAYERS over existing systems and never replaces them: HealthComponent stays the live-HP owner, the archetype resistances dict stays the resist source (a debuff feeds a mult into it), StatusReceiver stays the timed-status/expiry owner (buff DURATION routes there), and buff APPLICATION enters via a new BuffEffect on the existing CastData/Effect seam. NOT live HP (godot-fps-enemy-combat / HealthComponent), NOT timed status burn/slow/shock (StatusReceiver), NOT ability cost/cooldown or gameplay-tags (parked, available in the library).
---

# godot-stat-block

A stat-block separates a **base** number (designer constant) from the **runtime modifiers** that buffs, debuffs, and equipment apply on top, and recomputes a **derived** value on demand. We build it as a typed `StatModifier` Resource (the data — one change) plus a `StatBlock` **Node component** (the runtime — composition over a Resource holding live mutable state), because the modifier set is per-instance live state that belongs on a node, not on a shared `.tres`. The derived value uses **bucket math**: sum every ADD, sum every MULTIPLY, then apply `base + add_sum` scaled by `(1.0 + mult_sum)` and clamp — the buckets are summed and applied ONCE so two `+50%` buffs give `×2.0` (1.5+1.5 → 3×… i.e. +100% over base), NOT the sequential `1.5 × 1.5 = 2.25×` compounding that order-dependent per-modifier scaling would produce. Modifiers are keyed by an opaque `source` StringName so re-applying the same source REFRESHES (one slot) while different sources STACK. The block **owns no live HP, no timers, no resists** — it computes numbers and emits `stat_changed`; the existing systems consume them.

## Requirements

- `godot-code-rules` applied — strict typed GDScript, explicit return types, no `Variant`/untyped leak, `@warning_ignore` only at a proven duck-typed seam.
- `godot-composition` — StatBlock is a child component Node (signals up / calls down), not an autoload, not a Resource holding mutable runtime state.
- `godot-data-driven-effect-composition` / `cast-system` — buff APPLICATION enters as a new `BuffEffect` (an `Effect` subclass) on the existing `CastData` seam; this skill does NOT add a new firing path.
- These existing owners stay authoritative — the StatBlock FEEDS them, never replaces:
  - `HealthComponent` (`tools/lib/health_component.gd`) owns live HP + the `resistances: Dictionary{DamageType.Kind -> float}` mult.
  - `StatusReceiver` (`tools/lib/status_receiver.gd`) owns timed status (burn/slow/shock) and refresh-not-stack timers — buff DURATION/expiry routes here.

## Project conventions

- Files: `StatModifier` → `tools/lib/stat/stat_modifier.gd`; `StatBlock` → `tools/lib/stat/stat_block.gd` (reusable cross-entity glue lives in `tools/lib/`). Authored modifier `.tres` → `tools/lib/stat/` or beside the cast that applies it.
- Stat ids are `StringName`, snake_case, matching existing field names where they feed one: `&"move_speed"`, `&"resist_mult"`, `&"fire_rate"`, `&"damage"`. Keep the id set small and documented at the call site — no stringly reflection onto live properties.
- `source` is a `StringName` namespaced `&"kind:name"` (e.g. `&"buff:haste"`, `&"debuff:armor_break"`, `&"cast:rapid"`) — same source refreshes, different sources stack.
- StatBlock is a Node component instanced under the entity (e.g. `Player/StatBlock`, `Enemy/StatBlock`), NOT an autoload. The entity wires `stat_changed` to its own seams in `_ready()`.
- ADD + MULTIPLY only. No OVERRIDE op (available in the library if a hard set-value ever lands). No cost/cooldown/gameplay-tags/HUD-binding layer (that whole ability/effect-holder layer is parked — StatusReceiver + the Cast/Effect seam already cover timing and application).
- Derived consumers, by id (the block emits, the entity routes):
  - `&"move_speed"` → the first-person controller's speed (godot-first-person-controller).
  - `&"resist_mult"` → multiplies into a `HealthComponent.resistances` entry (a debuff lowers it). The block computes the mult; the entity writes it into the dict — the block never owns the dict.
  - `&"fire_rate"` / `&"damage"` → the Gun / Cast values at fire time.

## Steps

1. Author the modifier Resource — one change, no node references, safe to duplicate:

```gdscript
# tools/lib/stat/stat_modifier.gd — one buff/debuff change to one stat (authored .tres or built at runtime).
class_name StatModifier
extends Resource

enum Op {
	ADD,       ## Flat: contributes to the additive bucket (base + sum(ADD)).
	MULTIPLY,  ## Percent: contributes to the mult bucket. value 0.5 = +50%; -0.3 = -30%.
}

## Stat id this modifier targets (e.g. &"move_speed", &"resist_mult"). snake_case StringName.
@export var stat: StringName = &""
## ADD (flat bucket) or MULTIPLY (percent bucket).
@export var op: Op = Op.ADD
## ADD: flat amount. MULTIPLY: fraction where 0.0 is neutral, 0.5 = +50%, -0.3 = -30%.
@export var value: float = 0.0
## Opaque owner key. Same source REFRESHES (one slot); different sources STACK.
@export var source: StringName = &""
```

2. Author the StatBlock component — typed nested dict, bucket math, recompute-on-change. NOTE the MULTIPLY math: sum the bucket, then apply `(1.0 + mult_sum)` ONCE (not per modifier):

```gdscript
# tools/lib/stat/stat_block.gd — per-instance buff/debuff stat-block (slice 1).
class_name StatBlock
extends Node
## Composition child. Owns base values + active StatModifiers; computes derived values.
## Signals up (stat_changed); parent calls down (add_modifier/remove_*). Owns NO HP/timer/resist.
## Derived = base + sum(ADD), then × (1.0 + sum(MULTIPLY)), then clamp. Buckets SUMMED, applied once.

## Emitted only when a stat's computed value actually changes.
signal stat_changed(stat: StringName, value: float)

## Base values per stat. Authored in the Inspector: { &"move_speed": 6.0, ... }.
@export var base_values: Dictionary = {}
## Optional per-stat clamp. Key = stat StringName, value = Vector2(min, max). Absent = (0.0, INF).
@export var clamp_limits: Dictionary = {}

## Typed: stat -> { source -> StatModifier }.
var _modifiers: Dictionary = {}
## Last emitted value per stat, to suppress no-op emissions.
var _last: Dictionary = {}


## Add or refresh a modifier. Same source on the same stat replaces the old entry (refresh).
func add_modifier(modifier: StatModifier) -> void:
	var stat: StringName = modifier.stat
	if not _modifiers.has(stat):
		_modifiers[stat] = {}
	var by_source: Dictionary = _modifiers[stat]
	by_source[modifier.source] = modifier
	_emit_if_changed(stat)


## Remove one source's modifier from one stat.
func remove_modifier(stat: StringName, source: StringName) -> void:
	if _modifiers.has(stat):
		var by_source: Dictionary = _modifiers[stat]
		by_source.erase(source)
		if by_source.is_empty():
			_modifiers.erase(stat)
	_emit_if_changed(stat)


## Remove every modifier a source applied across all stats (clean buff expiry).
func remove_all_from_source(source: StringName) -> void:
	var affected: Array[StringName] = []
	for stat: StringName in _modifiers.keys():
		var by_source: Dictionary = _modifiers[stat]
		if by_source.has(source):
			by_source.erase(source)
			affected.append(stat)
	for stat: StringName in affected:
		if _modifiers.has(stat) and (_modifiers[stat] as Dictionary).is_empty():
			_modifiers.erase(stat)
	for stat: StringName in affected:
		_emit_if_changed(stat)


## Derived value for a stat: base + sum(ADD), then × (1.0 + sum(MULTIPLY)), then clamp.
func get_value(stat: StringName) -> float:
	var base: float = float(base_values.get(stat, 0.0))
	var by_source: Dictionary = _modifiers.get(stat, {})
	var add_sum: float = 0.0
	var mult_sum: float = 0.0
	for mod: StatModifier in by_source.values():
		if mod.op == StatModifier.Op.ADD:
			add_sum += mod.value
		else:
			mult_sum += mod.value
	var result: float = (base + add_sum) * (1.0 + mult_sum)
	var limits: Vector2 = clamp_limits.get(stat, Vector2(0.0, INF))
	return clampf(result, limits.x, limits.y)


## Change a base value and emit if the derived result changes.
func set_base(stat: StringName, value: float) -> void:
	base_values[stat] = value
	_emit_if_changed(stat)


func _emit_if_changed(stat: StringName) -> void:
	var new_val: float = get_value(stat)
	if not _last.has(stat) or not is_equal_approx(_last[stat], new_val):
		_last[stat] = new_val
		stat_changed.emit(stat, new_val)
```

3. Wire the block on the entity — instance `StatBlock` as a child, seed bases in the Inspector or `_ready()`, connect `stat_changed` to the real consumers. The block computes; the entity routes:

```gdscript
# In the entity root (e.g. player.gd / enemy.gd).
@onready var _stats: StatBlock = $StatBlock

func _ready() -> void:
	_stats.stat_changed.connect(_on_stat_changed)

func _on_stat_changed(stat: StringName, value: float) -> void:
	match stat:
		&"move_speed":
			_move_speed = value  # consumed by the controller's velocity calc
		&"resist_mult":
			# The block computes the mult; the entity writes it into HealthComponent's dict.
			# HealthComponent stays the resist OWNER — the block only feeds a number.
			_health.resistances[DamageType.Kind.PHYSICAL] = value
		&"fire_rate":
			_gun.fire_rate = value
```

4. Apply a buff from a cast via a new `BuffEffect` (an `Effect` subclass on the existing `CastData` seam) — application enters here, DURATION/expiry routes through StatusReceiver, NOT a new timer on the block:

```gdscript
# tools/lib/cast/buff_effect.gd — applies a StatModifier to a target's StatBlock on hit.
class_name BuffEffect
extends Effect
## On hit: pushes a StatModifier onto the target's StatBlock (refresh-by-source).
## Duration/expiry is owned by StatusReceiver — on expiry the receiver calls
## stat_block.remove_all_from_source(source). This Effect does NOT tick or time.

@export var modifier: StatModifier
## Seconds the buff lasts. Routed to the target's StatusReceiver, which calls back to remove it.
@export var duration: float = 5.0

func apply(target: Node) -> void:
	if target.has_method("apply_buff"):
		# SEAM: apply_buff(modifier, duration) proven by has_method; duck-typed.
		@warning_ignore("unsafe_method_access")
		target.apply_buff(modifier, duration)
```

The target entity's `apply_buff(modifier, duration)` calls `_stats.add_modifier(modifier)` and registers the source with `StatusReceiver` so expiry fires `_stats.remove_all_from_source(modifier.source)` — the block never owns a timer.

## Verification checklist

- A `+50%` and another `+50%` MULTIPLY buff on `move_speed` (base 6.0) yield `12.0` (`6 × (1 + 0.5 + 0.5)` = ×2.0), NOT `13.5` — confirms summed-bucket, not sequential compounding.
- A flat `+2` ADD and a `+50%` MULTIPLY together on base 6.0 yield `(6 + 2) × 1.5 = 12.0` — ADD applied before MULTIPLY.
- Re-applying the SAME source twice leaves one modifier — the stat value does not double (refresh, not stack).
- Two DIFFERENT sources both apply — the stat reflects both (stack).
- `stat_changed` fires only when the derived value changes; setting a base to its current value emits nothing.
- On buff expiry the StatusReceiver-driven `remove_all_from_source` restores the stat to its pre-buff value, and the consumer (move speed / resist mult) visibly reverts.
- HealthComponent still owns and clamps live HP; the StatBlock holds no `_current`/HP field. The resist debuff shows up as a changed multiplier in `HealthComponent.resistances`, written BY the entity, not owned by the block.
- `tools/validate.sh` passes — no `UNSAFE_*`, no untyped declaration; the only `@warning_ignore` is at the proven `apply_buff` / `apply_damage` duck-typed seam.

## Error → Fix

| Symptom | Fix |
|---|---|
| Two +50% buffs give ×2.25 not ×2.0 | Sequential compounding — sum the MULTIPLY bucket then apply `(1.0 + mult_sum)` ONCE in `get_value`, don't `result *= (1+v)` per modifier. |
| Re-casting the same buff doubles the stat | `source` differs each apply (or empty) — use a stable namespaced `source` (`&"buff:haste"`) so the inner dict slot refreshes. |
| Buff never wears off | No expiry path — route `duration` through `StatusReceiver` and have it call `remove_all_from_source(modifier.source)`; the block has no timer by design. |
| `stat_changed` fires every frame | Something calls `set_base`/`add_modifier` per frame, or `_emit_if_changed` compares with `==` on floats — use `is_equal_approx` and only mutate on real change. |
| Resist debuff has no effect | The block computed a `resist_mult` but nothing wrote it into `HealthComponent.resistances` — wire the `&"resist_mult"` case in `_on_stat_changed` to write the dict entry. |
| `UNSAFE_METHOD_ACCESS` on `apply_buff`/`apply_damage` | Guard with `has_method(...)` then `@warning_ignore("unsafe_method_access")` at that one line — the duck-typed seam, per godot-code-rules. |
| Stat goes negative (e.g. speed below 0 from a big debuff) | Add a `clamp_limits` entry, e.g. `{ &"move_speed": Vector2(0.0, INF) }`. |

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
