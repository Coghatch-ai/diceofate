# Shared Apartment — Slice 1: GridMap shell

**Goal** — The player spawns inside a walkable, multi-room apartment shell (walls, floor, window strip, lit) loaded from the drawn grid; F5 drops you in and you can walk the rooms and corridor.

**Scope (in)**
- Recreate the single builder `tools/build_shared_apartment.gd` (@tool extends SceneTree, headless) — it is the ONE build path for both shell and props (props arrive in later slices). This slice builds shell only.
- Build a MeshLibrary `resources/apartment_tiles.meshlib.tres` with these tile items (materials on the MESH, flat opaque `StandardMaterial3D`, pixel-art look):
  - `wall_<zone>` — one solid-block variant per room zone, sized `Vector3(1.5, 3, 1.5)`, each a distinct muted colour so zones read apart: zone 50 kitchen warm-grey, 40 lounge cool-blue, 20 bedroomA muted-green, 10 bedroomB muted-purple, 60 corridor neutral-grey, 30 bathroom pale-cyan. Pick one colour per zone; record the hex you used.
  - `window` — layered tile: short opaque sill (~1.0 m tall, seated on floor via the Y-shift gotcha) + a transparent glass pane box above it (`TRANSPARENCY_ALPHA`, alpha ~0.3); one shared `StaticBody3D`/`CollisionShape3D` sized to the sill.
- Add a `GridMap` "ApartmentMap" with `cell_size = Vector3(1.5, 3, 1.5)`, `cell_center_x/y/z = false`, the meshlib assigned, populated from `levels/drawn/current.json` (24×16, row-major) via the SEAM casting pattern. Code map: `0`=floor→empty, `1`=wall→`wall_<zone of that cell or nearest room>`, `2`=door→empty (passable gap), `3`=window→`window`, `4`=item→empty (floor; props later). For a wall cell pick the zone colour of an adjacent room cell (deterministic: scan N/E/S/W, first room hit; fallback corridor-grey).
- One `StaticBody3D` floor slab: `BoxMesh` + `BoxShape3D` sized `Vector3(24*1.5, 0.2, 16*1.5)` centred under the grid, top at `y=0`, flat pixel-art material.
- Lighting (skill `godot-pixel-lighting`): one `DirectionalLight3D` sun with hard shadows + `WorldEnvironment` (Sky or flat ambient, Filmic tonemap, fixed exposure).
- A `Player` instance (entities/player/player.tscn) placed on a floor cell inside the corridor zone 60, e.g. cell (10,7) → `Vector3(15.75, 0.1, 11.25)`.
- Save to `levels/shared_apartment.tscn` (cells baked in). Register in `main.gd`: add to `_levels` and set as `initial_level` so the shell loads on F5 under `Main/LevelHost`.

**Scope (out)**
- All furniture/props — later slices (one per room); item cells render as plain floor here.
- Door-frame meshes — doors are passable gaps this slice (no frame geometry).
- Ceilings, exterior, skybox detailing beyond a plain sky/ambient — not needed to read the rooms.
- Per-room floor textures — one slab, flat colour; zone reads come from wall colour.

**Acceptance**
- `tools/validate.sh` passes (builder + importer are strict typed GDScript).
- `$GODOT --headless --path . --script tools/build_shared_apartment.gd` then `--import` report no errors; `levels/shared_apartment.tscn` exists.
- godot-verify layers 1–2: scene loads, GridMap has meshlib + `get_used_cells()` non-empty, no silent-dropped properties, renders non-black.
- VISUAL gate: `tools/capture_screenshot.gd` interior diagnostic mode, low vantage over the corridor — e.g. `"15.75,6,11.25" "15.75,0.5,8.0" "9.0"`. godot-dev reads the PNG and confirms: distinct walls enclose the six zones, window strip along row 0, floor present, scene lit and readable (not top-down-flat).
- F5 human look: walk corridor → into each room through the door gaps; no wall clips; a collider matches every visible wall (the old shared_apartment 6 m mesh/collider gap must be impossible).

**Skill notes**
- `godot-gridmap-level` — the build method; ONE build path (headless builder, not also an editor importer). Window = layered/Y-shifted tile per the gotchas. Wall cell = solid block, not thin plane.
- `godot-pixel-lighting` — sun + WorldEnvironment exactly as blockout levels.
- `godot-main-scene` — load under `Main/LevelHost`; never `change_scene_to_file`; register in `_levels` + set `initial_level`.
- `godot-code-rules` — load before writing the builder; JSON.parse SEAM pattern (type-guard + `@warning_ignore("unsafe_cast")`).

**Later**
- Door-frame meshes in the door gaps.
- Per-room floor textures (procedural surface placeholders).
- Ceiling so an overhead camera doesn't see in (only if a top-down view is ever wanted).

**Open questions** (stated defaults, not blockers)
- Zone wall colours: defaults above; godot-dev may tune for readability and record the hex.
- Player spawn: corridor cell (10,7); adjust if it lands in a wall after the exact wall-cell derivation.
