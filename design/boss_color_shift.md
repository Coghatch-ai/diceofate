# Boss Color-Shift (Prism Warden)

**Goal** — The corridor's final boss visibly cycles through colors and can ONLY be hurt by the bullet matching its current color; depleting each color's HP chunk advances it to the next color and grows it one step; after the last color it explodes (AoE + knockback + shockwave) and ends the run.

This is the **inverse** of the corridor's teaching enemies (those are immune to ONE type; the boss is immune to ALL but one). It is the **first entry** in a reusable data-driven `VulnerabilitySchedule` system — the color list, per-color HP chunks, grow steps, and explode params are DATA on `BossData`, editable without code. New behaviour (more colors, different grow curve, timer mode later) = edit the `.tres`.

## Systemic framing (data-driven first)

Build the SCHEDULE system, not a bespoke boss. New fields on `BossData` (the existing boss tunables resource):

- `color_phases: Array[BossColorPhase]` — ordered list. Each `BossColorPhase` (new tiny `Resource` in `tools/lib/enemy/`): `damage_type: DamageType.Kind`, `phase_hp: int` (HP chunk for this color), `body_scale: float` (size while this color is active), `albedo: Color`, `emission: Color`.
- `explode_radius: float`, `explode_damage: int`, `explode_knockback: float`, `explode_vfx_scene: PackedScene` (shockwave), `explode_burst_scene: PackedScene` (oneshot death burst).

The boss's "only the current color hurts it" = at each phase, `HealthComponent.resistances` is rebuilt to `0.0` for every `DamageType.Kind` EXCEPT the active phase's type (which is `1.0`). This reuses the EXISTING `resistances` damage path (`HealthComponent.apply_damage(amount, type)` already multiplies) — no new immunity code. Boss `on_hit()` already routes a hit through HealthComponent; the gating is purely the swapped resistances dict.

## Scope (in)

**Combat slice (owns `boss.gd` + data):**
- New `BossColorPhase` resource + the `color_phases` / explode fields on `BossData`.
- First data entry `archetypes/boss_prism.tres`: 3 phases — FIRE(red)→ICE(blue)→ELECTRIC(yellow). Per-phase `phase_hp` summing to a beatable total; `body_scale` ramp 2.0 → 2.8 → 3.6 (final). Resistances rebuilt per phase (active type 1.0, all others 0.0).
- Boss runtime: on `_ready` enter phase 0 (set resistances + scale + signal color). On HealthComponent depletion of the current phase's `phase_hp` (track damage dealt vs `phase_hp`; when chunk gone) → advance to next phase: rebuild resistances, grow scale (tween), emit a `color_changed(albedo, emission)` signal for visuals. After LAST phase chunk gone → `explode()`.
- `explode()`: AoE — player within `explode_radius` takes `explode_damage` via existing duck-typed `apply_damage`, knocked back via existing `apply_knockback(global_position, explode_knockback)`; spawn `explode_vfx_scene` (shockwave) + `explode_burst_scene` (oneshot) at boss pos; then death → existing `died.emit` / `complete_run()` path. Explosion REPLACES the plain `_flash_and_die` visual.
- Existing charge/volley/slam mechanic rotation KEEPS RUNNING during color phases (no freeze) — confirmed default.

**Visuals slice (owns material readability + explosion VFX):**
- Boss body material swaps albedo + emission to the current phase color on `color_changed` (reuse the per-mesh override-material seam already in `boss.gd._flash_hit`). The current color is the readability contract: player reads body color → picks matching bullet. Emission ON so it reads at distance in the wall-less room.
- Color-swap visible tell: brief flash/pulse on advance (reuse the telegraph scale-pulse + a one-frame white flash) so the player notices the change.
- Explosion VFX: one shockwave ring (reuse `slam_vfx` ShockwaveRing pattern, scaled to `explode_radius`) + one oneshot death burst tinted to the LAST phase color. `godot-oneshot-vfx` / `godot-decal-vfx` seams; no new VFX framework.

## Scope (out)

- Timer / hybrid color-advance mode — SEGMENTED-HP only for v1 (cut: one mode to verify; parked as a schedule option).
- 5-color / POISON / PHYSICAL phases — 3 distinct-tint colors for the POC (cut: scope; pure data later).
- Per-phase distinct attack patterns (e.g. only volley while red) — mechanic rotation stays type-agnostic (cut: scope).
- Minion adds during the boss fight (cut: parked; corridor overview already parks boss-room waves).
- Partial-resistance phases (0.5) — binary immune/vulnerable for a clear lesson (cut).

## Acceptance

- `boss_prism.tres` + `BossColorPhase` `.tres` parts load (validate.sh / editor).
- Headless smoke (`godot-runtime-smoke`): instance Prism boss in phase 0 (FIRE). `apply_damage(n, ICE)` and `apply_damage(n, ELECTRIC)` → HP unchanged (wrong color, 0). `apply_damage(phase_hp, FIRE)` → advances to phase 1, `color_changed` emitted, `body_scale` grew. Repeat through phase 2; final chunk → `explode()` fires AoE (player apply_damage + apply_knockback called) and `died` emitted exactly once.
- One human F5 look in the boss room: boss visibly cycles red→blue→yellow, grows each step; only the matching bullet damages it; wrong bullet does nothing; final hit = explosion + knockback + run ends.

## Skill notes

- `cast-system` — bullets already carry `DamageType` via CastData; no bullet change. Color→type map matches existing: FIRE=E, ICE=R, ELECTRIC=Q.
- `godot-fps-enemy-combat` — boss `on_hit()` / HealthComponent resistances are the gate; reuse the apply_damage(amount, type) seam, do not add a parallel immunity check.
- `godot-oneshot-vfx` / `godot-decal-vfx` — explosion = shockwave ring + death burst from existing pools; no new VFX system.
- `godot-resource-registry` — `boss_prism.tres` is referenced directly by the boss-room encounter `@export`; registry optional.
- Wall-less room (already built): explode knockback flings player across open ground — no wall pin; that is intended. Keep `explode_radius` < room half-extent so it's dodgeable.
- `godot-code-rules` + `tools/validate.sh` gate; strict typed GDScript; no Transform3D literals.

## Later

- `VulnerabilitySchedule` timer / hybrid advance modes as a data flag.
- 5-color and combo (immune-to-two) phases for harder bosses.
- Per-phase attack-pattern overrides (volley while red, slam while blue).
- HUD pip showing current required bullet / phases remaining.
- Element-shield flash on a wrong-bullet hit (visual "no effect" feedback).

## Open questions

(none.)
