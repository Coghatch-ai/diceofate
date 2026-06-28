# Boss Attack Components + Always-Moving Behaviour Loop

**Goal** — The boss runs a varied, always-moving attack loop where every mechanic visibly DOES something; its attack set is authored as data (an ordered list of attack components), not hardcoded.

## Problem (what's wrong today)

- `boss.gd` is data-driven for **tunables** (`BossData` `.tres`) but the **attack SET is hardcoded**: a fixed `Phase` enum + `match _mechanic_index % 3` cycling exactly Charge → Volley → Slam. No way to add, remove, or reorder a mechanic without editing code.
- "Only CHARGE does something": `boss_prism.tres` and `boss_slime.tres` leave `volley_projectile_scene` and `slam_vfx_scene` **null**, so `_tick_volley` instantly bails to recover (no projectile) and `_execute_slam` applies an invisible instant AoE (no telegraph, no ring). Two of three mechanics are dead purely from missing payload.
- The IDLE / TELEGRAPH / RECOVER ticks **zero XZ velocity** — the boss literally stands still between mechanics. User: *"the boss needs to be always moving."*
- The color/form-change schedule (`color_phases` + `color_cycle_interval`) currently dominates the read — it's *"almost the entire changing-form"* and feels unnatural as the main behaviour. It should be a vulnerability side-channel, not the loop.
- No `AnimationPlayer` / skeletal clips exist anywhere. "Animations" today = scale-tween telegraphs. This overhaul stays with scale/tween tells (real skeletal anims are parked).

## System shape (decided)

A boss = `BossData` (stats / cadence / phases) **+ an ordered `Array[PackedScene]` of `BossAttack` components**. This **mirrors the existing enemy system** (`EnemyArchetype.behaviours: Array[PackedScene]` of `EnemyBehaviour` nodes bound via `bind()` / seam methods) — we extend that proven pattern, NOT a parallel one. Each `BossAttack` owns its own telegraph + execute + (optional) per-frame movement, instanced under a `Boss/Attacks` node at spawn. New mechanic = new component + add it to a `.tres`; reorder/remove = edit the `.tres`.

Movement stays **bespoke per-boss** (NOT the enemy nav-FSM) — confirmed by user. The boss keeps its own gravity + face-player + drive code.

## Scope (in)

- **Slice 1 (DATA MODEL):** Introduce `BossAttack` base (`tools/lib/enemy/boss_attack.gd`, extends `Node`, mirrors `EnemyBehaviour`) with seams: `bind(boss)`, `telegraph_duration()`, `start()`, `tick(delta) -> bool` (returns true when done), `recover_duration()`. Add `attacks: Array[PackedScene]` to `BossData`. `boss.gd` drives a generic loop: moving-idle → pick next attack (round-robin over `attacks`) → telegraph → run component until done → recover → repeat. Port existing Charge + Slam logic into `ChargeAttack` / `SlamAttack` components. **Deprecate/remove the hardcoded `Phase` enum branches** for the ported mechanics. Keep all `BossData` tunables; mechanics read them. Buildable + observable: existing bosses still charge + slam, now via components. Domain: **enemy** (boss).
- **Slice 2 (ALWAYS-MOVING + CADENCE):** Replace the dead-stop idle/recover with a **moving idle** — the boss strafes / circles / approaches the player at `move_speed` between attacks (bespoke, gravity + face). Telegraphs may slow but never fully freeze (a slow drift, not a stop). Apply **faster cadence**: shorten default `idle_duration` / `recover_duration`, and make phase-2 cadence the norm earlier. Make the **form/color-change a side-channel**: it swaps vulnerability + tint on its own timer WITHOUT being a "mechanic slot" or pausing movement — verify the boss is never standing still. Domain: **enemy** (boss).
- **Slice 3 (SLAM reads):** Give `SlamAttack` a real telegraph (wind-up scale/jump tell) + a visible shockwave ring on impact (reuse `boss_explode_shockwave.tscn` / `slam_vfx_scene`), wired in all three boss `.tres`. AoE damage stays. Buildable + observable: slam is clearly readable and avoidable. Domain: **enemy** (boss) + light **visuals**.
- **Slice 4 (SUMMON adds):** New `SummonAttack` component — telegraph, then spawn 2–3 enemies (reuse the existing `Enemy` scene + an archetype id) around the boss. Authored entirely in data (`.tres`: archetype id, count, spawn radius). Add to at least one boss's `attacks` list. Domain: **enemy** (boss + spawn glue).

