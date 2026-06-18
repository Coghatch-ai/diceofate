# Ruined Warehouse — Build Design

**Goal** — Playable wave-combat arena `levels/ruined_warehouse.tscn` loads under `Main/LevelHost`: player spawns in entry corridor, fights enemy waves on a ruined-warehouse kill floor, grabs pickups, wins on score / loses on lives.

**Source design** — `design/levels/ruined_warehouse.md` (frozen). Grid: `levels/drawn/current.json` (24×16). Save final grid copy to `levels/drawn/ruined_warehouse.json`.

## Construction method — GridMap (godot-gridmap-level)

GridMap, not per-piece BoxMesh. Brief cites `current.json` + ~130 wall cells → skill says always GridMap. `firing_yard.tscn` already builds walls this way (MeshLibrary item "wall" in a GridMap); only its floor slabs + props are baked StaticBody3D. Reuse that exact hybrid:

- **Walls** → GridMap, MeshLibrary tile per wall colour variant (zone tints). Mesh + collider welded → cannot drift.
- **Floor** → one baked `StaticBody3D` + `MeshInstance3D` + `CollisionShape3D` slab covering grid extent (48×32 m), dark tile colour. Raised platform = second small slab +1 m.
- **Props / pickups / markers** → instanced scenes / Marker3D at computed world pos, never eyeballed.
- **Build path** → ONE headless builder `scripts/build_ruined_warehouse.gd` (`@tool extends SceneTree`, tracked in `scripts/` not `tools/`). Re-run rebuilds the whole `.tscn`. Every gameplay node (player, WaveManager + SpawnMarkers, patrol waypoints, pickups, lights, env) is emitted by the builder — the baked `.tscn` is generated output, never hand-edited. MeshLibrary loads from a tracked `.tres`.

**Scale contract** — `cell_size = Vector3(2, 3.5, 2)`. Cell `(col,row)` → world `Vector3(col*2, y, row*2)`, `cell_center_*` = false (matches firing_yard). Wall height 3.5 m.

## Scope (in) — ordered slices

Each slice = one godot-dev task, independently verifiable (godot-verify + one human look). Builder grows slice by slice; each re-bake must keep all prior nodes (skill verify step 6: actor inventory).

- **Slice A — Floor + perimeter walls + lighting + LevelHost wiring.** MeshLibrary `.tres` with `wall` tile (`Color(0.251,0.251,0.314)`, box 2×3.5×2). Builder emits: GridMap of all code-1 cells from JSON; one floor slab 48×32 m at y=-0.1 (`Color(0.078,0.078,0.125)`); `DirectionalLight3D` Sun (energy 1.2, 45° pitch, shadows on) + `WorldEnvironment` (Sky, Filmic tonemap) per godot-pixel-lighting; root `RuinedWarehouse` (Node3D + `levels/ruined_warehouse.gd`). Add `"res://levels/ruined_warehouse.tscn"` to `main.gd` `_levels`. Verify: F5/cycle_level loads it, walls render with matching colliders, floor visible, lit.
- **Slice B — Entry-corridor wall tint + player spawn.** Add `wall_corridor` tile variant (`Color(0.18,0.18,0.22)`) to MeshLibrary; builder paints code-1 cells in corridor region (x0–8, y0–4) with it. Instance `Player` at spawn cell (6,1) → world `(12,1,2)`, facing south (`rotation_y = 0`, −Z is north here; south = +Z so face +Z → `rotation_y = PI`). Define spawn as constants in `ruined_warehouse.gd` (`SPAWN_POS=Vector3(12,1,2)`, `SPAWN_ROT_Y=PI`). Verify: player drops in corridor, faces kill floor.
- **Slice C — Kill-floor cover barriers + scattered pickups.** id=2 cells (x14–17 y1; x9–13 y13) → low concrete barrier props: `StaticBody3D` + `MeshInstance3D` BoxMesh 2×0.8×2 (`Color(0.35,0.30,0.25)`) + box collider, one instance per contiguous run at run centre, full collision. id=6 cells (x2 y6, x8 y8, x6 y10, x15 y10, x2 y13) → `entities/pickup/pickup_ammo.tscn` instanced flat on floor, ±15° random yaw. Verify: barriers block movement, 5 ammo pickups grabbable.
- **Slice D — Flanking pockets + raised platform.** Pocket wall tint `wall_pocket` (`Color(0.20,0.20,0.28)`) on code-1 cells around the right alcoves (x18–23, y2–3 and y11–12). Raised platform: second floor slab +1 m over x19–20 y11–12 (world x38–40, z22–24), same dark colour, with a single-step lip/ramp on its kill-floor (west) edge. Verify: pocket walls read distinct, platform stands +1 m and is walkable up the ramp.
- **Slice E — Breach gates + enemy spawn markers.** id=3 cells (south y15 strips x4–7, x15–18; left edge x0 y4–15; right edge x23 y11–14) → breach-gate marker: rubble-sill prop (thin BoxMesh, 5–10° yaw, **no blocking collision**) so wave enemies path through. Builder emits `WaveManager` node (children `SpawnMarker*` Marker3D at each south/side gate cell world pos) + 3 patrol waypoints (`EnemyWP0..2`) on the kill floor. Wire `spawn_marker_paths` / `patrol_waypoint_paths` exactly like firing_yard. No NavigationRegion yet (parked). Verify: gates open (player walks through), markers present (`get_node` count > 0), waves spawn at gates.
- **Slice F — Pickup clusters + spawn/respawn integration.** id=5 cluster (x19–20 y2–3) → `pickup_health.tscn` ×4. id=4 cluster (x19–20 y11–12, on the +1 m platform) → `pickup_ammo.tscn` ×4. Set WaveManager exports: enemy scenes + ratios + `start_count` mirroring firing_yard; assign its own spawn/respawn position to this level's spawn (see Skill notes — wave_manager.gd `SPAWN_POS` is currently a const tied to firing_yard). Verify: full run — spawn, fight, grab caches, win on score / lose on lives, respawn lands at corridor spawn.

