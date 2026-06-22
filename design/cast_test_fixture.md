# Cast System Test Fixture (one item per step, end-to-end)

**Goal** — Basic combat exercises + asserts EVERY layer of the data-driven Cast path from an AUTHORED `.tres`: CastData → effects-LIST → Effect×TargetResolver pairing → GameContext → duck-typed seam. Proves the system composes from data, not just from runtime-constructed objects.

## Context (already built — do NOT rebuild)
- `tools/lib/cast/`: `CastData`, `Effect`, `TargetResolver`, `GameContext`, `DamageEffect(amount)`, `KnockbackEffect`, `HitTargetResolver` — all present, strict-typed.
- `entities/weapon/pistol_cast.tres` = `[DamageEffect(amount=1), KnockbackEffect]` + `HitTargetResolver`; stamped by `gun.gd` (`@export cast_data`), applied by `projectile.gd` (apply loop, lines 99-110).
- Seams `apply_damage(amount)` / `apply_knockback(pos)` on enemy/target/npc/player.
- `tools/smoke_cast.gd` has 7 asserts (effect direct-call, resolver, fallback, pistol_cast loads).

## Gap this slice closes
smoke_cast proves Damage(3) only via `DamageEffect.new()` (runtime object), and proves pistol_cast `.tres` LOADS but never FIRES it through the apply loop. Missing: an authored multi-effect cast distinct from pistol, driven through the real resolve→list→apply chain, asserting data-authored amounts reach the seam. That is the one-per-step E2E proof.

## Scope (in)
- **One authored asset**: `entities/weapon/heavy_cast.tres` — `CastData` with `effects = [DamageEffect(amount=3), KnockbackEffect]`, `resolver = HitTargetResolver`. Strict typed `.tres` (mirror pistol_cast.tres format; new sub_resource amount=3). NO new weapon scene — reuse existing guns; assigning heavy_cast to a weapon is parked.
- **Extend `tools/smoke_cast.gd`** — add 2 asserts that drive the FULL chain from a loaded `.tres` (replicating projectile.gd lines 99-110: build `GameContext` → `resolver.resolve(ctx)` → nested `for eff: for t:` apply loop), NOT direct `eff.apply`:
  - **E2E-A (pistol_cast vs grunt)**: load `pistol_cast.tres`, build ctx with `target=grunt(health=1)`, run resolve+apply loop → assert `died` emitted once AND `apply_knockback` reached (proves list of 2 effects + HitTargetResolver pairing fire from authored data).
  - **E2E-B (heavy_cast vs tank)**: load `heavy_cast.tres`, ctx `target=tank(health=3)` → run loop → assert `died` once in a single cast (proves authored `amount=3` from `.tres` drives the seam, distinct from pistol).
- Keep all 7 existing asserts; add an 8th: `heavy_cast.tres` loads as `CastData`, 2 effects, `effects[0] is DamageEffect` with `amount == 3`, `resolver is HitTargetResolver`.

## Scope (out)
- New "special" weapon scene / wiring heavy_cast to a Gun — one CastData `.tres` proves the data path; a weapon scene adds no test coverage. Parked.
- Driving `projectile._on_body_entered` via real physics — it's private + needs a collision frame; the apply chain (resolver+loop) is a pure data path, so the smoke replicates those exact lines with the loaded resource. Same coverage, no physics-frame flakiness.
- Standalone `CastManager`, prereq/requirement gate, AoE/radius `TargetResolver`, `EffectMapComponent`, HealSelf/instigator resolver — all stay parked per cast_system.md.

## Acceptance
- `tools/validate.sh` passes (strict-typed; heavy_cast.tres loads).
- `$GODOT --headless --path . --script tools/smoke_cast.gd` → all asserts PASS, exit 0. New asserts: E2E-A (pistol_cast list+pairing fire from `.tres`), E2E-B (heavy_cast authored amount=3 one-shots health=3 tank), 8th (heavy_cast.tres shape).
- Coverage check: each step has ≥1 AUTHORED-`.tres`-driven assert — CastData (loads, 2 files), effects LIST (both effects fire in order), Effect (Damage amount + Knockback), TargetResolver (HitTargetResolver returns target), GameContext (carries target + instigator_pos to knockback).

## Skill notes
- `godot-runtime-smoke` — extend existing `tools/smoke_cast.gd`; reuse `StubTarget` only where a real enemy isn't needed; use `enemy.tscn` + `died` for E2E asserts as the file already does. New tests build `GameContext` + run the resolve/apply loop, mirroring `projectile.gd` 99-110 (keep them identical so the smoke tracks the real path).
- `godot-code-rules` — `.tres` sub_resources strict; no new `.gd` (only the `.tres` + smoke edits). Loaded resources typed `as CastData`.
- `godot-fps-enemy-combat` — unchanged; relies on existing `apply_damage`/`died` contract.

## Later
- Wire heavy_cast.tres to an actual weapon (shotgun/heavy) when a second weapon earns a distinct feel.
- Per-weapon casts, requirement gate, AoE resolver, CastManager — parked in cast_system.md.

## Open questions
- None blocking.
