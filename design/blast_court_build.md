# Blast Court — Build

**Goal** — A 72×48 m open industrial arena (`levels/blast_court.tscn`) that loads under `Main/LevelHost`, where the player fights waves spawned from a perimeter ring, weaves between two cover blocks, dodges two damaging hazard trap strips, and grabs a risk/reward pickup cluster — all reusing existing systems (WaveManager, HealthComponent, hazard `apply_damage` seam, pickups).

Brief: `design/levels/blast_court.md`. Construction is the **first instance** of our existing data-driven systems (WaveManager archetype spawning, the duck-typed `apply_damage` hazard seam, the pickup entity) applied to a new arena — no new system, no bespoke code paths. New behaviour = new `.tscn` + thin level script mirroring `firing_yard.gd`/`ruined_warehouse.gd`.

## Construction method (decided)

**Hand-authored greybox `.tscn` of BoxMesh/StaticBody3D primitives** — NOT GridMap. Rationale: brief is a single flat floor (72×48) + 4 perimeter walls + 2 cover blocks + flat trap slabs — ~10 geometry pieces, below the GridMap threshold (`godot-gridmap-level`). Matches firing_yard's floor-slab + cover-block + hazard approach. No verticality, no ramps, no per-cell wall variety to justify a MeshLibrary.

