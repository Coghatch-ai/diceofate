# Shared Apartment — Slice 3: Bedroom A furniture

**Goal** — The second bedroom (zone 20, cols 11-15) is furnished — two beds and two nightstands — so it reads as a shared/twin bedroom.

**Scope (in)**
- In `tools/build_shared_apartment.gd` (same single builder), instance for zone 20 as computed child `Node3D`s at near-uniform scale, each seated via `floor_y_offset`. Cell-centre formula and multi-cell grouping as in Slice 2.
  - `single_bed` ×2: bed group A cells (12,1)(12,2)(12,3) — vertical span, place at centre (12,2), long axis along Z; bed group B cells (15,1)(15,2)(15,3) — at (15,2), long axis along Z. Headboards toward row 0 / -Z.
  - `nightstand` ×2: cell (13,1) (between the bed heads) and cell (14,3).

**Scope (out)**
- Other rooms — their slices. Lamps, rugs, wall decor — Later, not in the grid.

**Acceptance**
- `tools/validate.sh` passes; rebuild + `--import` clean; scene loads (godot-verify 1–2).
- VISUAL gate: `tools/capture_screenshot.gd` interior diagnostic over zone 20 centre, e.g. `"19.5,6,3.0" "19.5,0.5,3.0" "9.0"`. godot-dev reads the PNG: two beds upright at sane scale (not crushed), nightstands beside them on the floor, nothing stretched or floating.
- F5 human look: walk into Bedroom A; reads as a twin bedroom, furniture on floor, doorway clear.

**Skill notes**
- `godot-procedural-model` — near-uniform scale, computed `floor_y_offset`, no per-axis stretch.
- `godot-mesh-import-pixel-art` — instance `.glb` child nodes.
- `godot-gridmap-level` (§3 hybrid) · `godot-code-rules`.

**Later**
- Lamp on a nightstand; rug; wardrobe if the room feels bare.

**Open questions** (defaults)
- Bed orientation: headboards toward -Z (window wall); flip if it reads better.
