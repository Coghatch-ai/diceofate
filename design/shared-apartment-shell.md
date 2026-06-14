# Shared Apartment — Shell (Slice 1)

**Goal** — Player can walk through the whole shared apartment greybox: all rooms, hallway, walls, windows and door gaps, with each zone's walls a distinct colour. No furniture yet.

**Scope (in)**
- New level scene `levels/shared_apartment.tscn`, root node `SharedApartment`, built with the **`godot-gridmap-level`** method (GridMap + MeshLibrary, computed from `levels/drawn/current.json` — never hand-typed `Transform3D` walls).
- MeshLibrary `resources/apartment_tiles.meshlib.tres` with structure tiles only:
  - One **wall** tile per zone colour (mesh material baked in — material on the MESH, not the node): `wall_kitchen` Color(0.91,0.84,0.64), `wall_twin` Color(0.83,0.72,0.63), `wall_master` Color(0.93,0.87,0.80), `wall_hall` Color(0.78,0.74,0.71), `wall_bath` Color(0.94,0.92,0.90). Wall cell = solid box `Vector3(1.5, 3, 1.5)`.
  - One **window-sill** tile: short solid wall (~1.5 m) + translucent glass plane above, axis-aligned, for row-0 windows.
- One `GridMap` with `cell_size = Vector3(1.5, 3, 1.5)` (1.5 m/cell × 3 m wall height) and the MeshLibrary assigned; populated by an author-time `@tool` importer (rebuild flag), scene saved so cells are baked into the `.tscn`. Importer maps room id → wall colour tile; door cells (code 2) and floor (code 0) left as gaps.
- One **floor slab**: single `StaticBody3D` + `BoxMesh`/`BoxShape3D` sized to grid extent (36 m × thin × 24 m), wood-tone albedo Color(0.78,0.66,0.48). Bathroom floor override deferred (see Later).
- `DirectionalLight3D` + `WorldEnvironment` (ProceduralSky, Filmic tonemap) per the brief's Look section (warm sun ~45° azimuth / 30° elevation, energy 0.8, low ambient) — skill `godot-pixel-lighting`.
- Register `SharedApartment` in `main.gd`'s level list so it loads under `Main/LevelHost`.

**Scope (out)**
- All 15 furniture prop types (beds, wardrobe, kitchen, bathroom fixtures, plants…) — next slice(s); they're what blows one-task scope. Walls/floor/windows are one safe importer run.
- Door-frame meshes (rotated frames) — door cells are passable gaps this slice; frames are dressing, parked.
- Bathroom light-tile floor override Color(0.92,0.90,0.88) — one extra slab, deferred to keep the floor a single slab.
- Per-tenant bedroom personality, functional doors, exterior skybox view, furniture collision — all parked in the brief's Later.
- Adding `SharedApartment` to the `cycle_level` Tab sequence — leave the existing basic_room→blockout cycle untouched unless asked.

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/shared_apartment.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- `tools/validate.sh` passes on the new `@tool` importer script.
- GridMap checks (skill godot-gridmap-level verify additions): MeshLibrary assigned, `get_used_cells()` non-empty, `cell_size == Vector3(1.5,3,1.5)`, cells baked into the `.tscn` (no `@tool` build at runtime).
- F5, load SharedApartment under `Main/LevelHost`: spawn at the corridor threshold (~cell 14,5) looking down the corridor; walk the full apartment — every room reachable through its door gaps, the long corridor reads as open vs. the tighter bedrooms, each zone's walls are a visibly different colour, windows line the top edge, and **every visible wall has a matching collider** (the `shared_apartment` 6 m mesh/collider gap must be impossible).

**Skill notes**
- `godot-gridmap-level` — the build method; structure-only this slice (its step 3 props deferred). Materials on the mesh, one wall tile per zone colour, importer is `@tool` author-time only.
- `godot-pixel-lighting` — sun + Filmic tonemap + ambient fill on the SubViewport Environment.
- `godot-main-scene` — register in `main.gd` `_levels`; loads under `Main/LevelHost`, never `change_scene_to_file()`.
- `godot-code-rules` — load before writing the `@tool` importer; strict typed GDScript, `tools/validate.sh` gate.
- `godot-verify` — mandatory 3-layer check before done.

**Later**
- Prop slice(s): instance the 15 item ids at computed positions, grouped per room (kitchen, twin bed, master bed, bathroom). Likely 2–3 small slices.
- Bathroom floor-tile override (second slab) + raised step (+0.25 m).
- Rotated door-frame meshes in the door gaps for the worn domestic look.
- Per-tenant bedroom personality (posters, rugs, accent colour).
- Functional doors (open/close on interact) — pairs with the existing interaction-system.
- Exterior view through windows (skybox backing).

**Open questions** — none.
