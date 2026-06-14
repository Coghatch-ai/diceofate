# Shared Apartment — Slice 5: Bathroom furniture

**Goal** — The lower-right room (zone 30) reads as a bathroom — toilet, bathtub/shower, sink vanity — completing the furnished apartment.

**Scope (in)**
- In `tools/build_shared_apartment.gd` (same single builder), instance for zone 30 (cols 18-23, rows 6-9) as computed child `Node3D`s, near-uniform scale, each seated via `floor_y_offset`. Cell-centre formula and multi-cell grouping as in Slice 2.
  - `toilet` at cell (20,6) — tank backing the -Z wall.
  - `bathtub` group cells (22,6)(22,7)(22,8) → ONE bathtub at centre (22,7), long axis along Z (the bathtub prop is authored ~1.7 m long → spans without stretching; leaving floor either side is correct). Against the east wall.
  - `sink_vanity` at cell (21,8) — back to the -Z/wall.

**Scope (out)**
- Other rooms — their slices. Mirror, towel rail, bath mat — Later, not in the grid.

**Acceptance**
- `tools/validate.sh` passes; rebuild + `--import` clean; scene loads (godot-verify 1–2).
- VISUAL gate: `tools/capture_screenshot.gd` interior diagnostic over zone 30 centre, e.g. `"31.5,6,11.25" "31.5,0.5,11.25" "9.0"`. godot-dev reads the PNG: toilet, bathtub along the east wall, sink vanity — all sane scale, on the floor, not stretched.
- F5 human look: walk into the bathroom from the corridor; reads as a bathroom; fixtures on floor, doorway clear.

**Skill notes**
- `godot-procedural-model` — `toilet`/`bathtub`/`sink_vanity` already in `_props`; near-uniform scale, computed `floor_y_offset`, no per-axis stretch (bathtub authored long → spans cells without stretching).
- `godot-mesh-import-pixel-art` · `godot-gridmap-level` (§3) · `godot-code-rules`.

**Later**
- Mirror over the vanity, towel rail, bath mat, shower screen on the tub.

**Open questions** (defaults)
- Bathtub vs shower for id 11: using the `bathtub` prop (semantics say bathtub/shower); fine as-is.
