# Arena Survival Loop — escalating waves, out-of-sight respawn, reset-on-touch

**Goal** — F5: kill an enemy and it respawns out of your sight PLUS one net-new enemy joins (2→3→4…); let any enemy touch you and the run resets to 2 fresh enemies with you back at spawn.

**Roadmap** — new Track C (Arena survival) of `docs/roadmap/fps_poc.md`. Lifts three items previously out-of-scope: enemy waves/respawn, and a touch-the-player reset (upgrades the B3 harmless attack telegraph into a real touch-trigger). Builds directly on B3 (`design/firing_yard_enemy.md`, `entities/enemy/`) and the death hook from B2 (`design/fps_targets.md`).

**Decisions applied (from interview + repo):**
- **Respawn placement = predefined spawn markers + line-of-sight pick** (option A). Author ~6–8 `SpawnMarker*` `Marker3D` nodes behind cover / around the perimeter, all on the baked navmesh. On respawn pick a random marker the player **cannot** see; fall back to the farthest-from-player marker if every marker is currently visible. Reuses the enemy's existing occlusion idea (raycast on the world/wall layer), checked player→marker.
- **Wave rule:** each enemy death → respawn the dead one AND add one net-new enemy, so active count climbs by 1 per kill (start 2 → 3 → 4 …).
- **Active cap = 30.** Once 30 active, a death respawns 1-for-1 (count holds at 30); the run still ends only on touch. Greybox capsules with `NavigationAgent3D` + per-frame `EyeRay` stay cheap to ~30.
- **Reset-on-touch:** any enemy reaching the player resets the run — clear all enemies, re-seed exactly 2 fresh at out-of-sight markers, and **teleport the player to `SPAWN_POS` facing −Z** (reuses the existing fall-zone reset path in `firing_yard.gd`). Feedback = a `print` this slice; visual flash parked to Later.
- **Touch trigger:** when an `AttackState` enemy is within `attack_range` of the player, it counts as a touch → reset. The harmless scale-lunge telegraph stays as the visible tell; reaching attack range now also fires the reset (no separate hitbox needed — reuse `distance_to_target() <= attack_range`).
- **Logic home = a `WaveManager` child node** under the level (`levels/wave_manager.gd`, `class_name WaveManager`, extends `Node`), composed into `firing_yard.tscn`. Owns the live enemy set, spawn markers, count, and the reset. Signals up to nothing (it IS the arena authority); the level passes it the player + `enemy.tscn` + markers. Keeps the 200-line lighting-cycle `firing_yard.gd` untouched. Per `godot-composition`: enemies signal "I died"/"I touched player" UP to the manager; the manager calls DOWN to spawn/free.

