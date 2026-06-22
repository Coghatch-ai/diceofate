# Enemy Archetype — data-driven, trait-mixing enemies

**Goal** — A complex enemy is authored as a typed `.tres` archetype (stats + an ordered list of behaviour-component pieces) that one generic `enemy.tscn` reads at spawn, so traits combine (tank+magnet, tank+shooter) WITHOUT a new `extends Enemy` subclass.

## Decided model (do not re-litigate)

**Hybrid: data archetype (stats) + composed behaviour-component NODES.**

- `EnemyArchetype` (`tools/lib/enemy/enemy_archetype.gd`, `class_name EnemyArchetype extends Resource`) carries STATS only — the CastData analogue: `@export_range`'d `max_health`, `move_speed`, `patrol_speed`, `detect_range`, `attack_range`, `escape_range`, `attack_cooldown`, `score_value`, `touch_damage`, plus `tint_color: Color` and `display_name: String`. PLUS an ordered `behaviours: Array[PackedScene]` — the behaviour-component scenes to attach.
- Behaviours are **child component NODES** (`extends EnemyBehaviour extends Node`), NOT Effect-style Resources. WHY: enemy behaviour is per-frame + stateful (hover spring, dive tween, telegraph tween, magnet hit-counter, group membership) and must hook engine seams (`perform_attack`, `move_along_path`, `stop`, `_on_nav_velocity_computed`, `_physics_process`). Cast `Effect` is a stateless fire-once `apply(target, ctx)` — wrong shape. godot-composition + transcript point #3 both prescribe child component nodes for stateful per-entity behaviour. The Resource carries the DATA (stats list, like CastData's stats); the behaviours it lists are nodes (like the Gun owning live nodes that the CastData configures).
- Trait-mixing = an archetype lists `[MagnetBehaviour]` with tank stats → tank-magnet; lists `[ShooterBehaviour]` with tank stats → tank-shooter; lists `[FlyingMovement, ShooterAttack]` → flying-shooter. No subclass per combo.

## Behaviour seam contract (how a component plugs into the enemy)

`enemy.gd` already routes attack through `perform_attack()` and movement through `move_along_path`/`stop`/`_on_nav_velocity_computed` (virtual dispatch today). The generic seam:

- `enemy.gd` gains an `Abilities: Node` child. At spawn it instances each `archetype.behaviours[]` scene under `Abilities` and calls `behaviour.bind(self)` (duck-typed, guarded `has_method`).
- `EnemyBehaviour` base exposes optional hooks the enemy calls if present: `bind(enemy)`, and one of two roles —
  - **attack behaviour** — implements `do_attack()`. `enemy.perform_attack()` delegates to the first behaviour with `do_attack` (else the default melee-lunge). Replaces shooter/magnet/flying-dive attack overrides.
  - **movement behaviour** — implements `drive_move(speed, delta)` / `drive_stop(delta)` / `wants_nav_velocity() -> bool`. `enemy.move_along_path`/`stop` delegate when a movement behaviour is bound (else default gravity walk). Replaces flying hover override.
- Behaviours own their own tints/groups/timers in `bind()` (magnet `add_to_group("magnet")` + bubble; flying hover lift; shooter projectile_scene export on the behaviour node).

This keeps `enemy.gd` thin: it owns nav/perception/health/death; behaviours own how-it-fights and how-it-moves.

## Scope (in) — ordered slices

Each slice is one godot-dev (godot-combat) task, independently buildable + verifiable.

### Slice 1 — Archetype Resource + generic scene + 1 proof grunt
- `EnemyArchetype` Resource (stats, `@export_range`/`@export_group`, `behaviours: Array[PackedScene]`).
- `EnemyBehaviour` base node + `Abilities` child node in `enemy.tscn`; `enemy.gd` reads `@export var archetype: EnemyArchetype`, applies stats in `_ready()` (seeds `HealthComponent.max_health` from `archetype.max_health`, sets move/ranges/score, applies `tint_color`), instances `archetype.behaviours` under `Abilities`, calls `bind(self)`.
- One `archetypes/grunt.tres` (no behaviours — default melee-lunge). Generic `enemy.tscn` + grunt.tres reproduces today's base grunt.
- `wave_manager.gd`: add `@export var archetype: EnemyArchetype` slot; when set, spawn the generic scene and assign archetype before `add_child`. Leave the 6 PackedScene slots untouched (fallback).
- **Acceptance**: F6 `enemy.tscn` with grunt.tres assigned → walks, patrols, chases, takes 2 hits, dies, emits `died`, awards score. `tools/smoke_archetype_grunt.gd`: boot scene, assert `HealthComponent.max_health == archetype.max_health`, simulate 2 hits → `died` fires once, `score_value` matches archetype.

