# Firing Yard — Arena Greybox (B1)

**Goal** — F5 drops the player into the Firing Yard arena: a walkable 48 x 32 m sci-fi yard whose solid walls collide, with two raised platforms reachable by ramps, plus colour-coded placeholder props — lit and pixelated.

## Build method
GridMap + MeshLibrary, headless build path (skill `godot-gridmap-level`, step 4b). The level was drawn (`levels/drawn/current.json`, 51 wall cells) — never hand-authored `Transform3D` boxes. One `scripts/build_firing_yard.gd` (`@tool extends SceneTree`) generates `levels/firing_yard.tscn` (root `FiringYard`). Structure walls + floor come from the GridMap + a single floor slab; platforms, ramps and placeholder props are computed-position instances outside the GridMap (multi-cell same-id groups = ONE spanning instance at the group centre, never `×N`).

**Grid → world contract:** cell `(col,row)` → `Vector3(col*2, y, row*2)`; `cell_size = Vector3(2, 4, 2)`; wall cells are solid 2x4x2 blocks. Spawn the player at cell (12,15) → world `(24, ~1, 30)`, facing north (−Z).

## Two ordered slices (one doc, two godot-dev tasks)

### Slice B1a — Arena shell (build + verify first)
**Scope (in)**
- `resources/firing_yard_tiles.meshlib.tres`: one `wall` tile (solid 2x4x2 `BoxMesh`, flat `StandardMaterial3D` albedo `#404050`, welded `BoxShape3D` via `set_item_shapes`). Material on the MESH, not the node.
- `scripts/build_firing_yard.gd`: parse `current.json` (use the SEAM casting pattern — type-guard + `@warning_ignore("unsafe_cast")`), place a wall tile for every `cells` code `1`; ignore item/prop cells here.
- One floor slab: `StaticBody3D` + `BoxMesh` + `BoxShape3D`, 48 x (thin) x 32 m, top at y=0, albedo `#141420`.
- `DirectionalLight3D` cool blue-white (`#8888ff`, energy 1.2, hard shadows) angled from upper-north; `WorldEnvironment` with dark-blue ambient (`#101020`) and a dark solid sky (no visible horizon). No bloom / post-process.
- Instance `entities/player/player.tscn` named `Player` at spawn (24, ~1, 30), facing −Z.
- Register `res://levels/firing_yard.tscn` in `main.gd` `_levels` and set it as `initial_level` so F5 lands here.

**Acceptance (B1a)**
- F5 lands in Firing Yard (not the apartment); scene renders, not black, pixelated.
- `GridMap.get_used_cells()` is non-empty and equals the 51 wall cells; `cell_size == Vector3(2,4,2)`.
- Walk the whole floor; every visible wall blocks the player and the collider matches the mesh (no `shared_apartment`-style gap).
- Lighting reads: walls dark grey, floor near-black, light from the north.

### Slice B1b — Platforms & placeholder props (build + verify after B1a passes)
**Scope (in)** — extend the same builder; re-run to regenerate the scene.
- **High platform (id 5, cols 19-20 rows 2-3):** ONE `StaticBody3D` box spanning the 2x2 cell group (4x4 m footprint), top at +2 m, albedo `#606070`, welded `BoxShape3D`. One ramp on the south face (a tilted collidable box from floor up to the +2 m deck) — walkable up.
- **Mid platform (id 4, cols 19-20 rows 11-12):** same, top at +1 m, ramp on south face.
- **Hazard placeholder (id 1, 6 cells cols 5-8 rows 1-2):** ONE orange (`#e06020`) `BoxMesh` group on the floor, NO collision. Marks the future rotating hazard.
- **Wall-cling zone (id 2, cols 14-17 row 1 + cols 9-13 row 13):** flat cyan (`#208090`) wall-surface placeholders standing on the floor, NO collision. Two separate groups (one per row).
- **Fake walls (id 3, 18 perimeter cells):** thin/low pale-grey (`#909090`) markers, NO collision — player walks through.
- **Decorative props (id 6, 5 singles):** small dark olive/rust boxes (barrel/crate stand-ins) at each cell, NO collision.

**Acceptance (B1b)**
- F5: ramp up onto BOTH platforms; standing on each deck is solid (collision), one +1 m, one +2 m.
- Hazard (orange), wall-cling (cyan), fake-wall (pale grey) and decorative (olive) props read by colour at their briefed positions.
- The three no-collision groups (id 1, 2, 3, 6) are walk-through; only walls + platforms + ramps + floor block the player.

## Scope (out)
- id-1 rotating push-out hazard mechanic — Later (placeholder prop only).
- id-2 slow-gravity / wall-cling mechanic — Later (placeholder prop only).
- Perspective FPS eye-camera — Track A (A1); B1 is walkable under the existing rig now, camera-agnostic for later.
- Per-zone lighting accents, bloom, post-process — Later.
- B2 targets / enemies — separate phase.

## Skill notes
- `godot-gridmap-level` — headless build path (step 4b); SEAM casting on JSON; walls are solid cell-blocks; floor is one slab not per-cell; props are computed-position `StaticBody3D` instances; multi-cell same-id = one spanning instance at the centre (platforms span 2x2 → one box each).
- `godot-code-rules` — load before writing `scripts/build_firing_yard.gd`; strict typed GDScript; pass `tools/validate.sh`.
- `godot-main-scene` — register the level in `main.gd`/`_levels`; never `change_scene_to_file()`; loads under `Main/LevelHost`.
- `godot-pixel-lighting` — one DirectionalLight3D (hard shadows) + WorldEnvironment ambient/sky; Filmic tonemap, fixed exposure.
- `godot-3d-pixelation` — renders unchanged inside the existing SubViewport rig.
- `godot-verify` — mandatory 3-layer gate per slice, plus the gridmap verify additions (MeshLibrary assigned, non-empty cells, cell_size, floor extent, F5 walk).

## Later
- id 1: spinning push-out hazard (physics body, angular velocity, contact force).
- id 2: slow-gravity / wall-cling zone (gravity override on contact).
- Per-zone lighting accents (cyan glow on id-2, platform spotlights).
- Enemy spawn system keyed to this arena.
- Swap greybox placeholders for sourced low-poly props (asset-advisor loop).

## Open questions
None — brief is locked; all decisions resolved by recommendation (recorded above).
