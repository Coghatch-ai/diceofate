# Elemental Bullets + Bigger Abilities HUD

**Goal** — the 5 hotbar bullets become a readable ELEMENTAL set (ice/fire/electric + 2 more), each with a colored projectile and a signature status effect, shown on a larger, clearer hotbar.

## Data-driven foundation (build first, this feature is its first entries)

The system is already data-driven: `CastData` `.tres` = `Effect[]` × `TargetResolver` + `bullet_color` + ammo, stamped by `Gun` onto each `Projectile`. We do NOT rebuild it. Elements = new data:
- New `DamageType.Kind` enum entries (data on the existing typed-damage seam).
- New `Effect` subclasses (`BurnEffect`, `SlowEffect`, `ShockEffect`) composed into the 5 existing `.tres` — same pattern as `DamageEffect`/`KnockbackEffect`.
- A small reusable `StatusReceiver` component so DoT/slow/shock have somewhere to live per-frame (status effects are stateful over time; a stateless `Effect.apply()` can only START them).
- Resistance reuses `HealthComponent.resistances` (Dictionary `Kind → float`), already built.

The 5 elements are the FIRST 5 entries in this system, not one-offs. Add a 6th element later = one new `.tres` (+ maybe one new `Effect`), no firing-path change.

## The 5 elements (decisions — autonomous)

