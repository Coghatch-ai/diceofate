# Immunity Teaching Archetypes

**Goal** — Enemies that are IMMUNE to one bullet type so the player must switch bullets. Authored purely as DATA on existing `EnemyArchetype.resistances` — no new code, no per-enemy class.

## Foundation already exists (confirmed in repo)

`EnemyArchetype.resistances: Dictionary` = `{DamageType.Kind(int) → float mult}`, `0.0 = immune`. `HealthComponent.apply_damage(amount, type)` applies it. `archetypes/immune_fire.tres` already sets `{1: 0.0}`. The data-driven immunity system is THIS system; these archetypes are its first entries.

DamageType.Kind ints: PHYSICAL=0, FIRE=1, ICE=2, ELECTRIC=3, POISON=4, ACID=5.
HUD slot → kind: Q=ELECTRIC(3), E=FIRE(1), R=ICE(2), T=POISON(4), Y=PHYSICAL(0).

## Scope (in)

Author one `.tres` per teaching enemy in `archetypes/`, each a copy of `grunt.tres` with one immunity + a matching `tint_color` and `display_name` (so the immunity reads visually). Zone A needs:

- **`immune_fire.tres`** — `resistances = {1: 0.0}`, tint red. ALREADY EXISTS — reuse for A.1 (teaches: not FIRE → use ICE/another).
- **`immune_ice.tres`** — `resistances = {2: 0.0}`, tint blue, `display_name = "IceImmune"`. NEW (A.2 — teaches: not ICE → use FIRE).
- **`immune_kinetic.tres`** — `resistances = {0: 0.0}`, tint white/grey, `display_name = "KinImmune"`. NEW (A.M — teaches: plain bullets useless, must use an element).

Keep `max_health = 2` (grunt baseline) so the lesson is "wrong bullet does nothing", not "bullet-sponge". `score_value`, speeds = grunt defaults.

## Scope (out)

- New `resistances` schema / new DamageType kinds — exist already (cut).
- Partial resistance (0.5) teaching tiers — v1 is binary immune for a clear lesson (cut: scope; parked).
- Multi-immunity enemies / immune bosses beyond the existing `boss_warden {4:0.0}` (cut: later zones).
- Zone B/C/D archetypes (ELECTRIC-immune, POISON-immune, combos) — later DATA (cut: vertical slice).

## Acceptance

- Each new `.tres` loads (validate.sh / editor) with the correct `resistances` int key.
- In-engine (covered by slice-4 F5 look): shooting the matching bullet at the immune enemy deals 0 damage (no hit number / no death); a different bullet kills it.
- Optional smoke: instance enemy with `immune_ice`, `apply_damage(2, ICE)` → still alive; `apply_damage(2, FIRE)` → dies.

## Skill notes

- `godot-data-driven-enemy` — archetype `.tres` drives the one generic enemy scene; immunity is a stat field, not a behaviour node.
- `cast-system` — bullets already carry their `DamageType` via CastData; no change needed.
- `godot-resource-registry` — if encounters reference archetypes by string id, register; else direct `@export` ref in the encounter is fine.

## Later

- ELECTRIC/POISON/ACID-immune archetypes for zones B/C/D.
- Resistance tiers (0.5) for "hard but not immune" enemies.
- Visual immunity shader hint (e.g. element-colored shield flash on a wrong-bullet hit).

## Open questions

(none.)
