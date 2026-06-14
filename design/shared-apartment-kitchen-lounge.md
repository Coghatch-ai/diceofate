# Shared Apartment — Slice 4: Kitchen + Lounge furniture

**Goal** — The left wing reads as a kitchen (zone 50: counters + stoves) and an adjacent lounge (zone 40: couches, TVs, plants).

**Scope (in)**
- In `tools/build_shared_apartment.gd` (same single builder), instance for zones 50 and 40 as computed child `Node3D`s, near-uniform scale, each seated via `floor_y_offset`. Cell-centre formula and multi-cell grouping as in Slice 2.
  - **Kitchen (zone 50):** `counter` group cells (3,3)(3,4) → ONE counter at centre (3, 3.5), long axis along Z (the counter prop is authored ~3 m long along Z → spans the 2 cells). `stove` group cells (5,3)(5,4) → place a `stove` per cell (stove is a single-cell appliance ~0.6 m), or one stove at (5,3.5); default: two stoves, one per cell. Both against the room's west/back wall.
  - **Lounge (zone 40):** `plant` ×2 at cells (7,1) and (10,1) (corners). `tv` group cells (7,3)(7,4) → ONE tv at centre (7,3.5), long axis along Z, screen facing +X (into the room). `couch` group cells (10,3)(10,4) → ONE couch at centre (10,3.5), long axis along Z, facing -X (toward the TV).

**Scope (out)**
- Other rooms — their slices. Fridge, table+chairs, rug, upper cabinets — Later, not in the grid.

**Acceptance**
- `tools/validate.sh` passes; rebuild + `--import` clean; scene loads (godot-verify 1–2).
- VISUAL gate: two diagnostic shots or one wide one covering both zones —
  - Kitchen: `"6.0,6,5.25" "6.0,0.5,5.25" "9.0"`
  - Lounge: `"13.5,6,5.25" "13.5,0.5,5.25" "9.0"`
  godot-dev reads the PNG(s): counter spans its 2 cells along the wall, stoves beside it; couch faces the TV across the lounge, plants in corners — all sane scale, on the floor, not stretched.
- F5 human look: walk the left wing; kitchen and lounge read distinctly; couch-faces-TV; nothing blocks the corridor door.

**Skill notes**
- `godot-procedural-model` — `counter`/`stove`/`couch`/`tv`/`plant` already in `_props`; near-uniform scale, computed `floor_y_offset`, no per-axis stretch (counter is authored long, so it spans cells WITHOUT stretching).
- `godot-mesh-import-pixel-art` · `godot-gridmap-level` (§3) · `godot-code-rules`.

**Later**
- Fridge, dining table + chairs, kitchen rug, wall cabinets.

**Open questions** (defaults)
- Stove count: two single-cell stoves (one per item cell) vs one; default two. Adjust after screenshot.
- Couch/TV facing: couch -X, TV +X (face each other across the lounge); confirm with the shot.