| Slot | Key | Cast file (re-themed in place) | Element | DamageType.Kind | bullet_color | Signature status effect |
|---|---|---|---|---|---|---|
| 0 | Q | pistol_cast.tres | ELECTRIC | ELECTRIC | yellow `(1,1,0)` | SHOCK: brief movement stun |
| 1 | E | heavy_cast.tres | FIRE | FIRE | red `(1,0.2,0.15)` | BURN: fire DoT over time |
| 2 | R | stun_cast.tres | ICE | ICE | blue `(0.3,0.6,1)` | SLOW: movement chill |
| 3 | T | blast_cast.tres | POISON (free pick #1) | POISON | green `(0.4,0.9,0.2)` | BURN-style DoT, poison-typed (reuses BurnEffect, different type) |
| 4 | Y | rapid_cast.tres | KINETIC (free pick #2) | PHYSICAL | white `(1,1,1)` | none — fast, no-frills physical (knockback only) |

**Free-pick rationale:** POISON gives a second DoT flavor that reuses `BurnEffect` (proves the data-driven win — one Effect, two elements, differing only by `damage_type`). KINETIC = the plain physical baseline (uses existing `PHYSICAL`, no new type), so the set has a "vanilla" option and we add only 3 new types not 5. Colors honor user: blue=ICE, red=FIRE, yellow=ELECTRIC exactly; green/white are the free picks.

**User constraint check:** blue→ICE ✓ red→FIRE ✓ yellow→ELECTRIC ✓ (slots re-themed; Q stays yellow=ELECTRIC, E stays red=FIRE; R recolored cyan→blue for ICE).

## New DamageTypes (extend `tools/lib/damage_type.gd` ONLY)

```
enum Kind { PHYSICAL = 0, FIRE = 1, ICE = 2, ELECTRIC = 3, POISON = 4 }
```
Also widen `DamageEffect.damage_type` `@export_enum` string list to match (`"PHYSICAL","FIRE","ICE","ELECTRIC","POISON"`).

## New Effects (subclass `Effect`, author as `.tres` sub-resources, strict-typed)

All three START a status on the target via a duck-typed `StatusReceiver` seam (mirrors `DamageEffect`'s `has_method` guard). They do NOT tick themselves.

- `BurnEffect` (`tools/lib/cast/burn_effect.gd`) — `@export dps:int`, `@export duration:float`, `@export damage_type:int` (FIRE or POISON). `apply()` → `target.add_status_burn(dps, duration, damage_type)` if present.
- `SlowEffect` (`tools/lib/cast/slow_effect.gd`) — `@export slow_factor:float` (0.4 = 40% speed), `@export duration:float`. `apply()` → `target.add_status_slow(slow_factor, duration)`.
- `ShockEffect` (`tools/lib/cast/shock_effect.gd`) — `@export stun_duration:float`. `apply()` → `target.add_status_shock(stun_duration)`.

Guard pattern each (copy `DamageEffect`): `if not target.has_method("add_status_X": return` + `@warning_ignore("unsafe_method_access")`.

## StatusReceiver component (`tools/lib/status_receiver.gd`, `extends Node`)

Reusable child node (composition; signals up / calls down). Holds active status timers, ticks in `_process(delta)`:
- `add_status_burn(dps, duration, type)` — accumulates fractional damage, applies `int` ticks via the parent's `apply_damage(n, type)` (so resistances apply); ends at duration.
- `add_status_slow(factor, duration)` — emits `slow_changed(factor)`; emits `slow_changed(1.0)` at expiry. Parent multiplies `move_speed` by current factor.
- `add_status_shock(duration)` — emits `shock_started` / `shock_ended`; reuses the existing knockback-stun gate in `enemy.gd` (`_stun_timer`) by setting it, so velocity drive is skipped.

Enemy wires it: add `StatusReceiver` child to `enemy.tscn`, connect `slow_changed` → a setter that scales nav speed, route `shock` to the existing stun path. Player can ignore (enemies are the targets; `HitTargetResolver` returns the hit body — enemies).

**Minimal:** stack rule = refresh (re-apply resets timer, no stacking math). One burn, one slow, one shock at a time per receiver.

## Cast remapping (edit the 5 existing `.tres` in place — keeps Gun/tracker/HUD plumbing)

Keep each cast's existing resolver, ammo (`max_ammo`/`ammo_cost`/`ammo_regen`), knockback. Change: `bullet_color`, the `DamageEffect.damage_type`, and ADD one status `Effect` sub-resource (except KINETIC). Ammo stays as authored today (Q 30/3.0, E 8/0.5, R 12/1.0, T 5/0.4, Y 20/2.0) — already balanced, no reason to churn.

- Q electric: DamageEffect type=ELECTRIC + ShockEffect(stun=0.4) + Knockback. color yellow.
- E fire: DamageEffect type=FIRE + BurnEffect(dps=2,dur=3,type=FIRE) + Knockback. color red. (the teed-up burning feature lands here.)
- R ice: DamageEffect type=ICE + SlowEffect(0.4,dur=2.5) + Knockback. color blue.
- T poison: DamageEffect type=POISON + BurnEffect(dps=1,dur=5,type=POISON) + Knockback. keeps RadiusTargetResolver(3.0) — poison cloud. color green.
- Y kinetic: DamageEffect type=PHYSICAL only. color white. (unchanged behavior, recolor only.)

## VFX hooks (right skill per use)

- BURN aura (fire + poison): `godot-looping-particle-vfx` — persistent emitter attached to target while burn active, removed by `StatusReceiver` on expiry (`emitting=false` + free).
- Impact bursts (all): `godot-oneshot-vfx` — element-tinted hit burst routed off existing `hit` seam.
- ICE/ELECTRIC: one-shot tinted impact only for the slice (no persistent aura) — keeps it small. Persistent ice/electric auras → Later.

## HUD enlargement (`entities/hud/arena_hud.gd`, `_build_hotbar_slots`)

Current: slot `52×56`, swatch `52×10`, key font 11, ammo font 13. Too small. Enlarge:
- Slot `custom_minimum_size` → `96×104`.
- Swatch (element color band) → `96×22`.
- Key label font → 20; ammo label font → 22.
- Add element NAME label (font 14) under the key: ["ELEC","FIRE","ICE","POIS","KIN"]. Add `SLOT_NAMES` const array.
- Hotbar spacing: set `_hotbar.add_theme_constant_override("separation", 10)`.
- Active highlight: keep modulate scheme; bump inactive dim to `0.45` and add a `2px` bright border on active via a `StyleBoxFlat` on the active slot (or a border ColorRect) for stronger read.
- Swatch colors array updated to the 5 element colors above.

All sizes are `Control` minimums, resolution-independent (anchored BottomRight already). No new scene nodes required beyond the per-slot name Label built in code.

## Ordered slices (each independently buildable + verifiable)

**Slice A — types + status effects + receiver wiring** (godot-combat)
- Extend `DamageType.Kind` (+ICE,ELECTRIC,POISON); widen `DamageEffect` enum list.
- Add `BurnEffect`/`SlowEffect`/`ShockEffect`.
- Add `StatusReceiver` component + wire to `enemy.tscn`/`enemy.gd` (slow scales speed, shock reuses stun gate).
- Smoke: extend `smoke_typed_shield.gd` style — assert ICE/POISON resistance math; new `smoke_status.gd`: burn ticks reduce health over time, slow emits factor<1 then 1.0, shock sets stun gate.
- Acceptance: `validate.sh` green; smoke asserts pass. Independently buildable (no `.tres`/HUD change yet; existing casts still PHYSICAL/FIRE).

**Slice B — re-theme the 5 casts + colors + VFX hooks** (godot-combat + godot-visuals)
- Edit 5 `.tres`: colors, damage types, add status Effect sub-resources per table.
- VFX: looping burn aura on burn start/stop; oneshot tinted impacts per element.
- Smoke: extend `smoke_cast.gd` — each cast resolves its status Effect onto a stub receiver (burn/slow/shock method called with authored args).
- Acceptance: F6 fire each Q/E/R/T/Y → projectile shows element color; enemy burns/slows/shocks visibly; `validate.sh`+smoke green. Depends on A.

**Slice C — enlarge HUD** (godot-visuals)
- Apply sizes/fonts/names/border above in `_build_hotbar_slots`; update swatch colors.
- Acceptance: F5 → hotbar slots large, element name+color+ammo readable at gameplay res; active slot clearly highlighted; ammo updates on fire. `validate.sh` green. Independent of A/B (pure UI; can build in parallel, but colors should match B — list B's colors as the source).

## Skill notes
- `cast-system` / `godot-data-driven-effect-composition`: new Effects + `.tres` edits, no firing-path change.
- `godot-code-rules`: strict typed GDScript, author data as `.tres`, `@export` typed.
- `godot-fps-enemy-combat`: `apply_damage(amount,type)` + duck-typed seam reused for burn ticks.
- `godot-composition`: `StatusReceiver` is a child component, signals up.
- `godot-looping-particle-vfx` (burn aura) / `godot-oneshot-vfx` (impacts).
- `godot-runtime-smoke`: per-slice headless asserts above.

## Later (parked)
- Persistent ice/electric auras (frost mist, arc sparks) — only impact VFX now.
- Status stacking math (currently refresh-only).
- Resistance/weakness tuning per enemy archetype (e.g. fire enemy immune to burn).
- Element on the player-damage path (only enemies receive status now).
- A 6th+ element / element-swap UI / chain-lightning ShockEffect to nearby enemies.
- Element icons (glyphs) — name labels only for now.

## Open questions
None — all decisions made autonomously above.
