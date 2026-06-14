# Level: Shared Apartment

**Concept** — A three-person shared apartment the player explores from the central hallway: a kitchen zone, a twin bedroom, a master bedroom, a bathroom, and a long corridor connecting them all. Dense with everyday furniture props; the scale and clutter make the space feel lived-in.

**Source** — levels/drawn/current.json (24×16 grid · cell_size hint 1 m overridden below)

**Scale** — 1.5 m per cell · wall height 3 m · flat throughout (no elevation change)
- Building footprint: ~36 m wide × 24 m deep (24 × 16 cells × 1.5 m)
- Bedroom widths: ~6–9 m; hallway corridor: ~16.5 m long × 4.5 m wide

**Layout** — Two horizontal bands separated by a full-width dividing wall at grid row 5.

TOP BAND (rows 0–5) — four side-by-side walled rooms, exterior windows lining the top edge (row 0):
- Room 50 (x=2–6, y=0–6): Kitchen — left zone, ~7.5 m wide
- Room 40 (x=7–10, y=0–5): Kitchen (continuation) — rooms 50 and 40 together form one open kitchen zone; the interior wall between them may be partial or open
- Room 20 (x=11–15, y=0–5): Twin bedroom — ~7.5 m wide, two single beds + two nightstands
- Room 10 (x=16–23, y=0–5): Master bedroom — ~12 m wide; the largest room, has wardrobe, double bed, nightstand, chair, laptop table

DIVIDING WALL (row 5) — solid wall full width, broken by two double-door openings:
- Cols 13–14: twin bedroom → hallway
- Cols 16–17: master bedroom → hallway (exact door cell positions from grid: `1,2,2,1,2,2,1,1,1,1,1,1` starting col 2)

BOTTOM BAND (rows 6–9):
- Room 60 (x=3–17, y=6–8): Hallway / corridor — the hub; ~22.5 m long × 4.5 m wide; all rooms connect here
- Room 30 (x=18–23, y=6–9): Bathroom — right alcove off corridor, ~9 m × 6 m

Flow: player spawns at the double-door threshold (row 5, centre ~col 14) → steps into the long corridor → kitchen zone to the left, bathroom to the right; double doors lead back up into the bedrooms. The contrast between the tight bedroom widths and the open corridor is the spatial payoff.

**Tiles**
- Wall (1): solid 3 m wall mesh + collision; colour varies per zone (see Look)
- Door (2): open archway with door frame mesh; passable gap, no blocking collision; frame rotated 5–10° for a worn domestic look. Door locations: double-door pairs at row 5 cols 13–14 and 16–17; single door at (2,6) corridor entry; door at (22,7)–(22,8) bathroom entrance
- Window (3): half-height sill (~1.5 m) + translucent glass plane above; exterior wall only (row 0, full width). Solid below sill, see-through above; axis-aligned (clean look)
- Items (4) — placeholder prop markers; same id = same prop type; props placed at slight diagonal for shape variety:
  - id 1 · Wardrobe — 2 cells vertical pair in master bedroom (22,2)–(22,3), wall-side
  - id 2 · Nightstand — 3 cells in twin + master bedrooms: (13,1), (14,3), (20,4)
  - id 3 · Bed — 12 cells across twin + master bedrooms; each 2-cell grouping = one bed unit; single beds in twin room (room 20), double bed in master (room 10)
  - id 4 · Chair — 5 cells: (20,1) master bedroom; pairs at (3,3)–(3,4) and (5,3)–(5,4) kitchen zone
  - id 5 · Laptop table / small desk — 1 cell in master bedroom (21,1)
  - id 6 · Couch — 2 cells vertical pair in kitchen/hallway boundary (10,3)–(10,4) — reinterpreted as couch in or near the kitchen area
  - id 7 · TV unit — 2 cells vertical pair (7,3)–(7,4), facing couch
  - id 8 · Plant — 1 cell at (10,1), decorative, no collision
  - id 9 · Plant — 1 cell at (7,1), kitchen/entry boundary, decorative
  - id 11 · Shower / bathtub — 3 cells vertical strip in bathroom (22,6)–(22,8)
  - id 12 · Toilet — 1 cell in bathroom (20,6)
  - id 13 · Bathroom sink / vanity — 1 cell in bathroom (21,8)
  - id 14 · Kitchen counter / worktop — 2 cells vertical pair in kitchen room 50 (3,3)–(3,4)
  - id 15 · Kitchen appliance (stove/oven) — 2 cells vertical pair in kitchen room 50 (5,3)–(5,4)

**Rooms — zone identities and wall colours**
- Room 50 + 40 (Kitchen): warm cream walls Color(0.91, 0.84, 0.64)
- Room 20 (Twin bedroom): warm terracotta walls Color(0.83, 0.72, 0.63)
- Room 10 (Master bedroom): warm off-white walls Color(0.93, 0.87, 0.80)
- Room 60 (Hallway / corridor): neutral warm grey walls Color(0.78, 0.74, 0.71); the contrast anchor
- Room 30 (Bathroom): white/light tile walls Color(0.94, 0.92, 0.90); brighter, cleaner

**Spawn** — At the double-door threshold, centre of row 5, approximately cell (14, 5); player spawns looking down the full corridor length

**Look**
- Floor: warm wood-tone across all rooms Color(0.78, 0.66, 0.48); bathroom override: light tile Color(0.92, 0.90, 0.88)
- Walls: per-zone flat StandardMaterial3D albedo as listed above
- Props: flat StandardMaterial3D per prop type; rough material distinctions (wood for beds/wardrobe, white for bathroom fixtures, metal/enamel for kitchen appliances)
- Lighting: DirectionalLight3D angled softly from upper-left (~45° azimuth, 30° elevation); warm colour Color(1.0, 0.95, 0.85); energy 0.8. ProceduralSky with warm horizon tint. Tonemap: Filmic (tonemap_mode=3). Low ambient energy. Soft domestic interior feel with readable pixel-art shadows.

**Handoff** — to game-designer: turn this level design into the buildable design. Decide how to build it — the CLAUDE.md draw-level pipeline specifies GridMap + MeshLibrary via the `godot-gridmap-level` skill. The level is mid-size (24×16, 6 rooms, 15 item ids); consider splitting into per-room build slices that can each be built and verified independently. Dispatch godot-dev to build the greybox as a GridMap scene at `levels/shared_apartment.tscn`, root node `SharedApartment`, registered in `main.gd`, verified with `godot-verify`. Source grid: `levels/drawn/current.json`.

**Later**
- Functional doors (open/close on interact) — parked
- Raised bathroom step (+0.25 m) — parked; flat throughout chosen for now
- Per-tenant bedroom personality (posters, rugs, colour accent) — parked
- Exterior view through windows (skybox backing) — parked
- Collision on furniture props (beds, wardrobe) if gameplay requires blocking — parked
- **Window representation** — parked (2026-06-14, user-accepted as prototype). The brief asked for a sill solid below + translucent glass pane above; the `window_sill` MeshLibrary tile was built as a single opaque grey 1.5×1.5×1.5 m box (no glass pane) and centred at the cell's vertical origin, so it floats ~0.75 m off the floor instead of resting on it. Not a GridMap limit — both are tile-authoring fixes (a second mesh + transparent material for the glass; a `mesh_transform` Y-offset to seat the sill on the floor). The only genuine GridMap awkwardness is that a window occupies a full 1.5 m cell, so it always reads chunky. Revisit when window fidelity matters; candidate for a window-tile improvement to `godot-gridmap-level` or a dedicated windows skill.
