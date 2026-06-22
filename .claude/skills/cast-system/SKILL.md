---
name: cast-system
description: >-
  The DiceOfFate Cast system — this FPS's concrete data-driven projectile-payload
  contract (Godot 4.6, strict-typed GDScript). A bullet's behaviour is authored as
  a `CastData` `.tres` (a `bullet_color` + an ordered `Effect[]` × a `TargetResolver`),
  the Gun stamps that CastData onto each spawned Projectile at fire time, and the
  Projectile owns the hit→resolve→apply chain through a duck-typed seam — new bullet
  behaviour = a new `.tres` (or a new `Effect` subclass), no firing-path change. Use
  when a task touches bullet/weapon payload data — "add a new bullet type", "make this
  gun do X on hit", "new Effect", "data-driven damage/knockback", "tint the bullet",
  "author a CastData / .tres for a weapon", "extend the Cast system" — or when wiring a
  weapon slot to a cast. Lists the PARKED pieces (CastManager, prereq/cost gate, AoE
  resolver, EffectMapComponent, HealSelf) so a builder knows what is intentionally not
  built. Game-specific — NOT a framework skill; the engine-agnostic pattern behind it is
  `godot-data-driven-effect-composition`. Leans on `godot-travelling-projectile-3d`
  (firing/despawn), `godot-fps-enemy-combat` (the apply_damage/on_hit seam) and
  `godot-composition` — cross-references them, does not duplicate.
---

# DiceOfFate Cast system (data-driven projectile payload)

