# Level: Ruined Warehouse

**Concept** — Indoor FPS wave-combat arena: player holds the kill floor of a ruined warehouse compound while enemy waves push in through breach gates on the south and side walls; pickups scattered on the open floor reward aggressive positioning.

**Source** — levels/drawn/current.json (24×16, 384 cells: ~130 wall, ~230 floor, 52 item-coded)

**Scale** — 2 m per cell · wall height 3.5 m · felt size: ~48 m × 32 m open interior

**Layout** — Three zones, read left→right / north→south:
- **Entry corridor** (top-left, ~x0–8, y0–4): tight walled pocket, 2–3 cells wide; player spawn here. Pinch point: single-cell gap at y4 opens onto kill floor. Dark tint, lower perceived ceiling.
- **Kill floor** (centre, ~x6–20, y4–12): open arena ~28×16 m. Two cover-wall runs (id=2 barriers) crossing the space — one at top (y1), one at bottom (y13) — create mid-ground skirmish rhythm. Item-6 scattered pickups reward crossing the open.
- **Flanking pockets** (right side, ~x18–23): two enclosed alcoves — top-right (id=5 cluster, y2–3) health cache; right-mid (id=4 cluster, y11–12) elevated ammo cache (+1 m raised platform). Enemies can push through right-side wall gaps to contest these.
- **Breach gates** (south edge, y15): id=3 gate strips at x4–7 and x15–18 are enemy wave entry portals. Also id=3 left-edge (x0, y4–15) and right-edge (x23, y11–14) as side breach slots.
- Flow: spawn NW → push south across kill floor → contest pickups → fall back to pocket cover between waves.

**Tiles**
- wall (code 1): BlockMesh box 2×3.5×2 m, flat colour `Color(0.251, 0.251, 0.314)` (matches firing_yard wall tint)
- door (code 2): passable gap, no collision; optional frame mesh (thin 0.2 m box, 5° rotation offset for worn look)
- window (code 3): **repurposed as breach gate / entry marker** — half-height wall (1.5 m) or open gap with rubble sill mesh; no blocking collision on designated south gate strips (id=3 at y15 and side-edge clusters); decorative sill elsewhere
- item ids:
  - id=1 → player spawn zone marker (x5–8, y1–2); no mesh — used only to determine spawn cell
  - id=2 → cover wall prop: low concrete barrier, ~0.8 m tall BoxMesh, full collision; placed as horizontal cover runs
  - id=3 → breach gate / perimeter marker: open gap + rubble frame mesh (no collision); side/bottom perimeter = wave spawn portals
  - id=4 → ammo crate cluster: 2×2 at x19–20 y11–12 on +1 m raised platform; `pickup_ammo.tscn` × 4
  - id=5 → health pack cluster: 2×2 at x19–20 y2–3; `pickup_health.tscn` × 4
  - id=6 → floor pickup spawns (scattered 5 cells: x2 y6, x8 y8, x6 y10, x15 y10, x2 y13); `pickup_ammo.tscn` × 5, placed flat on floor
- rooms: none painted in source; zones defined by geometry above

**Spawn** — Player auto-spawn: cell (6, 1) — central-most floor cell of id=1 cluster, facing south (into kill floor)

**Look**
- Floor: `Color(0.078, 0.078, 0.125)` flat dark tile (matches firing_yard floor)
- Entry corridor walls: `Color(0.18, 0.18, 0.22)` — slightly darker, tighter feel
- Kill floor walls: `Color(0.251, 0.251, 0.314)` — standard warehouse grey
- Pocket walls: `Color(0.20, 0.20, 0.28)` — mid tone, sets them apart from open floor
- Cover barriers (id=2): `Color(0.35, 0.30, 0.25)` — warm concrete
- Raised platform (id=4 zone): +1 m floor slab, same dark floor colour
- Lighting: standard `DirectionalLight3D` (energy 1.2, angle 45°) + ambient via Sky; no special per-zone lights (park for later)

**Verticality** — One height tier: id=4 pocket (x19–20, y11–12) raised +1 m; single-step ramp or lip at east edge of kill floor. Provides sightline advantage / risk-reward for ammo run.

**Space contrast** — Entry corridor (tight, dark) → kill floor (wide, mid-lit) → flanking pockets (enclosed, reward). Cover walls break sightlines mid-floor so open space feels earned, not empty.

**Shape variety**
- id=2 cover barriers: BoxMesh rotated 0° (straight run) — geometry, full collision
- id=3 breach gates: thin rubble-sill mesh, 5–10° yaw offset per gate for organic ruin feel, no collision
- id=6 floor pickups: placed with slight random yaw (±15°) for scatter feel

**Inferred assumptions (reviewable)**
- No rooms painted in source JSON (`rooms: []`); zones inferred from geometry + item clustering.
- id=3 (code: window) reinterpreted as breach gates — the perimeter/bottom placement makes functional doors more logical than windows.
- id=2 (code: door) reinterpreted as cover barriers — horizontal mid-space runs don't read as doors; low barrier fits FPS cover.
- Cell (6,1) chosen as spawn; if enemy nav enters from y15, player faces waves immediately on south push.
- Wave manager (`wave_manager.gd`) wires up to enemy spawn points at breach gate cells — those positions should be passed as spawn transforms to the wave manager, same pattern as firing_yard.

**Handoff** — to game-designer: turn this level design into the buildable design (decide how to build it, split into pieces if large), then dispatch godot-dev.

**Later**
- Per-zone point lights (corridor shadow pool, pocket accent).
- Destructible rubble on breach gates.
- Ceiling mesh / skybox occlusion for full indoor feel.
- Wave manager spawn-point assignment to breach gate cells.
- Nav mesh bake over raised platform.
