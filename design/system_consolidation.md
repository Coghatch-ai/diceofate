# System Consolidation — Architectural Drift Cleanup

**Goal** — One coherent shape for each cross-cutting system (run-control, damageable contract, weapon feel, behaviour/nav/death tuning, VFX events), retire the dead parallel paths, and close the data-driven gaps — so a class of bug (data field exists but nothing reads it; two parallel controllers; magic numbers in logic) can't recur.

## Ground truth (verified, corrects the brief)

- **Only ONE live level: `levels/iron_floor.tscn`, and it uses `RoomController` — NOT WaveManager.** WaveManager has **zero** live levels (firing_yard / blast_court / ruined_warehouse all deleted). → WaveManager + ArenaBuilder are dead-on-arrival; only refs are `wave_manager.gd` itself, `arena_builder.gd`, `tools/smoke_audit_layout.gd`, `npc.gd` (export DI, unused per its own comment), and `main.gd`'s defensive `find_child("WaveManager")` branch.
- **Score path already reads `score_value` everywhere** — RoomController:198, wave_manager:347/423, iron_floor.gd:43 (`complete_run(boss.score_value)`). The reported bug is FIXED. C5 = an **audit to confirm**, not a fix.
- **Live spawn path is data-driven already:** RoomController + generic `enemy.tscn` + `EnemyArchetype` whose `behaviours[]` instance `magnet_behaviour.tscn` / `flying_movement.tscn` (archetype/behaviour child nodes). The per-subclass scripts (`enemy_runner/tank/magnet/shooter/flying.gd` + `enemy_magnetic.tscn` / `enemy_flying.tscn`) are the OLD path; only refs are `tools/test_combat_integration.gd` + design docs.
- **Single weapon today** (`rifle.tscn` via `gun.gd`); 5 element bullet_casts already data-driven (CastData). Feel-stats (fire_rate/spread/recoil) are scene `@export`s, not a Resource.
- **VFX signal fan-out works** (vfx_router consumes 6 gun signals incl. element/blast index). It's drift, but it never caused a bug.

## Decisions (recommendations applied — override in the doc if wrong)

1. **Run-control → retire WaveManager + ArenaBuilder outright; RoomController IS the controller.** No shared base needed for two when one is dead — a base over a single class is ceremony. Extract the 4-signal run-control contract (`score_changed/active_changed/run_lost/advance_level`) as a documented **`RunController` interface convention** (same signal names + arity), not an inheritance base, so `main.gd` wires ONE branch. Removes the duplication that caused the win-flow bug at the source (one controller, not two).
2. **Damageable contract → shared base class `Damageable extends CharacterBody3D` for enemy + boss; keep Npc separate.** Enemy & Boss both are CharacterBody3D and both declare `died(self)` + `touched_player(self)` → real shared base earns its keep. Npc is `StaticBody3D` with a different death model (`died(npc)` + `rescued`) → leave it; forcing it under the base is a worse fit than the duplication. Base declares the two signals + the `score_value` field + the duck-typed `on_hit`/`apply_damage` seam contract; subclasses keep their own behaviour. (Composition note: this is a thin signal/field base, NOT a behaviour hierarchy — behaviour stays in components/archetype.)
3. **WeaponData → introduce it now.** Cheap, and it's the data-driven FOUNDATION the brief mandates: `WeaponData extends Resource` mirroring CastData, holding fire_rate / spread_hip / spread_ads / crouch_spread_mult / recoil_pitch / recoil_yaw. `gun.gd` reads from an `@export var weapon_data: WeaponData` (the rifle is the FIRST entry, a `.tres`). Code reads the resource; no tuning literal stays in firing logic. Even with one weapon, this is the data layer a second weapon is just a new `.tres` over.
4. **VFX signal collapse (gun vfx_* → one event) → DEFER to Later.** It's working, drift-only, and collapsing it touches the live element/blast routing (regression risk) for no current bug. Park it; revisit when a 2nd weapon or new VFX seam actually forces it.
5. **Slice order + disjoint scopes** — see slice table; scopes chosen so no two slices edit the same file.

## Scope (in) — six disjoint builder slices