A weapon's bullet behaviour is **authored data, not code**. The resource graph is named
the **Cast system**; the firing node keeps the name `Projectile`. Why this way: every new
weapon identity (damage amount, knockback, colour, effect mix) becomes a new `.tres` an
author edits, never a firing-path edit. The split that makes it compose — WHAT (`Effect`)
× WHOM (`TargetResolver`), carried by a `GameContext` DTO, applied **inside the spawned
projectile** (the source's spawned-object rule) — is the engine-agnostic pattern documented
separately in `godot-data-driven-effect-composition`. THIS skill is the concrete DiceOfFate
contract a builder follows to extend it.

## Requirements

- `godot-code-rules` applied — every `.gd` here is strict typed; the duck-typed seams go
  through `has_method` guards + `@warning_ignore("unsafe_method_access")` (never widen
  warning levels).
- `godot-travelling-projectile-3d` understood — the Projectile firing/despawn lifecycle is
  unchanged; the Cast adds only a `cast_data` stamp + an apply loop on hit.
- `godot-fps-enemy-combat` understood — `DamageEffect` and the fallback path call the
  duck-typed `apply_damage(amount)` / `on_hit()` seam that skill owns. The Cast does not
  redefine shootability; it routes into it.
- `godot-composition` — `CastData` / `Effect` / `TargetResolver` are data Resources (calls
  down via duck-typed apply); `GameContext` is a plain `RefCounted` DTO. No autoload, no
  manager (parked).

## Project conventions (the concrete graph)

The system lives under `tools/lib/cast/` (shared cross-entity logic per CLAUDE.md):

| File | `class_name` | Role |
|---|---|---|
| `cast_data.gd` | `CastData` (extends `Resource`) | `@export effects: Array[Effect]`, `@export resolver: TargetResolver`, `@export bullet_color: Color = Color(1,1,0)` |
| `effect.gd` | `Effect` (extends `Resource`) | base; virtual `apply(target: Node, ctx: GameContext) -> void` (no-op) |
| `target_resolver.gd` | `TargetResolver` (extends `Resource`) | base; virtual `resolve(ctx: GameContext) -> Array[Node]` (returns `[]`) |
| `game_context.gd` | `GameContext` (extends `RefCounted`) | DTO: `instigator`, `target`, `hit_pos`, `hit_normal`, `instigator_pos` |
| `damage_effect.gd` | `DamageEffect` (extends `Effect`) | `@export amount: int = 1`; duck-types `target.apply_damage(amount)` |
| `knockback_effect.gd` | `KnockbackEffect` (extends `Effect`) | duck-types `target.apply_knockback(ctx.instigator_pos)` |
| `hit_target_resolver.gd` | `HitTargetResolver` (extends `TargetResolver`) | returns `[ctx.target]` (the body hit); `[]` if target null |

Firing wiring (do NOT change the lifecycle, only data):
- `entities/weapon/gun.gd` — `@export var cast_data: CastData` (null = fallback path, valid).
  In `_fire()` after instancing: `projectile.cast_data = cast_data` and
  `projectile.instigator_pos = _muzzle.global_position`.
- `entities/projectile/projectile.gd` — `cast_data` is a property with a setter that tints
  the mesh on stamp (`_tint_mesh`); `_on_body_entered` runs the apply chain (lines ~104-123).
- Authored casts (one `.tres` per bullet identity), in `entities/weapon/`:
  `pistol_cast.tres` (yellow, `[Damage(1), Knockback]`), `heavy_cast.tres` (red, `[Damage(3),
  Knockback]`), `stun_cast.tres` (cyan, `[Damage(1), Knockback]`). All use `HitTargetResolver`.
- Weapon slots: Q cycles 3 slots — Pistol(0)=pistol_cast, Rifle(1)=heavy_cast,
  Carbine(2)=stun_cast. `carbine.tscn`/`rifle.tscn` are inherited scenes off `weapon.tscn`.

## Steps

### The firing rule (what happens per shot — read once)

1. Gun owns a `CastData` (`@export cast_data`). On `_fire()` it instances the projectile,
   then **stamps**: `projectile.cast_data = cast_data` (+ `instigator_pos`). Stamp may be
   null — that is the non-cast fallback, not an error.
2. The projectile's `cast_data` setter immediately tints its mesh from `bullet_color`
   (`_tint_mesh` make-uniques each `StandardMaterial3D` so instances don't share, sets
   albedo + emission). Null stamp → scene-default material kept (no regression).
3. On `_on_body_entered(body)`, the projectile emits `hit(body, normal, hit_pos)` (signals
   up to the weapon for hitmarker feedback — `godot-fps-enemy-combat`), then runs the
   **apply chain it owns**:
   ```gdscript
   if cast_data != null and cast_data.resolver != null:
       var ctx := GameContext.new()
       ctx.instigator = self
       ctx.target = body
       ctx.hit_pos = hit_position
       ctx.hit_normal = normal
       ctx.instigator_pos = instigator_pos
       var targets: Array[Node] = cast_data.resolver.resolve(ctx)
       for t: Node in targets:
           for eff: Effect in cast_data.effects:
               eff.apply(t, ctx)
   else:
       if body.has_method("on_hit"):
           @warning_ignore("unsafe_method_access")
           body.on_hit()        # fallback: bare 1-damage path, non-cast guns
   ```
   Then `_play_hit_sfx()` + `queue_free()`. Effect application living inside the projectile
   (not a central manager) is deliberate — see the parked `CastManager` below.

### Add a new Effect

1. New file `tools/lib/cast/<name>_effect.gd`, `class_name <Name>Effect`, `extends Effect`.
2. `@export` its tunables (e.g. `@export var amount: int`). Override
   `apply(target: Node, ctx: GameContext) -> void`. Read context off `ctx`
   (`ctx.instigator_pos`, `ctx.hit_normal`, …).
3. Reach the target through a **guarded duck-typed seam** — never assume a type:
   ```gdscript
   func apply(target: Node, _ctx: GameContext) -> void:
       if not target.has_method("apply_slow"):
           return
       @warning_ignore("unsafe_method_access")
       target.apply_slow(amount)
   ```
   If the seam method (`apply_slow`) doesn't exist on the shootables yet, adding it is its
   own slice on `enemy.gd`/`target.gd`/`npc.gd` (mirror how `apply_damage` was added) —
   coordinate with `godot-fps-enemy-combat`.
4. Use it by adding a `sub_resource` of the new script to any cast `.tres` `effects` list.

### Add a new bullet type (new CastData .tres + colour + weapon slot)

1. Copy an existing cast `.tres` (e.g. `stun_cast.tres`) as the format template. A cast
   `.tres` is `[gd_resource type="Resource" script_class="CastData"]` with one
   `ext_resource` per script, one `sub_resource` per effect + the resolver, then:
   ```
   [resource]
   script = ExtResource("1")
   effects = [SubResource("1"), SubResource("2")]
   resolver = SubResource("3")
   bullet_color = Color(0.2, 0.8, 1, 1)
   ```
2. Set `bullet_color` (distinct so the bullet reads at a glance) and the `effects` mix
   (length and `amount` differences are what prove composition).
3. Assign it to a weapon: either set `cast_data` on an existing Gun, or make a new inherited
   weapon scene off `weapon.tscn` (as `carbine.tscn` does) and set its `cast_data`. Wire its
   slot in the weapon controller's Q-cycle (default 3 slots).
4. No firing code changes — same Gun/Projectile machinery, different data → different bullet.

### Smoke-test expectation

The data path is gated headless by `tools/smoke_cast.gd` (`godot-runtime-smoke`). It does
NOT drive real physics; it **replicates the projectile apply lines** (build `GameContext` →
`resolver.resolve(ctx)` → nested `for eff: for t:` loop) against a loaded `.tres`, so the
test tracks the real path. Every new cast/effect must extend it with an AUTHORED-`.tres`-driven
assert: load the `.tres`, run the resolve+apply loop vs a real `Enemy`/`StubTarget`, assert
the observable outcome (`died` emitted once, `apply_knockback` reached, authored `amount`
one-shots the matching health). A direct `eff.apply()` call alone is NOT enough — drive it
from the loaded resource through the loop.

## Parked (intentionally NOT built — do not assume these exist)

| Parked piece | Why parked / when it earns its place |
|---|---|
| Standalone `CastManager` component on the weapon | The Gun's stamp + the projectile's own apply loop covers a single hit-driven projectile. A manager earns its place only for instigator-side effects (HealSelf) or multi-stage spawns. |
| Prereq / cost / requirement gate (mana / class / cooldown-as-mana) | No resource system; firing stays `gun.gd`'s `try_fire()` ammo+cooldown gate. |
| AoE / radius `TargetResolver` | Only `HitTargetResolver` ships. A radius/chain resolver is parked until an explosive/chain bullet earns it. |
| `EffectMapComponent` (editor-key `on_tick`/`on_bounce` event→effect maps) | The projectile's single `hit` seam suffices for v1; needed only for multi-event entities (blizzard-zone, chain-bounce). |
| `HealSelf` / instigator-targeted effects + instigator resolver | The player has no local health/heal seam (routed via WaveManager); inventing one is its own slice. |
| New status Effects (Slow / DoT / Pierce) | Stun Dart reuses Damage+Knockback; a real status effect is a new `Effect` slice. |
| Per-bullet trail / impact-VFX / SFX colour tint | Mesh tint reads 3 distinct bullets; tinting trail/decal/VFX is polish. |

## Verification checklist

- `tools/validate.sh` passes (strict-typed; the cast `.tres` files + any new weapon scene load).
- `$GODOT --headless --path . --script tools/smoke_cast.gd` → all asserts PASS, exit 0,
  including each new cast's authored-`.tres` assert.
- `godot-verify`: `weapon.tscn`, `rifle.tscn`, `carbine.tscn` load + render; the projectile renders.
- Human F5 in `firing_yard`: Q-cycle the guns, fire each → bullets are visibly the authored
  colours (yellow / red / cyan); a `Damage(1)` bullet does NOT one-shot a 3-health tank, a
  `Damage(3)` bullet does; the knockback bullets push the enemy back, the Damage-only one does not.
- A Gun with `cast_data == null` still kills a grunt in one shot via the fallback `on_hit()`
  path (no regression for non-cast weapons).

## Error → Fix

| Symptom | Fix |
|---|---|
| New `Effect` does nothing on hit | The target lacks the seam method — `apply` no-ops by design. Add the seam method to the shootable (`godot-fps-enemy-combat`) or check the target actually exposes it. |
| Bullet not tinted / wrong colour | `bullet_color` only applies when `cast_data != null` (the setter tints on stamp). Confirm the Gun's `cast_data` is assigned and the mesh is a `MeshInstance3D` with a `StandardMaterial3D`. |
| All bullets share one tint / earlier shot recolours | `_tint_mesh` must `duplicate()` the material (make-unique) before setting colour; without it instances share one resource. |
| `UNSAFE_METHOD_ACCESS` fails parse | Annotate the duck-typed seam call with `@warning_ignore("unsafe_method_access")` immediately above it after a `has_method` guard; never lower warning levels. |
| `.tres` won't load / "Can't load script_class CastData" | Each `ext_resource` script path must be correct `res://tools/lib/cast/…`; `script_class="CastData"` on line 1; sub_resources reference the right `ExtResource` id. |
| Effects fire but no targets | `resolver` is null or returns `[]`. The apply chain requires `cast_data.resolver != null`; `HitTargetResolver` returns `[]` when `ctx.target == null`. |
| Non-cast gun stopped killing | The fallback path runs only when `cast_data == null`; if you stamped a cast with a null/empty resolver it takes the cast branch and no-ops. Leave `cast_data` unset for the bare path. |
| Double-hit / effect applied twice | `body_entered` is connected `CONNECT_ONE_SHOT`; don't reconnect it, and keep the `queue_free()` at the end of `_on_body_entered`. |

Game-local skill authored for DiceOfFate from the project's own built Cast system
(`tools/lib/cast/`, `design/cast_system.md`, `design/bullet_types.md`); no external library source.