- Root `Node3D` named `BlastCourt`, `script = res://levels/blast_court.gd` (`class_name BlastCourt extends Node3D`).
- `.tscn` hand-authoring rules (`godot-verify`): **NO rotated `Transform3D`** for axis-aligned boxes (use identity basis + position only); cover blocks need 8° Y-rotation → use `transform` with a real rotation basis ONLY on those 2 nodes (allowed; documented, grid-snapped position). **Sky must be a `Sky` resource** in the Environment (reuse firing_yard's `ProceduralSkyMaterial`+`Sky`+glow-enabled `Environment` verbatim).

## Grid → world mapping

- `cell_size = 3 m`. Grid origin `(gx=0, gy=0)` → world `(x=0, z=0)`. Grid +y(south) maps to world +Z.
- **Cell center** = `world(gx*3 + 1.5, y, gy*3 + 1.5)`. Use cell-center for all spawn/marker/prop placement (firing_yard used corner origin; cell-center is cleaner and self-consistent here — documented override of the brief's `(24,1,24)` literal).
- Grid is 24 wide (x 0–23) × 16 deep (y 0–15) → world 72 × 48. Floor spans x∈[0,72], z∈[0,48].
- **Player spawn** grid(8,8) → world `(25.5, 1, 25.5)`. Facing +Z (`rotation.y = PI`) toward arena depth. Export `SPAWN_POS = Vector3(25.5, 1.0, 25.5)`, `SPAWN_ROT_Y = PI` in the script (WaveManager `spawn_pos`/`spawn_rot_y` set to match).

## Node tree (target)

```
BlastCourt (Node3D, blast_court.gd)
├─ Floor (StaticBody3D)              # one BoxMesh 72×0.2×48 @ (36,-0.1,24), dark concrete 0.16,0.16,0.20
│  ├─ FloorMesh (MeshInstance3D)
│  └─ FloorCollision (CollisionShape3D)
├─ WallN/WallS/WallE/WallW (StaticBody3D ×4)   # perimeter, 4 m tall, slate 0.22,0.22,0.28
│  └─ (Mesh + Collision each; N/S = 72×4×1, E/W = 1×4×48; placed flush at edges)
├─ CoverBlockA (StaticBody3D)        # L-shape footprint → single merged BoxMesh ~9×4×6 @ grid(5–8,1–2) center, 8° Y-rot, 0.30,0.30,0.36
│  └─ (Mesh + Collision)
├─ CoverBlockB (StaticBody3D)        # 2×2 → BoxMesh ~6×4×6 @ grid(19–20,2–3) center, 8° Y-rot
│  └─ (Mesh + Collision)
├─ Sun (DirectionalLight3D)          # copy firing_yard: color 1,0.6,0.2 energy 0.6 shadows on
├─ WorldEnvironment                  # copy firing_yard Environment (Sky + glow levels 3–5 @ 0.6)
├─ NavFloor (NavigationRegion3D, group "nav_region")   # navigation_mesh = blast_court_navmesh.tres
├─ TrapNorth (MeshInstance3D + Area3D sibling)         # slice 2
├─ TrapSouth (MeshInstance3D + Area3D sibling)         # slice 2
├─ Pickup* ×4 (instances of pickup_health/ammo)        # slice 2
├─ SpawnMarker0..23 (Marker3D ×24)                     # slice 3
├─ EnemyWP0..2 (Marker3D ×3)                            # slice 3
├─ Player (instance entities/player/player.tscn)
└─ WaveManager (Node, wave_manager.gd)                 # slice 3
```

Cover block 8° Y-rot is shape variety only; box collision rotates with it (acceptable — full-height, blocks nav + projectiles).

## System wiring

- **Hazard traps (id=2)** — reuse the firing_yard `HazardFloor` pattern: an emissive orange slab `MeshInstance3D` (`Color(0.9,0.35,0.05)` emission energy 0.8) + a sibling `Area3D` (`collision_layer=0`, `collision_mask=2`) + `CollisionShape3D` over the strip cells. `blast_court.gd._ready()` connects each trap `body_entered` → `_on_trap_body_entered(body)` → guard `is_in_group("player")` + `has_method("apply_damage")` → `@warning_ignore("unsafe_method_access") body.apply_damage(trap_damage)`. **Damage-only — NO teleport/reset** (firing_yard's hazard resets; brief wants a punishing-but-not-fatal strip). Export `@export_range(1,100,1) var trap_damage: int = 10`. Add a re-entry cooldown (per-body `Dictionary` of last-hit time, ~0.5 s) so standing on the slab does not drain HP every physics tick.
  - TrapNorth: grid x=14–17, y=1 → slab ~12×0.1×3 centered world(48,0.1,4.5).
  - TrapSouth: grid x=9–13, y=13 → slab ~15×0.1×3 centered world(34.5,0.1,40.5).
- **Pickups (id=4)** — instance `entities/pickup/pickup_health.tscn` ×2 + `entities/pickup/pickup_ammo.tscn` ×2 at the four grid cells (19–20, 11–12) → world centers, y≈0.5, slight per-prop Y-rot (~7–13°). No script wiring — pickup entity self-contains its pickup logic.
- **Enemy spawning (id=3)** — `WaveManager` (Node) child of `BlastCourt`, script `wave_manager.gd`. Export the 6 enemy scenes (copy firing_yard's `enemy_scene`..`enemy_scene_f` ext_resources + ratios), `spawn_marker_paths` = the 24 `SpawnMarker*`, `patrol_waypoint_paths` = 3 `EnemyWP*`, `spawn_pos=(25.5,1,25.5)`, `spawn_rot_y=PI`. **main.gd auto-wires it**: `find_child("WaveManager")` connects score/active/run_lost/advance_level to HUD and injects `current_level.wave_manager` — so `blast_court.gd` MUST declare `@export var wave_manager: WaveManager` (even if unused by traps) to satisfy that duck-typed set. 24 markers ring the perimeter per brief zone-6 cells → world cell-centers, y=0.
- **Navigation** — `NavFloor` NavigationRegion3D (group `nav_region`) with a pre-baked `levels/blast_court_navmesh.tres`. Bake via `tools/bake_navmesh.gd` after slice 1 geometry exists (cover blocks must be present so nav carves around them). `bake_navmesh.gd` has hardcoded `SCENE_PATH`/`OUTPUT_PATH` for firing_yard → godot-dev temporarily points them at blast_court (or copies the tool) to bake, then assigns the `.tres`. WaveManager's close-ring spawn + enemy pathing depend on this.
- **Level registration** — append `"res://levels/blast_court.tscn"` to `main.gd._levels` so Tab (`cycle_level`) reaches it and the advance-level chain can rotate into it. (One-line edit; not a regression to existing levels.)

## Ordered slices

### Slice 1 — Greybox shell + player spawn (F6-runnable)
**godot-dev task:** Create `levels/blast_court.tscn` (root `BlastCourt`) + `levels/blast_court.gd` (`class_name BlastCourt extends Node3D`, `@export var wave_manager: WaveManager`, empty `_ready()` for now). Build: Floor (72×0.2×48 StaticBody3D), 4 perimeter walls (4 m), CoverBlockA (L→merged box, 8° Y-rot), CoverBlockB (6×6 box, 8° Y-rot), Sun + WorldEnvironment copied verbatim from firing_yard (glow-enabled), NavFloor NavigationRegion3D (group `nav_region`, empty NavigationMesh resource for now), Player instance at world(25.5,1,25.5) rot.y=PI. Append blast_court to `main.gd._levels`.
**Verify:** `tools/validate.sh` (L0 load+render, lint, types). `godot-verify` windowed: F6 `blast_court.tscn` → player drops onto floor, walls enclose, 2 cover blocks read, warm glow lighting; F5 from Main + Tab cycles into Blast Court without breaking firing_yard/ruined_warehouse. Then bake `blast_court_navmesh.tres` and assign to NavFloor.
**Independently buildable + F6-runnable:** yes — geometry + player only; no wave/trap deps.

### Slice 2 — Hazard traps + pickups
**godot-dev task:** Add TrapNorth + TrapSouth (emissive slab MeshInstance3D + sibling Area3D mask=2 + CollisionShape3D) at the two strips. Implement `blast_court.gd` trap handling: connect both `body_entered` in `_ready()`, `_on_trap_body_entered` → duck-typed `apply_damage(trap_damage)` with `is_in_group("player")`+`has_method` guards + per-body ~0.5 s cooldown. Add `@export var trap_damage: int = 10`. Instance 2× `pickup_health.tscn` + 2× `pickup_ammo.tscn` at the id=4 cluster cells with slight Y-rot.
**Verify:** `tools/validate.sh`. `godot-runtime-smoke` (`tools/smoke_blast_court_trap.gd`): boot scene, teleport player onto a trap Area3D, simulate `body_entered`, ASSERT player HP decremented by `trap_damage` and that re-entry within cooldown does NOT stack. `godot-verify` windowed: emissive slabs glow (glow buffer reads them), walking onto a strip drains HP and shows the damage vignette, pickups instance and are grabbable.
**Independently buildable:** yes — builds on slice-1 scene; no wave dep.

### Slice 3 — WaveManager enemy-spawn wiring
**godot-dev task:** Add 24 `SpawnMarker0..23` (perimeter ring cells → world cell-centers, y=0) + 3 `EnemyWP0..2` (grid (2,6),(6,10),(15,10)) Marker3D. Add `WaveManager` Node child with the 6 enemy ext_resources + ratios copied from firing_yard, `spawn_marker_paths`→the 24 markers, `patrol_waypoint_paths`→the 3 WPs, `spawn_pos=(25.5,1,25.5)`, `spawn_rot_y=PI`. Confirm main.gd's existing `find_child("WaveManager")` wiring picks it up (no main.gd change beyond slice-1's `_levels` append).
**Verify:** `tools/validate.sh`. `godot-runtime-smoke` (reuse/extend the WaveManager smoke pattern if present, else `tools/smoke_blast_court_waves.gd`): boot scene, ASSERT WaveManager resolves ≥1 spawn marker + nav map valid, seeds `start_count` enemies, an enemy `died` increments score. `godot-verify` windowed: F5 → enemies spawn from perimeter ring, path around cover blocks toward player, HUD score/active update on kills, run-lost fires at HP 0.
**Independently buildable:** yes — adds markers + WaveManager onto slices 1–2; navmesh from slice 1 already baked so pathing works.

## Acceptance (whole level)

- F6 `blast_court.tscn` and F5→Tab→Blast Court both run; firing_yard + ruined_warehouse still load (no regression).
- Player spawns center, can shoot (rifle + Q/E/R/T/Y), waves spawn from the ring, enemies path around the 2 cover blocks.
- Both trap strips deal `trap_damage` on entry (vignette shows), do not stack within cooldown, do not teleport.
- Pickup cluster grabbable; reaching it crosses the south trap (risk/reward).
- `validate.sh` green; both runtime-smokes pass.

## Skill notes

- `godot-main-scene` — level lives under `LevelHost`; never `change_scene_to_file()`; main.gd `_levels` append is the only entry-point edit.
- `godot-verify` — Transform3D ban (identity basis except the 2 cover blocks' documented 8° rot); Sky resource required (reuse firing_yard's).
- `godot-gridmap-level` — explicitly NOT used (below threshold; flat arena); documented so nobody re-derives.
- `godot-runtime-smoke` — slices 2 & 3 assert trap damage + spawn logic headless.
- `godot-fps-enemy-combat` / `cast-system` — combat/bullets unchanged; level only provides the arena + spawns.

## Later (parked)

- Per-zone floor colour (center vs perimeter band) — cosmetic.
- Animated trap emissive pulse (Tween) — juice.
- Cover-block surface textures (HD) — asset-advisor if needed.
- Pinch-point interior partition walls (brief §pinch points) — dropped for POC; flat open arena ships first, add micro-funnel walls in a later slice if combat feels too open.
- `bake_navmesh.gd` parameterization (scene path as arg) — refactor when a 3rd level needs baking.

## Open questions

None — all brief assumptions carried as-is; cell-center origin + damage-only traps + no-GridMap are documented decisions above.
