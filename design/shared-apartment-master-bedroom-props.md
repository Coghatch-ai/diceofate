# Shared Apartment — Master Bedroom Props (Slice 2)

> **Rebuild note (2026-06-14).** This slice is already folded into the builder: `tools/build_shared_apartment.gd._build()` calls `_place_props()`, so the five props regenerate in the **same run** as the Slice-1 shell — they are NOT a separate dispatch on rebuild. Cell coordinates below match the unchanged `current.json`. See `design/shared-apartment-rebuild.md`.

**Goal** — The master bedroom of the shared apartment is dressed with greybox furniture (bed, wardrobe, nightstand, chair, desk) so it reads as a furnished room — a believable in-context stage for swapping in a real textured asset later.

**Scope (in)**
- One author-time builder pass that instances **five greybox prop nodes** into the existing `levels/shared_apartment.tscn`, as direct children of the `SharedApartment` root (NOT GridMap cells — per `godot-gridmap-level` step 3, furniture is computed-position instanced nodes). The walls/floor/windows/lighting/spawn from Slice 1 are untouched.
- Props are **flat-coloured greybox primitives** (`MeshInstance3D` + `BoxMesh`, baked `StandardMaterial3D` albedo), correct footprint and height, one named node per prop so any single one is a clean 1:1 swap target for a future real asset. No collision this slice (parked — gameplay doesn't need it yet).
- Cell→world: `cell_center_*` is true on the existing GridMap, so cell `(col,row)` centre = world `((col*1.5)+0.75, y, (row*1.5)+0.75)`. Multi-cell props centre on their cell-group midpoint. Sit each box so its base rests on the floor (floor top ≈ y 0; box centre y = height/2). All positions **computed**, never eyeballed.
- The five props (master bedroom = room 10, item cells from `levels/drawn/current.json`):
  - **Bed (id 3)** — cells (18,2)(19,2)(18,3)(19,3)(18,4)(19,4): one double bed, ~3 m × 4.5 m footprint, low box ~0.5 m high, warm wood albedo Color(0.55,0.40,0.28). Node `BedMaster`, centred on the 6-cell group.
  - **Wardrobe (id 1)** — cells (22,2)(22,3), wall-side: tall box ~1.5 m × 3 m footprint, ~2 m high, wood albedo Color(0.50,0.36,0.25). Node `Wardrobe`.
  - **Nightstand (id 2)** — cell (20,4): small box ~0.7 m cube, ~0.6 m high, wood albedo Color(0.58,0.43,0.30). Node `NightstandMaster`.
  - **Chair (id 4)** — cell (20,1): small box ~0.6 m × 0.6 m, ~0.9 m high, muted albedo Color(0.45,0.45,0.50). Node `ChairMaster`.
  - **Desk / laptop table (id 5)** — cell (21,1): box ~1.2 m × 0.7 m, ~0.75 m high, wood albedo Color(0.52,0.38,0.27). Node `DeskMaster`.
- Build via the existing headless builder pattern: extend `tools/build_shared_apartment.gd` with a `_place_props()` pass (only the master-bedroom five), or a sibling `tools/build_shared_apartment_props.gd` that loads the saved scene and adds the nodes. Either way it stays the **one build path** for this scene (skill rule: don't fork two importers) — prefer extending the existing builder so the scene regenerates in one run. Re-save the `.tscn` with the props baked in.

**Scope (out)**
- The other 10 prop types (kitchen counter/stove/TV/couch/plants, bathroom fixtures, twin-room beds/nightstands) — later room slices; out so this stays one verifiable task.
- Prop collision — parked; nothing walks into furniture yet.
- Per-tenant personality (poster, rug, accent colour on the master bed wall) — parked; this slice is furniture only.
- Final textured meshes / real assets — that's the *next* action this dressing enables, not this slice.
- Rotated/diagonal prop placement for shape variety — props axis-aligned this slice; diagonal flourish parked.

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/shared_apartment.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- `tools/validate.sh` passes on the builder script.
- The five named prop nodes (`BedMaster`, `Wardrobe`, `NightstandMaster`, `ChairMaster`, `DeskMaster`) exist under `SharedApartment` in the saved `.tscn`, each a `MeshInstance3D` with a baked-material `BoxMesh`.
- F5, load SharedApartment, walk to the master bedroom (right end of the corridor, up through the master door): the room reads as furnished — a double bed against the far area, a tall wardrobe on the right wall, a nightstand by the bed, a chair + desk by the top wall. Every prop sits **on the floor** (no floating, no sinking) and inside the room's walls (no clipping through walls). Nothing else in the apartment changed.

**Skill notes**
- `godot-gridmap-level` (step 3 — hybrid) — furniture is instanced prop scenes/nodes at computed positions, NOT GridMap cells. One build path only; extend the existing `tools/build_shared_apartment.gd`.
- `godot-code-rules` — load before editing the builder; strict typed GDScript, `tools/validate.sh` gate. Reuse the SEAM cast pattern already in the builder for any JSON reads.
- `godot-verify` — mandatory 3-layer check before done.
- `godot-main-scene` — scene already registered in `main.gd`; no change needed.

**Later**
- Kitchen / living slice: counter (id 14), stove (id 15), TV (id 7), couch (id 6), plants (id 8, id 9).
- Bathroom slice: shower/tub (id 11), toilet (id 12), sink/vanity (id 13) + bathroom floor-tile override.
- Twin bedroom slice: two single beds (id 3), two nightstands (id 2).
- Per-tenant personality for the master room (poster/rug/accent) — earns its own slice once an asset-test loop is running.
- Prop collision pass if gameplay starts blocking on furniture.
- Diagonal prop rotation for shape variety.

**Open questions** — none.
