# Enemy Spawn System — single source of truth, hard-defined markers, robust reset

**Goal** — F5: a run starts with exactly 2 enemies at authored markers away from the player; killing escalates (+1/kill, cap 30); getting touched resets to 2 fresh enemies — and the reset works **every** time, not just once.

**Why** — The spawn path churns because the level has **two competing spawn sources**: pre-placed `EnemyA`/`EnemyB` baked in `firing_yard.tscn` + a `_connect_existing_enemies()` scanner, AND a `WaveManager` with `start_count = 0`. Two bugs fall out of that one design flaw:
- **Too close:** `spawn_director.md`'s procedural close-ring spawns enemies 6–12 m behind a player who never moves → constant unfair flanks.
- **Stops after first reset:** on touch, `_on_enemy_touched_player` frees all enemies then re-seeds `range(start_count)` = `range(0)` = **0**. Pre-placed enemies are gone, nothing refills → empty arena forever.

Fix is structural: **one spawn source** (authored markers + `start_count`), **no pre-placed enemies**, **no scanner**, and the spawn system isolated into one self-contained subtree.

**Decisions applied (interview — all recommendations accepted):**
- **Markers only.** Drop the procedural close-ring entirely. Enemies appear ONLY at authored `Marker3D` spawn points. Hard-defined, debuggable, fixes "too close".
- **No pre-placed enemies, no scanner.** Delete `EnemyA`/`EnemyB` nodes from `firing_yard.tscn`; delete `_connect_existing_enemies()` and its `call_deferred` from `wave_manager.gd`. Enemies exist only if `WaveManager` spawned them.
- **`start_count = 2`** (scene must set this on the `WaveManager` node — not rely on the export default).
- **Min spawn distance = 15 m** from player spawn `(24,1,30)`. Every authored marker must sit ≥15 m away.
- **Markers are children of `WaveManager`.** Move all `SpawnMarker*` under the `WaveManager` node so the spawn system is one self-contained subtree (move/inspect/disable as a unit). `spawn_marker_paths` become relative (`SpawnMarker0`…). Strongest isolation, no autoload.
- **Reset = fixed re-seed.** Clear all, spawn `start_count` fresh at out-of-sight markers, teleport player to `SPAWN_POS` facing −Z. Deterministic return to start state.
- **Keep escalation** (each kill → respawn + 1 net-new, `active_cap = 30`, then 1-for-1). Gameplay loop unchanged; this slice touches placement/reset/isolation only.

## Build steps (godot-dev)
1. **`firing_yard.tscn` — remove pre-placed enemies.** Delete nodes `EnemyA` (lines ~732) and `EnemyB` (~738). They are the implicit second spawn source.
2. **Reparent markers under `WaveManager`.** Move `SpawnMarker0..11` to be children of the `WaveManager` node. Re-author any whose distance to `(24,1,30)` is < 15 m so all are ≥15 m (current `SpawnMarker10`/`11` at x=3,z≈10–20 and `SpawnMarker0`/`9` are the perimeter ones — keep the ring, just verify the ≥15 m rule and that each lands on the baked `NavFloor`, clear of `BarrelA/B`/`CrateA`/platforms/hazards). Keep ≥12 markers spanning all four sides + corners (carries the all-sides goal from `spawn_director.md`). Update `spawn_marker_paths` to the new relative paths.
3. **`wave_manager.gd` — collapse to one spawn path.**
   - Set the `WaveManager` node's `start_count = 2` in the scene.
   - Delete `_connect_existing_enemies()` and its `call_deferred` in `_ready()`.
   - Delete the close-ring: `_pick_close_point()`, the CLOSE_*/FRONT_CONE_DEG/NAV_SNAP_TOLERANCE/CLOSE_RETRIES constants, and the close branch of `_pick_spawn_point()`. `_pick_spawn_point()` becomes: pick an out-of-sight authored marker (player→marker LOS raycast on `WALL_MASK`), fallback = farthest marker. (Keep `_pick_far_marker_pos()` as the only picker.)
   - Reset (`_on_enemy_touched_player`) and seed (`_seed_start`) both call the marker picker; both now re-seed `start_count` = 2 — verify reset refills correctly.

## Scope (in)
- One spawn source: `WaveManager` + its `SpawnMarker*` children; no pre-placed enemies, no scanner.
- Marker-only `_pick_spawn_point()`: out-of-sight pick + farthest-marker fallback.
- `start_count = 2` start AND reset; escalation (+1/kill, cap 30) unchanged.
- Reset-on-touch clears, re-seeds 2 at markers, teleports player to `SPAWN_POS` facing −Z, `print`s a reset line — repeatable.
- All markers ≥15 m from `(24,1,30)`, on the baked `NavFloor`, all four sides + corners.

## Scope (out)
- Procedural close-ring / behind-player ring — removed (caused "too close").
- Score / wave / enemy-count HUD — none this POC. (Later.)
- Player health / multi-hit — touch = instant reset. (Later.)
- Visual/audio reset or spawn feedback — `print` only. (Later.)
- Changing enemy AI behaviour, the cap, or `firing_yard.gd` lighting script. Untouched.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript); `godot-verify` passes on `main.tscn` + `firing_yard.tscn` (F6).
- Scene has **zero** `Enemy` nodes baked in (search the `.tscn`); `WaveManager` is the only enemy source.
- All `SpawnMarker*` are children of `WaveManager`, each ≥15 m from `(24,1,30)`, on `NavFloor`, spanning all sides + corners.
- F5: run opens with exactly **2** enemies, none within 15 m, none spawned in your crosshair.
- Kill repeatedly → count climbs (2→3→4…), holds at 30; respawns appear off-camera.
- **Get touched → reset to 2 fresh enemies at player spawn facing −Z; console prints reset. Repeat the touch 3+ times — enemies refill EVERY time (the regression is gone).**
- No orphan nodes after kills/resets; node count sane.

## Skill notes
- `godot-composition` — `WaveManager` stays a sibling component node owning the enemy set; markers as its children = one self-contained subtree. Enemies signal `died`/`touched_player` UP; manager spawns/frees DOWN. Do NOT fold into `firing_yard.gd` or an autoload.
- `godot-enemy-ai` — enemies unchanged; spawns MUST land on baked `NavFloor` (`firing_yard_navmesh.tres`) or `NavigationAgent3D` can't path. Markers stay on the navmesh; player stays in group `player`.
- `godot-gridmap-level` — `SpawnMarker*` are computed-position `Marker3D`s baked in the level scene (not GridMap cells); keep grid-sane on `NavFloor`.
- `godot-code-rules` — strict typed GDScript on the `wave_manager.gd` edits; gate `tools/validate.sh`. Deleting the close-ring removes the `unsafe`-prone navmesh-sample code.
- `godot-verify` — spawns/frees/resets are runtime state; verify enemies appear at markers, reset refills repeatedly, no clip into walls.

## Later
- Pre-spawn telegraph (ground decal / sound) if close spawns ever return.
- Score / wave / active-enemy HUD; win/lose screen.
- Player health + damage so touch hurts instead of instant-reset.
- Reset/spawn visual + audio feedback; per-wave difficulty scaling.
- Anti-cluster marker memory; weighted far pick.

## Open questions
None blocking. All three fixes (remove pre-placed enemies, collapse to one marker-only spawn path, reset re-seeds `start_count`) are build steps.
