# Cast System v1 (data-driven projectile payload)

**Goal** — A weapon's bullet behaviour is authored as a `CastData` `.tres` (an `Effect[]` + a `TargetResolver`), not hardcoded; firing the pistol applies a data-authored damage amount + knockback to the hit enemy. Foundation so each future weapon gets its own rules by editing a resource, not code.

**Concept (agreed)** — "Bullets" become spell/magic-style payloads. The weapon owns a `CastData`; the gun stamps it onto each spawned projectile; the projectile keeps owning its own hit→apply-effects (source's spawned-object rule). Name the resource graph the **Cast system** (`CastData`); the existing `Projectile` node keeps its name. Extensible: new `Effect` subclass = new `.tres`, no firing-path change.

## Scope (in)
- `CastData` Resource (`tools/lib/cast/cast_data.gd`, `class_name CastData`) — `@export var effects: Array[Effect]`, `@export var resolver: TargetResolver`. Saved as typed `.tres`, NOT JSON.
- `Effect` base Resource (`class_name Effect`) — one virtual `func apply(target: Node, ctx: GameContext) -> void` (no-op base).
- `TargetResolver` base Resource (`class_name TargetResolver`) — `func resolve(ctx: GameContext) -> Array[Node]`. One concrete v1: `HitTargetResolver` → returns `[ctx.target]` (the body the projectile hit).
- `GameContext` (plain `RefCounted`, `class_name GameContext`) — `instigator: Node`, `target: Node`, `hit_pos: Vector3`, `hit_normal: Vector3`. Built by the projectile on hit.
- Two concrete Effects:
  - `DamageEffect` — `@export var amount: int`; on `apply`, duck-types `target.apply_damage(amount)` (no method → no-op).
  - `KnockbackEffect` — on `apply`, duck-types `target.apply_knockback(ctx.instigator_pos)` (already exists on `enemy.gd`; no method → no-op).
- New damage seam (user choice): add `func apply_damage(amount: int) -> void` to the 3 shootables (`enemy.gd`, `target.gd`, `npc.gd`). Body = current `on_hit()` death/flash logic, but `_health -= amount` instead of `-= 1`. `on_hit()` becomes `apply_damage(1)` (one-liner) so `projectile.gd`'s existing bare call + godot-fps-enemy-combat contract still pass.
- Wiring: `gun.gd` gets `@export var cast_data: CastData`; in `_fire()`, after instancing, set `projectile.cast_data = cast_data`. `projectile.gd` `_on_body_entered`: build `GameContext`, then `if cast_data != null:` resolve targets and `for e in effects: for t in targets: e.apply(t, ctx)`. If `cast_data == null`, fall back to current bare `on_hit()` path (no regression for non-cast weapons).
- One authored asset: `entities/weapon/pistol_cast.tres` — `[DamageEffect(amount=1), KnockbackEffect]`, `HitTargetResolver`. Assigned on the pistol's `Gun`.

## Scope (out)
- HealSelf / instigator-targeted effects — player has no local health/heal seam (routed via WaveManager); inventing one is its own slice.
- Mana / class / weapon / cooldown requirement gate — no resource system; firing stays gun.gd's `try_fire()` ammo+cooldown gate.
- Radius / AoE `TargetResolver` — only `HitTargetResolver` ships.
- Generic editor-key `EffectMapComponent` (`on_tick`/`on_bounce` event maps) — projectile's single `hit` seam suffices for v1.
- `CastManager` component on the weapon — for a single hit-driven projectile, the gun's stamp + projectile's apply loop covers it; a manager earns its place only when casts fire instigator-side effects (HealSelf) or multi-stage spawns. Parked, not built.
- Renaming `Projectile` → `ProjectileSystem` — keep the node name; "Cast system" is the data layer's name.

## Acceptance
- `tools/validate.sh` passes (strict-typed; no untyped/unsafe beyond guarded seams).
- godot-runtime-smoke (`tools/smoke_*.gd`): fire a projectile with `pistol_cast.tres` at a 1-health enemy → `apply_damage(1)` invoked → `died` emitted; assert KnockbackEffect called `apply_knockback`. Author a `DamageEffect(amount=3)` cast vs a 3-health tank → dies in ONE shot (proves data-authored amount).
- Existing combat unchanged: a `Gun` with `cast_data == null` still kills a grunt in one shot via the fallback `on_hit()` path (no regression).
- Human F5 look: shoot pistol at an enemy in `firing_yard` — enemy takes damage AND visibly gets knocked back from one shot.

## Skill notes
- `godot-code-rules` — strict typed GDScript; Resource subclasses need explicit types + return types; duck-typed `apply_damage`/`apply_knockback` calls go through `has_method` guards + `@warning_ignore("unsafe_method_access")` (same pattern as projectile's `on_hit`).
- `godot-fps-enemy-combat` — the shootability contract changes: `on_hit()` stays but delegates to new `apply_damage(amount)`. Update the skill's contract note so the seam is `apply_damage(amount:=1)` / `on_hit()` alias. Flag to skill owner.
- `godot-travelling-projectile-3d` — projectile keeps owning hit→effect; the only addition is the `cast_data` stamp + apply loop. Firing component untouched.
- `godot-composition` — `Effect`/`TargetResolver`/`CastData` are data Resources (calls down via duck-typed apply); `GameContext` is a plain RefCounted DTO, no node lifecycle. No autoload.

## Later
- HealSelf + instigator `TargetResolver` once player gets a real health/heal seam.
- `CastManager` weapon component when casts fire instigator-side or multi-spawn effects.
- Radius/AoE `TargetResolver` for an explosive/chain cast.
- Per-weapon casts: shotgun (multi-projectile spread cast), heavy slug (high `DamageEffect.amount`), each its own `.tres`.
- Requirement gate (cooldown/ammo-as-mana) in `CastData` metadata.

## Open questions
- None blocking.