## Scope (out)
- NavigationRegion3D / navmesh bake — parked; enemies use existing patrol-waypoint AI without baked nav for now (matches min viable; nav added later if pathing fails).
- Per-zone point lights — brief parks them; single Sun only.
- Ceiling mesh / indoor skybox occlusion — parked.
- Destructible rubble, day/night cycle (firing_yard's gimmick), hazards (crusher/fall/hazard floor) — not in this arena.

## Acceptance
- `levels/ruined_warehouse.tscn` loads under `Main/LevelHost` via `main.gd` `_levels` (F5 or cycle_level), no errors, renders lit.
- Walls grid-snapped with matching colliders (no clip/drift); three zone tints visible.
- Player spawns at corridor cell (6,1) facing the kill floor; cover barriers block; raised platform walkable.
- Breach gates passable; waves spawn at gate markers; pickups (5 scattered ammo, 4 health cache, 4 ammo cache) collectible.
- Full run reaches win (score) and loss (lives) end screens; life-loss respawn lands at this level's spawn, NOT firing_yard's (24,1,30).
- Each slice passes `tools/validate.sh` + godot-verify, incl. actor-inventory check after every re-bake.

## Skill notes
- **godot-gridmap-level** — GridMap walls; floor/props baked outside; per-zone colour = separate MeshLibrary tile items (colour on mesh material, not node override); collision welded to tile / unique box on props (default, not parked); multi-cell same-id prop = ONE instance at group centre; ONE tracked builder in `scripts/`; baked `.tscn` never hand-edited; re-bake keeps full actor inventory.
- **godot-main-scene** — load under `Main/LevelHost`; add to `main.gd` `_levels`; never `change_scene_to_file()`. main.gd auto-wires Player camera + WaveManager→HUD via `find_child`, so node names must be `Player` / `WaveManager`.
- **godot-pixel-lighting** — one Sun (hard shadows) + Sky/Color ambient + Filmic tonemap on the SubViewport env.
- **godot-composition / godot-code-rules** — strict typed GDScript on `ruined_warehouse.gd` + builder; gate `tools/validate.sh`.
- **godot-verify** — after every slice; GridMap has MeshLibrary + non-empty `get_used_cells`; actor inventory after re-bake.

## Spawn-constant constraint (must resolve in Slice F)
`levels/wave_manager.gd` hardcodes `const SPAWN_POS = Vector3(24,1,30)` / `SPAWN_ROT_Y = PI` (firing_yard's). On life-loss it teleports the player there → wrong for this level. Resolution (godot-dev decides exact mechanism, prefer minimal): make WaveManager read spawn from `@export` (set by builder to `(12,1,2)`/`PI`) OR from its level-root sibling's `SPAWN_POS`. Do NOT duplicate the const. This is the one cross-cutting code change; keep it surgical and re-verify firing_yard still respawns correctly.

## Later
- Bake NavigationRegion3D over floor + platform (`levels/ruined_warehouse_navmesh.tres`) if enemies fail to path.
- Per-zone accent point lights (corridor shadow pool, pocket glow).
- Ceiling / indoor occlusion for enclosed feel.
- Destructible breach rubble; wave-pacing tuning per gate.

## Open questions
None — all decisions applied from frozen brief + firing_yard precedent. Spawn-const change flagged above is an implementation note, not a design fork.
