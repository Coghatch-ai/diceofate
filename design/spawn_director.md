# Spawn Director — all-sides perimeter + close-behind ring

**Goal** — F5: respawned enemies come from every side of the arena, and a meaningful share appear close behind the player, so standing still is no longer safe — the player must keep moving and turning.

**Why** — Current `WaveManager` spawns cluster: 8 markers all sit north of the player's south spawn `(24,1,30)`; the player rarely moves so the player→marker LOS pick almost always lands in that same north band, and the "all visible → nearest" fallback never triggers. No spawn is ever close. Result: zero pressure to move. This slice replaces the spawn-point selection inside `wave_manager.gd` only.

**Decisions applied (interview + repo):**
- **Method = hybrid.** Keep authored edge markers for FAR spawns; compute CLOSE spawns procedurally on a ring around the player each time. The ring follows the player, so "close" always means close.
- **Far markers = ≥12 authored `Marker3D`, covering all 4 sides + corners** of the arena perimeter (arena ≈ x∈[0,48], z∈[0,40]; floor box `size=(56,2,40)`, `cell_size 2`). Replaces today's north-biased 8. Far pick stays out-of-sight (existing player→marker LOS raycast on `WALL_MASK`); fallback = farthest marker (not nearest — nearest re-introduces clustering).
- **Close ring = min 6 m, max 12 m, biased behind the player** (outside the forward ~90° view cone). Sampled to the navmesh so a close point never lands inside a wall/prop; reject + retry a few times, else fall back to a far marker.
- **Mix = ~40% close / ~60% far per respawn.** Roll per spawn. Start-seed (`start_count`) stays FAR so the run opens calm.

## Scope (in)
- **Re-author far markers in `firing_yard.tscn`:** replace `SpawnMarker0..7` with **`SpawnMarker0..11`** (≥12), placed around the full perimeter — north edge, south edge (behind/around player spawn too), east edge, west edge, and the four corners — all on the baked `NavFloor`, clear of `BarrelA/B`/`CrateA`/platforms. Update `WaveManager.spawn_marker_paths` to list all of them.
- **`wave_manager.gd` — new `_pick_spawn_point(seed_phase: bool) -> Vector3`** replacing the marker-only `_pick_spawn_marker()`:
  - `seed_phase == true` → always FAR (out-of-sight authored marker; fallback = farthest from player).
  - else roll: ~40% → CLOSE ring point, ~60% → FAR marker.
  - **CLOSE point:** pick a random angle in the rear arc (player facing is `-Z` rotated by `rotation.y`; rear arc = angles outside the front 90° cone), random radius in `[6,12]`, candidate = `player_pos + offset`. Snap/validate to navmesh via `NavigationServer3D.map_get_closest_point` (or region's map RID); accept if the snapped point is within ~1.5 m of the candidate, else retry (cap ~6 tries) then fall back to a FAR marker.
  - Returns a world-space `Vector3`; `_spawn_one()` uses it directly (drop the `+0.5 y` already applied, keep the existing spawn-height offset).
- **Constants** for the tunables: `CLOSE_MIN := 6.0`, `CLOSE_MAX := 12.0`, `CLOSE_FRACTION := 0.4`, `FRONT_CONE_DEG := 90.0`, `NAV_SNAP_TOLERANCE := 1.5`, `CLOSE_RETRIES := 6`.
- Keep all existing behaviour: died→respawn+net-new, `active_cap` 30, touch→reset+teleport, signal wiring, print lines.

## Scope (out)
- Telegraph / visual marker before an enemy appears — POC stays `print`-only per convention. (Later.)
- Weighted anti-cluster across far markers, or "no two spawns from the same marker twice" memory. (Later.)
- Difficulty-scaled mix (more close spawns per wave). (Later.)
- Changing enemy behaviour, the cap, the reset, or `firing_yard.gd`. Untouched.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript); `godot-verify` passes on `main.tscn` and `firing_yard.tscn` (F6).
- Scene has **≥12** `SpawnMarker*` nodes spanning all four sides + corners; `spawn_marker_paths` lists all.
- F5: kill enemies repeatedly and watch where they appear — over ~10 kills they come from **all sides** (north, south, east, west), not one band.
- Some respawns appear **close behind / to the flank** of the player (within ~6–12 m, not in the crosshair) — confirm by standing still and getting flanked.
- No enemy ever spawns **on top of** the player (< 6 m) or **inside a wall/prop** (navmesh-snapped).
- Start-of-run seed (2 enemies) still appears far/out of sight, not close.
- No orphan nodes; count still holds at 30 under sustained killing; reset-on-touch still teleports player to spawn facing −Z.

## Skill notes
- `godot-code-rules` — strict typed GDScript on the new pick fn; type the navmesh-sample call (`NavigationServer3D.map_get_closest_point` returns `Vector3`, takes a map `RID`). Gate `tools/validate.sh`.
- `godot-enemy-ai` — close spawns MUST land on the baked `NavFloor` map or the `NavigationAgent3D` can't path; navmesh-snap is mandatory, not optional. Reuse `firing_yard_navmesh.tres`.
- `godot-composition` — selection logic stays inside `WaveManager`; enemies unchanged.
- `godot-verify` — spawn positions are runtime-computed; verify visually that respawns land on all sides, close ones land behind the player, none clip walls.
- `godot-gridmap-level` — far markers are computed-position `Marker3D`s baked in the level scene (not GridMap cells); keep them grid-sane on `NavFloor`.

## Later
- Pre-spawn telegraph (ground decal / sound) so close spawns feel fair.
- Anti-cluster memory across far markers; weighted-by-distance far pick.
- Per-wave mix ramp (close fraction rises with wave count).

## Open questions
None blocking. Marker count/placement and the pick rewrite are build steps.