## Scope (out)

- **Projectile volley** — user dropped it from this pass. The existing volley code may be ported to a `VolleyAttack` component for parity but is NOT wired into any boss's `attacks` this pass (parked).
- **Radial burst / beam sweep** — not selected. Later.
- **Real skeletal animations** — no `AnimationPlayer`; tells stay scale/tween. Parked.
- **Boss id-registry (ResourceRegistry)** — boss is still wired via the scene's `@export var data` slot, not id-keyed lookup. Not needed now; park until bosses are spawned from save/wave data by id.
- **Moving bosses onto the enemy nav-FSM** — explicitly rejected; bosses stay bespoke.

## Acceptance

- **Always moving:** across a 10 s headless run, the boss's XZ position changes every second outside of explicit dash frames; no contiguous ≥1.0 s window where `velocity.x == 0 and velocity.z == 0` while `_phase != DEAD` (assertable in a `play_*.gd` smoke).
- **Data-driven set:** a boss `.tres` with `attacks = [Charge, Slam, Summon]` produces exactly those three mechanics in order; removing one entry from the `.tres` removes that mechanic with no code change (smoke spawns the boss, logs each executed attack's class_name, asserts the sequence matches the `.tres`).
- **Slam reads:** on slam execute, a shockwave VFX node is added under the scene root within 2 frames of detonation AND a telegraph tween runs ≥0.15 s before the AoE applies (assert VFX child count delta + telegraph timestamp).
- **Summon:** on summon execute, enemy count in group `enemies` increases by the configured count within N frames; new enemies are live (have HealthComponent) (assert group-count delta).
- **Cadence faster:** measured mean seconds-between-attack-executions is below the pre-overhaul baseline (assert against a recorded baseline number).
- **Form-change is side-channel:** color/vulnerability swaps occur on their own timer WITHOUT a frame where the boss is in a dedicated standstill "form" phase (assert no movement freeze coincides with a `color_changed` emit). _human F5: the form change reads as a flourish, not the whole fight._
- All slices pass `tools/validate.sh` (L0+L1) and a `tools/play_boss_*.gd` smoke (L2).

## Skill notes

- `godot-enemy-archetype` / `godot-data-driven-composition` — the `BossAttack` component list IS the stateful-behaviour flavour; follow the `bind()`/seam contract that `EnemyBehaviour` already uses. Do NOT invent a new carrier — extend `BossData`.
- `godot-composition` — `BossAttack` components are child nodes under `Boss/Attacks`; signals up / calls down.
- `godot-fps-enemy-combat` — boss keeps the duck-typed `on_hit()` / `apply_damage()` shootability seam; summoned adds reuse the standard `Enemy` death contract.
- `godot-oneshot-vfx` — slam shockwave + telegraph are fire-and-free one-shots off the execute seam.
- `godot-code-rules` — strict typed GDScript; `boss.gd` must stay under 500 lines (already extracted to `BossMechanics`; move ported per-mechanic logic INTO the components, not back into `boss.gd`).
- `godot-runtime-smoke` — each slice gets a headless `tools/play_boss_*.gd` asserting the acceptance deltas above. Reuse existing `tools/smoke_boss.gd` / `tools/smoke_boss_prism.gd` patterns.

## Later (parked)

- `VolleyAttack` component wired into a boss (code can be ported now, left out of `attacks`).
- Radial/spiral burst attack; beam sweep attack.
- Real skeletal `AnimationPlayer` clips replacing scale-tween tells.
- Boss id-registry lookup (spawn boss by StringName from wave/save data).
- Per-attack cooldowns / weighted (non-round-robin) attack selection.

## Open questions

(none blocking — defaults above stand)

## Slice order (for the orchestrator)

1. **Slice 1 — Boss attack-component data model** (domain: enemy). `BossAttack` base + `BossData.attacks` + generic loop in `boss.gd`; port Charge + Slam into components. Foundation — must land first.
2. **Slice 2 — Always-moving loop + faster cadence + form-change as side-channel** (domain: enemy). Depends on Slice 1.
3. **Slice 3 — Slam telegraph + shockwave reads** (domain: enemy + visuals). Depends on Slice 1.
4. **Slice 4 — Summon-adds attack component** (domain: enemy + spawn glue). Depends on Slice 1.
