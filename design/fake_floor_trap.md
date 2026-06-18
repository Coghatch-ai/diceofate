# Fake-Floor Fall-Through Trap (ruined_warehouse)

**Goal** — Three floor tiles in the warehouse look like the real floor (faint tell) but have no
collision, so a player who steps on one drops through into the void and snaps back to spawn a
moment later. The horizontal sibling of the fake-wall trap.

## Build method
Extend the existing headless builder `scripts/build_ruined_warehouse.gd` (`@tool extends SceneTree`,
skill `godot-gridmap-level`) and re-run it to regenerate `levels/ruined_warehouse.tscn` — the baked
`.tscn` is generated output, never hand-edited. The fake tiles, the floor holes, and the fall-detect
trigger are all baked there. The respawn handler is a small addition to the level root
`levels/ruined_warehouse.gd` (currently bare — only spawn consts), mirroring `firing_yard.gd`'s
`_reset_player` + `_on_FallZone_body_entered` exactly.

**Grid → world contract (unchanged):** cell `(col,row)` → `Vector3(col*2, y, row*2)`;
floor cell is 2×2 m (`CELL_X=CELL_Z=2.0`). Floor look to copy: `FLOOR_COLOR=Color(0.078,0.078,0.125)`,
`FLOOR_THICK=0.2`, top at `FLOOR_Y=-0.1`. Player spawn `Vector3(12,1,2)`, facing +Z (`SPAWN_ROT_Y=PI`).

## Scope (in)
- **3 fake-floor tiles (new drawn-grid item id=7, all open interior floor cells):**
  | intent | cell (col,row) | world centre (x,z) |
  |---|---|---|
  | bait — beside ammo pickup at (8,8) | (9,8) | (18,16) |
  | retreat lane — east mid | (16,7) | (32,14) |
  | retreat lane — central | (13,5) | (26,10) |
  All three are confirmed grid-value-0 floor cells (no wall/barrier/pickup). Add them as
  `{"id":7,"x":..,"y":..}` entries in `levels/drawn/ruined_warehouse.json` `items`.
- **Fake-tile mesh (one per id=7 cell):** a 2×0.2×2 `BoxMesh` at the cell centre, top flush with the
  real floor (`y=-0.1`), using a material that is the `FLOOR_COLOR` base with a **faint tell** — a
  subtle discolour (e.g. albedo lightened/desaturated ~8–12%, no hard edge). Plain `MeshInstance3D`,
  **no collision** (not a body), so the player passes through.
- **Floor holes under fake tiles:** the real `FloorSlab` is one 48×32 slab — the player would land on
  it. Open a 2×2 gap in the playable floor at each id=7 cell so there is open void below the fake tile
  (builder's choice: per-cell hole in the slab, or rebuild the slab as sub-slabs leaving the 3 cells
  open). Real floor everywhere else stays solid.
- **Fall-detect trigger:** one `Area3D` (`FallZone`) with a wide flat `BoxShape3D` below the arena
  (top at y ≈ −6, spanning past the 48×32 footprint). `monitoring=true`; `collision_mask` includes
  the player layer (player is in group `player`; firing_yard uses the same Area pattern).
- **Respawn on fall:** in `ruined_warehouse.gd`, port firing_yard's `_reset_player(body)` +
  `_on_FallZone_body_entered` verbatim — `body.global_position = SPAWN_POS`, `rotation.y=SPAWN_ROT_Y`,
  `velocity=Vector3.ZERO` (duck-typed, `@warning_ignore("unsafe_property_access")`), gated on
  `is_in_group("player")`. A brief visible drop precedes the reset. Print `[trap] fell through -> reset`.

## Scope (out)
- **Life cost** — fall = snap-to-spawn only, NO life lost. Costing a life (per G2) would need a new
  public seam on `wave_manager.gd` (life-loss currently lives only on enemy contact); deferred to Later.
- **Enemies falling** — player-only. The pre-baked navmesh (`ruined_warehouse_navmesh.tres`) still
  covers the fake-tile cells, so enemies path over them as if solid and never drop. No navmesh re-bake.
- **VFX / audio on fall** — raw teleport, no whoosh/fade (matches fake-wall sibling).
- **Changing the disguise to identical** — confirmed faint tell, fairer (user choice).
- **More/fewer than 3 tiles, or open-floor scatter** — confirmed 3, bait + 2 retreat lanes.

## Acceptance
- Re-run `scripts/build_ruined_warehouse.gd` headless; regenerates `levels/ruined_warehouse.tscn`
  with no `push_error`; project still loads.
- F5 into Ruined Warehouse: real floor solid everywhere; the 3 fake tiles read like floor with only a
  faint tell.
- Step on any fake tile → player passes through (no collision) AND drops (no floor below).
- After the drop, `FallZone` catches the player → reappears at spawn `(12,1,2)` facing +Z, able to
  move/fire again. `[trap] fell through -> reset` prints. (One human F5 confirms gotcha + respawn.)
- Enemies walk over the fake-tile cells normally (none fall in).
- `tools/validate.sh` passes on changed `.gd` files.

## Skill notes
- `godot-gridmap-level` — fake tiles + holes + trigger baked in the headless builder; fake tiles are
  computed-position `MeshInstance3D` instances (one per id=7 cell), NOT GridMap tiles, so they omit
  collision while the real floor keeps it. One block per cell at the cell centre — never a `×N` count.
- `godot-code-rules` — load before editing the builder + `ruined_warehouse.gd`; strict typed GDScript;
  pass `tools/validate.sh`. JSON parse uses the existing SEAM `as`-cast pattern.
- `godot-verify` — mandatory 3-layer gate; plus: scene loads no node-name clash, real floor intact,
  fake-tile count == 3, FallZone present, F5 walk-onto + respawn observed.
- **Owner gotcha (existing builder rule):** for freshly-`.new()` nodes you create (fake tiles,
  FallZone, any sub-slabs) set `owner = scene_root` as the existing `_add_floor_slab` does; do NOT
  re-own children inside an instanced PackedScene (the player/pickup instances).

## Later
- Make a fall cost a life (G2 model) once `wave_manager.gd` exposes a public `lose_life()` seam.
- Respawn whoosh/fade polish.
- A subtle audio creak as the player steps onto a fake tile (telegraph).

## Open questions
None — count (3), placement (bait + 2 retreat lanes), disguise (faint tell), consequence
(snap-to-spawn, no life), enemies (player-only, navmesh intact) all resolved.