- **S1 (refactor): Retire dead legacy.** Delete `levels/wave_manager.gd`(+.uid), `entities/arena/arena_builder.gd`(+.uid), `tools/smoke_audit_layout.gd`; remove `main.gd`'s WaveManager `find_child` branch + the `current_level.wave_manager` inject; drop `npc.gd`'s unused `wave_manager` export; delete dead enemy subclasses `enemy_runner/tank/magnet/shooter/flying.gd`(+.tscn) + `enemy_magnetic.tscn` + `enemy_flying.tscn`; update/retire `tools/test_combat_integration.gd` (swap MAGNET_SCENE to the archetype path or delete the test). Files: those listed only.
- **S2 (refactor): RunController contract.** Document the 4-signal contract in `design/known-problems.md` + a header comment on `room_controller.gd`; confirm `main.gd` has a single run-control wiring branch (RoomController) after S1. No new base class. Files: `room_controller.gd` (comment only), `main.gd`, `design/`.
- **S3 (enemy): Damageable base.** New `entities/damageable.gd` (`class_name Damageable extends CharacterBody3D`) declaring `signal died(d: Damageable)`, `signal touched_player(d: Damageable)`, `@export var score_value: int`, and the `on_hit`/`apply_damage` seam doc. `enemy.gd` + `boss.gd` `extends Damageable`, drop their now-inherited signal/field decls; keep their typed connect sites working (signal arg type widens to Damageable — fix call-site casts). Files: new `damageable.gd`, `enemy.gd`, `boss.gd`. (NOT npc.gd, NOT room_controller.gd.)
- **S4 (ranged-combat): WeaponData resource.** New `tools/lib/weapon/weapon_data.gd` (`class_name WeaponData extends Resource`) with the 6 feel fields; new `entities/weapon/rifle_data.tres` (first entry, values copied from current gun exports); `gun.gd` reads `weapon_data` for fire_rate/spread/recoil, removing the baked `@export` defaults from firing logic (keep an `@export var weapon_data` slot). Files: new `weapon_data.gd`, new `rifle_data.tres`, `gun.gd`, `rifle.tscn` (wire the slot). (NOT vfx_router, NOT cast files.)
- **S5 (enemy): Lift behaviour magic numbers.** Add `@export`s to `magnet_behaviour.gd` for glow ramp (min/max emission, default 0.3/1.8), bubble alpha (0.5), bubble emission energy (2.0), lunge scale (Vector3(1.3,0.7,1.3)) + lunge timing (0.1/0.1); code reads them. Files: `magnet_behaviour.gd` only. (Assess `flying_movement.gd` for the same in the same slice if it holds literals; its tuning already looks @export'd on `enemy_flying.gd` — verify and lift any stragglers onto the behaviour.)
- **S6 (refactor): Lift nav agent params.** Move `nav_utils.gd` `_AGENT_HEIGHT/RADIUS/MAX_CLIMB` consts to a `NavAgentParams` resource OR (lighter, recommended) parameters on `ensure_baked(region, height, radius, climb)` defaulted from the region's own `navigation_mesh` when present — so the level's navmesh resource is the single source, not a hardcoded const. Files: `nav_utils.gd` + its one caller (`iron_floor.gd`). Pick the region-reads-its-own-mesh path if the navmesh already carries the values (it does — comment says "match iron_floor_navmesh.tres").

## Scope (out)

- VFX signal collapse (gun vfx_* → one event) — working, regression-risky, no live bug → Later.
- Run-control shared inheritance base — only one live controller; a base over one class is ceremony.
- Npc under Damageable — wrong fit (StaticBody3D, different death/rescue model).
- C4 "death effects + VFX timings to data" beyond S5 — death VFX already route through CastData/archetype (`hit_spark_scene`, `muzzle_vfx_scene`) + vfx_router consts that are art-director knobs, not logic literals; no logic magic-number to lift. Confirm in S2 audit, otherwise out.
- A second weapon / new archetype — not requested; the systems above make each a pure-data add.

## Acceptance

- S1: `rtk grep -r WaveManager\|ArenaBuilder` (excl. graphify-out/design) returns nothing; `tools/validate.sh` green; iron_floor F5 plays (RoomController unaffected).
- S2: `main.gd` has exactly one run-control wiring branch; doc updated.
- S3: enemy + boss still emit `died`/`touched_player`; RoomController + iron_floor boss wiring still connect (no "Signal already connected" / arity error); validate.sh green; F5 kill registers score, boss death advances.
- S4: rifle fires with identical feel (fire_rate 0.2, spread 2.5/0.3, recoil 0.08/0.03) sourced from `rifle_data.tres`; changing a `.tres` value changes feel; no feel literal left in `gun.gd` firing path; validate.sh green.
- S5: magnet bubble glow/alpha/lunge all editable from the behaviour Inspector; no literal in `_update_contact`/`do_attack`/`_setup_bubble`; F5 magnet bubble pulses as before.
- S6: changing the navmesh agent params on the level resource changes bake; no hardcoded agent const in `nav_utils.gd`; enemies still path on iron_floor.
- All: godot-verify after each slice; final `code-reviewer` pass on the combined diff.

## Skill notes

- `godot-code-rules` — strict typed GDScript; honor the no-magic-tuning rule (S4/S5/S6 exist to satisfy it). New resources fully typed; `@export` everything tunable.
- `godot-composition` — Damageable (S3) is a thin signal/field base, signals up; behaviour stays in components/archetype. WeaponData/NavAgent params are data carriers, not logic.
- `cast-system` / `godot-resource-registry` — WeaponData (S4) mirrors CastData's authored-`.tres` shape; if a registry over weapons is later wanted it's a thin subclass (parked).
- `godot-enemy-archetype` — S5 lifts onto the existing archetype/behaviour data layer; do NOT add a parallel tuning system.
- `godot-fps-enemy-combat` — S3 must preserve the `on_hit`/`died`/`kill_confirmed` contract exactly.
- `godot-main-scene` — S1/S2 touch level-load wiring; keep the LevelHost swap rules.

## Later

- Collapse gun `vfx_*` fan-out into one routed/data-driven VFX event.
- RunController as a real base/interface if a 2nd run-control mode appears.
- WeaponRegistry (resource-registry) over `weapon_data` `.tres` when a 2nd weapon lands.
- Fold Npc into a broader Damageable/IDamageable seam if a 3rd damageable shape appears.
- NavAgentParams resource if more than iron_floor needs per-level agent tuning.

## Open questions

None block implementation. Decisions 1–5 are applied; override any in this doc before dispatch if wrong.
