# Shared Apartment — Slice 2: Bedroom B furniture (+ chair prop)

**Goal** — The top-right bedroom (zone 10) is furnished — beds, wardrobes, a desk with chair, a nightstand — so it reads as a lived-in bedroom from inside.

**Scope (in)**
- Add ONE new prop spec `chair` to `tools/gen_models.gd` `_props` (id 4 has no model yet): seat slab + 4 legs + a low backrest, authored at true metres (~0.45 × 0.9 × 0.45, seat at ~0.45 m, native Y-min = 0). Re-run `gen_models.gd` + `--import`.
- In `tools/build_shared_apartment.gd` (the same single builder), after the shell, instance these props for zone 10 (cols 16-23, rows 1-4) as computed child `Node3D`s of the level root. All at near-uniform scale ~(1,1,1); each rests on the floor via `floor_y_offset = -(native AABB Y_min)*scale`. Positions are cell-centre `Vector3((col+0.5)*1.5, floor_y_offset, (row+0.5)*1.5)`; multi-cell same-id groups → ONE prop at the group centre, long axis oriented along the group's long span, NOT stretched.
  - `single_bed` ×2: bed group A cells (18,2)(18,3)(18,4) — vertical span, place at centre cell (18,3), long axis along Z; bed group B cells (19,2)(19,3)(19,4) — at (19,3), long axis along Z. (Headboards toward row 2 / -Z.)
  - `wardrobe` ×2: cells (22,2) and (22,3) — against the east wall; back to +X wall.
  - `desk`: cell (21,1). `chair`: cell (20,1), facing the desk.
  - `nightstand`: cell (20,4).

**Scope (out)**
- Other rooms — their own slices.
- Bedside lamp on the nightstand — Later (the `lamp` prop exists but isn't in the grid).
- Wall-mounted / hanging decor, rugs — not in the grid, not now.

**Acceptance**
- `tools/validate.sh` passes; `gen_models.gd` + `--import` report no errors; `chair.glb` loads as a PackedScene.
- Rebuild via `build_shared_apartment.gd` + `--import`; `levels/shared_apartment.tscn` updated, scene loads (godot-verify layers 1–2).
- VISUAL gate: `tools/capture_screenshot.gd` interior diagnostic over zone 10 centre, e.g. `"29.25,6,4.5" "29.25,0.5,4.5" "10.0"`. godot-dev reads the PNG: two beds upright (NOT crushed flat), wardrobes against the wall, desk+chair paired, nightstand on the floor — all at sane scale, none stretched, none floating.
- F5 human look: walk into Bedroom B; furniture sits on the floor, doesn't block the doorway, reads as a bedroom.

**Skill notes**
- `godot-procedural-model` — append the `chair` spec; near-uniform scale; compute `floor_y_offset`; never per-axis stretch (crushed-bed / bloated-desk lesson).
- `godot-mesh-import-pixel-art` — instance the `.glb` as a child node in place of the item cell, NOT a texture on a box.
- `godot-gridmap-level` (§3 hybrid) — props are computed child nodes, not GridMap cells.
- `godot-code-rules` — before editing the builder/gen_models.

**Later**
- Lamp on the nightstand. Rug under the beds. Posters on the wall.

**Open questions** (defaults)
- Bed orientation: headboard toward -Z (row 0 / window wall); flip if it reads better against the solid wall.
- Wardrobe facing: doors toward room interior (-X); adjust after the screenshot.