### Slice 2 — Behaviour-component pieces + trait-mixed proof enemies
- Extract three behaviour components from the existing subclasses (logic moved, not rewritten): `MagnetBehaviour` (contact-count pull-field + bubble + group), `ShooterAttack` (telegraph + fire projectile), `FlyingMovement` (hover/bob/no-gravity + dive). Each `extends EnemyBehaviour`, owns its exports.
- Author `archetypes/tank_magnet.tres` (tank stats + `[MagnetBehaviour]`) and `archetypes/tank_shooter.tres` (tank stats + `[ShooterAttack]`). **These are the trait-mixing proof: tank stats compose with magnet/shooter behaviour, impossible by subclass today.**
- ALSO migrate the two trivial variants: `archetypes/tank.tres`, `archetypes/runner.tres` (pure stat+tint, no behaviour) — cheapest migration, frees their subclasses. (magnet/shooter/flying subclasses stay until later slice.)
- `wave_manager.gd`: allow archetype-`.tres` per spawn slot alongside the PackedScene slots (keep ratio logic; one slot = one archetype on the generic scene).
- **Acceptance**: F5 → tank_magnet enemy is tanky (3 hits) AND pulls bullets (in `magnet` group, bubble visible); tank_shooter is tanky AND fires telegraphed projectiles. `tools/smoke_archetype_mix.gd`: spawn tank_magnet → assert health == tank max AND `is_in_group("magnet")`; spawn tank_shooter → assert `perform_attack()` spawns a projectile.

## Scope (out) — explicitly cut

- **Migrate magnet/shooter/flying subclasses** — slice 2 EXTRACTS their behaviour into components but the standalone subclasses keep working; deleting them + full archetype migration is a later slice. (Keeps slice 2 small; shipped variants untouched.)
- **Spawn-table `.tres`** — parked. wave_manager keeps ratio logic; slots become archetype-or-scene. Promoting to a `WaveTable` Resource is a later nicety, not needed to prove trait-mixing.
- **Behaviour-as-Effect-Resource** — rejected: wrong shape for stateful per-frame behaviour (see model section).
- **Behaviour trees** — banned by godot-enemy-ai; FSM stays. Behaviours plug into existing FSM seams, do not replace the FSM.
- **Behaviour ordering conflicts beyond attack-vs-movement** — only the two roles above; no multi-attack stacking or behaviour priority graph this build. Park.

## Acceptance (whole feature)
- godot-dev: each slice passes `tools/validate.sh` (L0+L1) + its `smoke_*.gd` (L2).
- User: F5 sees a tank that pulls bullets and a tank that shoots — neither existed as a subclass — proving traits compose from data.

## Skill notes
- `godot-fps-enemy-combat` — archetype MUST keep the duck-typed `apply_damage`/`on_hit`/`died(enemy)` contract and the child `HealthComponent`. Stats seed `HealthComponent.max_health` in `_ready()` (preserve the bottom-up `reset()` ordering in `enemy.gd`).
- `godot-enemy-ai` — FSM stays; behaviours plug into `perform_attack`/movement seams. No BTs.
- `godot-composition` — behaviours are component child nodes under `Abilities`; signals up / calls down; `bind(enemy)` is calls-down, behaviours emit no new signals to the enemy this build.
- `godot-data-driven-effect-composition` / `cast-system` — archetype is the enemy analogue of CastData (typed `.tres`, `@export` list). Mirror its authoring feel; do NOT reuse `Effect` for behaviour.
- `godot-code-rules` — strict typed; `@export_range` on every numeric stat, `@export_group("Stats")`/`@export_group("Behaviours")`. `@tool` not required (archetype has no editor-side preview).
- `godot-runtime-smoke` — both smoke scripts assert the seams above.

## Later (parked)
- Migrate magnet/shooter/flying subclasses to archetypes; delete subclasses.
- `WaveTable` spawn `.tres` (archetype + weight pairs); wave_manager reads it.
- Flying-Shooter / Flying-Magnet enemies (need FlyingMovement + a second behaviour role coexisting — proves movement+attack stacking; slice-2 proofs use single-behaviour mixes first).
- Behaviour priority / multi-attack stacking if a combo needs >1 attack role.
- New framework skill `godot-data-driven-enemy` (see handoff).

## Open questions
None — buildable.