## Build prerequisites (godot-dev)
1. **Enemies become runtime-spawned.** Today `EnemyA`/`EnemyB` are static nodes baked in `firing_yard.tscn`. Remove them; the `WaveManager` instances `enemy.tscn` at start and on each death. Keep the existing `EnemyWP0..2` patrol markers — spawned enemies get their `patrol_waypoint_paths` set to those at spawn time (or to nearest markers; godot-dev's call, keep them on open floor).
2. **Death + touch must signal the manager, not just `queue_free()`.** Add two signals to `enemy.gd`: `died(enemy)` and `touched_player(enemy)`. `on_hit()` emits `died(self)` then frees; the `AttackState`/attack path emits `touched_player(self)` when within `attack_range`. The `WaveManager` connects these on every enemy it spawns. (Composition: enemy reports events up; manager owns the response.)
3. **Spawn markers on the navmesh.** Add 6–8 `Marker3D` nodes (`SpawnMarker0..N`) placed behind walls/props and around the arena edge, all over the baked `NavFloor` region, clear of `BarrelA/B`/`CrateA`/platforms. The manager picks among these for out-of-sight respawn.

## Scope (in)
- `levels/wave_manager.gd` (`class_name WaveManager`, extends `Node`) + a `WaveManager` node in `firing_yard.tscn`. Exports: `enemy_scene: PackedScene`, `spawn_marker_paths: Array[NodePath]`, `patrol_waypoint_paths: Array[NodePath]`, `start_count := 2`, `active_cap := 30`. Resolves NodePaths in `_ready()` (same pattern as `enemy.gd`).
- **Start:** spawn `start_count` (2) enemies at out-of-sight markers; wire each enemy's `died`/`touched_player` signals.
- **On `died(enemy)`:** if active count (after the death) < `active_cap`, spawn **two** replacements (the respawn + the net-new); else spawn **one** (hold at cap). New enemies spawn at out-of-sight markers.
- **Out-of-sight pick:** random marker where player→marker raycast (world/wall layer) is blocked; fallback = marker with max distance to player.
- **On `touched_player(enemy)`:** free all live enemies, re-seed `start_count` at out-of-sight markers, teleport player to `SPAWN_POS` facing −Z (reuse the level's reset), `print` a reset line.
- Player already in group `player` — manager finds it via `get_first_node_in_group("player")`.

## Scope (out)
- Score / wave-number / enemy-count HUD — no UI in POC. (Later.)
- Player health bar / multi-hit — touch = instant reset, one shot still despawns an enemy. (Later.)
- Win/lose screen — none. (Later.)
- Visual/audio reset feedback (screen flash, sound) — `print` only this slice. (Later.)
- Smarter spawn (weighted by distance, anti-clustering, behind-player bias beyond LOS) — Later.
- Difficulty scaling (faster/tougher enemies per wave) — Later.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript); `godot-verify` passes on `main.tscn` and `firing_yard.tscn` (F6).
- F5: run starts with exactly 2 enemies.
- Shoot one enemy → it despawns, and the active count goes to **3** (one respawn + one net-new); the new enemies appear away from where you're looking (you do not see them pop in front of you).
- Repeat: each kill nets +1 (3→4→5…); confirm growth over several kills.
- Let an enemy reach you (walk into one): the run resets — all enemies vanish, 2 fresh ones seed, and you are back at the spawn point facing −Z; console prints the reset.
- Sustained killing past 30 active holds the count at 30 (deaths respawn 1-for-1), no runaway node count, no frame collapse.
- No orphan nodes after kills/resets; node count sane.

## Skill notes
- `godot-enemy-ai` — enemies unchanged in behaviour; only gain `died`/`touched_player` signals and runtime spawning. They still need the baked `NavFloor` and the `player` group (already present).
- `godot-composition` — `WaveManager` is a sibling component node owning the enemy set; enemies signal UP (died/touched), manager calls DOWN (spawn/free/reset). Do NOT fold this into the lighting script `firing_yard.gd`.
- `godot-main-scene` — nothing new registered in `main.gd`; the manager lives inside the already-registered `firing_yard.tscn`.
- `godot-gridmap-level` / `firing_yard.tscn` — spawn + waypoint `Marker3D`s are computed-position nodes baked into the level scene, not part of the GridMap; navmesh already baked in `firing_yard_navmesh.tres`.
- `godot-code-rules` — strict typed GDScript on `wave_manager.gd` and the `enemy.gd` signal additions; gate `tools/validate.sh`.
- `godot-verify` — spawns/frees/resets change runtime state; verify enemies appear, respawns land off-camera, reset teleports the player, scene keeps running.

## Later
- Score / wave counter / active-enemy HUD.
- Player health + damage so touch hurts instead of instant-reset; a real lose screen.
- Reset/spawn visual + audio feedback (red flash, hit sound).
- Per-wave difficulty scaling (speed/aggro/health).
- Smarter spawn distribution (behind-player bias, anti-cluster).

## Open questions
None blocking. The three prerequisites (runtime-spawn enemies, add died/touched signals, author spawn markers) are build steps, not open decisions.
