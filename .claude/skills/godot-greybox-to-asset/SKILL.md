---
name: godot-greybox-to-asset
description: Migrate a finished greybox blockout to final sourced assets in Godot 4.6 — the REPLACE half of the blockout loop (godot-greybox BUILDS it; this skill RETIRES it). Identify every BoxMesh greybox node in a level `.tscn`, batch-source/verify the `.glb` models and tileable surface textures through the asset-advisor loop, swap each node 1:1 in place preserving its name + position + rotation + collision, validate, then delete the greybox nodes LAST (never first), re-bake the navmesh, and decorate after the walls land. Use for "replace the greybox", "swap blockout for real assets", "retire the placeholder boxes", "migrate the level to final art", "the level is greyboxed, make it look real", or when an arena full of flat BoxMesh cover must become sourced models/textures. Owns the migration ORDER + safety + shared-material building-set; DELEGATES the per-node swap to godot-mesh-import-pixel-art (props) / godot-texture-import-pixel-art (surfaces) and the sourcing to the asset-advisor loop. NOT a second importer, NOT CSG greyboxing, NOT inherited-scene or make-local swaps, NOT the original blockout build (that is godot-greybox).
---

# godot-greybox-to-asset — retire the blockout (migration craft)

A greybox is a deliberate placeholder; migration is the controlled REPLACE that turns it into final art
**without losing the spatial work**. The whole danger is regression — a swap that moves a wall, drops a
collider, breaks the navmesh, or deletes a placeholder before its replacement exists. So the governing
rule is **swap in place, validate, retire LAST**: every asset goes in keeping the greybox node's name +
`position` + `rotation` + collision, you validate the level still loads/renders/walks, and only THEN do
you delete the greybox nodes — never the other way round. This skill owns the ORDER and the SAFETY; it
does not re-implement importing — it orchestrates the skills that already do.

## Requirements

- `godot-greybox` — the level being migrated was built by it (BoxMesh cover, SpawnMarker3D, FallZone,
  baked NavigationRegion3D). This skill consumes that blockout; it does not author shape.
- `godot-mesh-import-pixel-art` — owns the per-node prop swap (scale near-uniform, nested `.glb`
  instance, collider, NEAREST/material). This skill calls it once per discrete prop/cover node.
- `godot-texture-import-pixel-art` — owns large flat surfaces (wall/floor/ground): a `StandardMaterial3D`
  with `uv1_scale` + Texture Repeat on the existing BoxMesh, NOT a model. This skill calls it per surface.
- asset-advisor classify/verify loop — sources + verifies the batch of `.glb` / textures BEFORE any swap.
- `godot-verify` — the load/render/smoke gate run AFTER swaps and AGAIN after the greybox deletion;
  also the `position`+`rotation` (never raw `Transform3D` literal) authoring contract is preserved.
- `godot-code-rules` — strict typed GDScript for any glue (there should be little; this is scene edits).

## Project conventions

- Migrate ONE level `.tscn` (`levels/<name>.tscn`) at a time; never batch across levels in one pass.
- Art-kind → technique (decide per greybox node BEFORE sourcing, from the CLAUDE.md table):
  - **discrete prop / cover piece / furniture** → sourced low-poly `.glb` (`assets/models/<name>.glb`),
    instanced in place of the BoxMesh node — `godot-mesh-import-pixel-art`.
  - **large flat surface** (perimeter wall, floor, ground) → tileable texture on the EXISTING BoxMesh
    via `StandardMaterial3D` + `uv1_scale` + Texture Repeat — `godot-texture-import-pixel-art`. Keep the
    box; re-skin it. Do NOT replace a wall with a wall-shaped model.
  - **modular wall kit** (directional panel geometry from a `.glb` kit) → **per-edge placement path**
    (see below). Wall cells from a grid greybox → this path, NOT the 1:1 box-swap and NOT the
    texture-on-box surface path. Floors/ground still use texture-on-box or floor-tile-instance; discrete
    props still use 1:1 swap.
- **Preserve the spatial contract.** A swap keeps the greybox node's PascalCase name, `position`,
  `rotation`, and a collider of equivalent footprint. The nine spatial principles godot-greybox authored
  (topology/cover/sightlines/verticality/landmarks) must read IDENTICALLY after migration — migration is
  re-skinning, not re-shaping. If an asset is a different size, scale it to the cell, do not move the cell.
- **Shared-material building set.** Source wall/floor/structural pieces as a coherent set sharing ONE
  material/texture family so the arena reads as one place, not a kitbash — pick the set in the asset
  request, not piecemeal per node.
- **One build path.** If the greybox was placed by a builder (`tools/build_*.gd` / a GridMap), extend
  that builder's swap, do NOT fork a second importer.
- `assets/` is gitignored; models → `assets/models/`, textures → `assets/textures/` (snake_case).

## Steps (prop/surface path)

1. **Inventory the greybox.** Open `levels/<name>.tscn`. List every placeholder node: BoxMesh cover/
   props vs BoxMesh perimeter/floor surfaces. Tag each by technique (prop `.glb` vs surface texture vs
   modular wall kit). Leave SpawnMarker3D / FallZone / NavigationRegion3D / lights ALONE — they are
   systems, not art.
2. **Source + verify the batch (asset-advisor).** File one asset request for the whole set: the
   shared-material building pieces + the props + the surface textures. Let the asset-advisor classify/
   verify loop land verified `.glb`/PNG in `assets/`. Do NOT start swapping until the batch verifies.
   (No real asset yet? `tools/gen_models.gd` / `tools/gen_textures.gd` placeholders are fine to swap
   onto FIRST — they still de-box the scene — and re-swapped when sourced art arrives.)
3. **Swap each node IN PLACE — greybox stays until validated.** Per node, delegate the mechanics:
   - prop/cover → `godot-mesh-import-pixel-art` (nest the `.glb` under the owned node; keep name +
     `position` + `rotation`; scale near-uniform to the cell; unique collider sized to AABB).
   - surface → `godot-texture-import-pixel-art` (apply `StandardMaterial3D` + `uv1_scale` + Repeat to
     the EXISTING BoxMesh; keep the box).
   Do the swaps with the greybox content still present as a fallback — do NOT delete any greybox node yet.
4. **Validate the swapped scene.** `tools/validate.sh` then
   `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/<name>.tscn main.tscn`.
   F5: every piece renders as its asset (no flat box, no box-AND-model double), right size, on the floor,
   colliders solid. The arena shape reads the same as the blockout.
5. **Retire the greybox LAST.** Only after step 4 is green: delete the now-redundant placeholder
   `MeshInstance3D`/holder nodes that were fully replaced (a re-skinned surface keeps its box — nothing
   to delete there). Re-run validate + verify_scene. (Optional editor convenience while iterating: lock
   + a transparent-magenta `surface_material_override` on a not-yet-swapped greybox so it reads as
   "TODO" — purely visual, not the mechanism.)
6. **Re-bake nav + decorate.** Re-bake the `NavigationRegion3D` over the final geometry (new colliders
   may shift the walkable area). THEN add non-blocking decoration (set-dressing props, detail) — last,
   after the walls land, so it never blocks the structural migration.
7. Hand off to godot-verify for the final gate.

---

## Modular wall-kit path (per-edge placement)

Use this path when wall cells from a grid greybox are replaced by a **directional panel kit** (separate
`.glb` pieces for wall segments and corners). A wall kit is NOT a texture on a box and NOT a 1:1 swap of
one box for one model — it is directional geometry placed on **cell edges**, not cell volumes.

`build_iron_floor.gd` already gets the orientation logic right (neighbour-derived `is_z_run`, 90° Y-rotation
for Z-runs, orientation-matched thin collision `0.1×6×2` vs `2×6×0.1`, 0.5 scale). The path below upgrades
that to the robust algorithm and adds the missing corner-piece pass.

### Step 0 — Pre-flight kit inspection (mandatory before placing anything)

Headless-measure every GLB piece before committing to placement math. For each kit `.glb`:

```gdscript
var ps: PackedScene = load("res://assets/models/kit_wall.glb") as PackedScene
var inst: Node3D = ps.instantiate() as Node3D
for child in inst.get_children():
    if child is MeshInstance3D:
        var mi := child as MeshInstance3D
        print("AABB: ", mi.mesh.get_aabb())            # → native size in local space
        print("global origin: ", mi.global_position)   # confirm center vs edge
        for s in range(mi.get_surface_override_material_count()):
            var mat := mi.mesh.surface_get_material(s)
            if mat is StandardMaterial3D:
                print("surface %d cull_mode: %d" % [s, (mat as StandardMaterial3D).cull_mode])
```

Record for each piece:
- **AABB size** → derive `scale = cell_size / native_width` (uniform; apply to WALLS and CORNERS so legs align).
- **Origin** → is it center-bottom (good for floor seating)? Off-center? Compute a `position_offset` to
  recenter over the body origin via `get_aabb().get_center()` if needed.
- **`cull_mode` per surface** → `0 = CULL_BACK` (single-sided); `2 = CULL_DISABLED` (double-sided).

**Verified facts for the Sci Fi Wall kit (Godot 4.6, this game):**

| Piece | AABB (m) | Origin | Native width | cull_mode |
|---|---|---|---|---|
| `Sci Fi Wall 3.glb` | 4.0 × 6.0 × 0.55 | center-bottom, face spans X −2..+2, thin at z≈−1.8 | 4 m | 0 = Back (single-sided) |
| `Sci Fi Wall Corner 3.glb` | 4.05 × 6.0 × 4.05 | L-shape, two 4 m legs in X and Z | 4 m legs | 0 = Back |
| `Sci Fi Floor Tile.glb` | 4.0 × 0.1 × 4.0 | dead-center (0,0,0) | 4 m | 0 = Back |

Cell = 2 m, native = 4 m → `scale = 0.5` uniform. Corner legs are also 4 m → SAME 0.5 scale; legs align
with wall segments automatically.

### Step 1 — cull_mode = Back contract (single-sided walls)

`cull_mode = CULL_BACK` means the **front face must point to the playable/open side**. Placing a
single-sided panel facing the wrong way makes it invisible from the inside — the panel exists, no error,
the player sees nothing. This is the exact failure mode that occurred with wall.glb.

**Rule:** when placing a wall segment on an edge, the model's +Z (front face) must face the open/floor
neighbour, not the wall interior.

For a panel sitting on the NORTH edge of a wall cell, the open side is north (−Z in world). Rotate the
model so it faces −Z. Concretely:

- Edge faces SOUTH (open side is +Z world): `rotation_degrees.y = 0`
- Edge faces NORTH (open side is −Z world): `rotation_degrees.y = 180`
- Edge faces EAST  (open side is +X world): `rotation_degrees.y = 90`
- Edge faces WEST  (open side is −X world): `rotation_degrees.y = 270`

**Double-sided alternative:** set `cull_mode = CULL_DISABLED` on every surface of the wall material
(`StandardMaterial3D` → Cull Mode → Disabled, or `get_surface_override_material(s).cull_mode =
BaseMaterial3D.CULL_DISABLED` in code). Trades draw-call cost for zero facing risk — valid for interior
partitions visible from both sides.

### Step 2 — Per-edge placement (not per-cell)

The per-cell approach (`build_iron_floor.gd`'s `is_z_run` default) mishandles T-junctions, single-cell
nubs, and room corners where a cell has neighbours on two axes. The robust algorithm:

**For each wall cell `(col, row)`, for each of the 4 cardinal neighbours (N/S/E/W):**
- If the neighbour is floor, door, or out-of-bounds → **place one wall segment on that edge**, oriented
  to face the opening.
- If the neighbour is also a wall → **skip** (a shared wall-wall edge needs no segment; placing one would
  double the geometry and block the view from the adjacent wall cell).

Position of a wall segment on the SOUTH edge of cell `(col, row)` (open side at +Z):

```gdscript
var edge_pos := Vector3(
    col * CELL_SIZE + CELL_SIZE * 0.5,   # cell center X
    0.0,                                  # floor-seated
    row * CELL_SIZE + CELL_SIZE           # south edge Z
)
```

Each segment gets its own `StaticBody3D` → `CollisionShape3D` → thin `BoxShape3D` + the `.glb` instance
as a child. Never one fat `2×6×2` box per cell — that blocks every edge simultaneously and walk-through
gaps appear at perpendicular walls.

**Orientation-matched thin collision (carry forward from `build_iron_floor.gd`):**

```gdscript
# N/S edge (panel spans X, thin in Z):
shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, 0.1)
# E/W edge (panel spans Z, thin in X):
shape.size = Vector3(0.1, WALL_HEIGHT, CELL_SIZE)
```

Slight oversize (e.g. 0.12 instead of 0.1) prevents squeeze-through at seams.

### Step 3 — Corner-piece pass (2×2 marching-squares)

After all edge segments are placed, classify each 2×2 vertex of the grid to fill corner gaps. A corner
vertex at grid-point `(c, r)` (between cells `(c-1,r-1)`, `(c,r-1)`, `(c-1,r)`, `(c,r)`) counts the
number of wall cells among those four:

| Wall-cell count | Corner type | Action |
|---|---|---|
| 1 | Convex / outer corner | Place corner GLB at the vertex position, oriented so the L opens toward the single wall cell |
| 3 | Concave / inner corner | Place corner GLB rotated 180° — L closes into the wall mass |
| 2 adjacent (same edge) | Straight run | Wall segments from step 2 already cover it — skip |
| 2 diagonal | Kit-specific gap | No standard L-corner fits; accept the visual gap or drop a second wall segment |
| 0 or 4 | Open space / solid mass | Skip |

Corner position:

```gdscript
var corner_pos := Vector3(c * CELL_SIZE, 0.0, r * CELL_SIZE)  # exact grid vertex
```

Corner GLB scale = same uniform 0.5 (two 4 m legs → 2 m legs at scale 0.5, matching wall segments).

### Step 4 — Door cells (passable frame)

Door cells should NOT use a full `2×6×2` collision — that blocks the opening. Two options:

- **Door-frame GLB** (preferred): a model with a visible frame and NO solid interior. Collision = two
  thin `BoxShape3D` pillar shapes flanking the opening, NOT a solid box.
- **No collision on the opening axis** (interim): place wall segments only on the two non-door edges of
  the door cell; leave the open edges with no segment (player can walk through).

`build_iron_floor.gd` currently uses a full `2×6×2` box for doors — this blocks the opening. Rework when
a door-frame GLB is available; for now document it as a known gap (`# FIXME(agent): door uses solid
collision — rework when door-frame GLB sourced`).

### Pre-flight gotcha checklist (wall kit)

- [ ] Measured each piece AABB, origin, cull_mode headless before starting placement
- [ ] `scale = cell_size / native_width` (uniform); same scale for wall AND corner segments
- [ ] cull=Back panels: front face verified to point toward playable side after rotation
- [ ] Segments placed per-edge (not per-cell); wall-wall shared edges skipped
- [ ] Thin collision per segment orientation; slight oversize (~0.12 m) at seams
- [ ] Corner-piece pass run after wall segments; convex/concave classified
- [ ] Door cells: non-blocking collision or door-frame GLB (no solid `2×6×2` box)
- [ ] All positions/rotations authored via `position` + `rotation_degrees` — no `Transform3D` literal
- [ ] GLB origin offset confirmed (model base at local y=0 for floor-seating; if off-center,
  recenter via `inst.position = -mesh.get_aabb().get_center()` before placing)

---

## Verification checklist

- [ ] Every greybox node inventoried and tagged prop-`.glb` vs surface-texture vs modular-wall-kit before sourcing
- [ ] Batch sourced + verified by asset-advisor (or local gen placeholders) BEFORE swapping
- [ ] Each swapped node keeps its original **name + position + rotation**
- [ ] Props are **nested `.glb` instances** (not make-local, not inherited scene) with a unique collider
- [ ] Surfaces re-skin the EXISTING BoxMesh (texture + `uv1_scale` + Repeat) — box kept, not replaced
- [ ] Wall-kit cells use per-edge placement + corner-piece pass (not 1:1 box swap)
- [ ] Wall/floor/structural pieces share ONE material family (reads as one place)
- [ ] Greybox placeholder nodes deleted **only after** the swapped scene passed validate + verify_scene
- [ ] No box-AND-model doubles; no floating/sunk/crushed props
- [ ] Arena's spatial read (cover, sightlines, verticality, landmarks) unchanged vs the blockout
- [ ] `NavigationRegion3D` re-baked over final geometry; enemies still path
- [ ] No raw `Transform3D` literals introduced (godot-verify)
- [ ] One build path (builder extended, not forked); decoration added LAST
- [ ] `tools/validate.sh` passes; `verify_scene.gd` prints `VERIFY: OK`

## Error → Fix

| Symptom | Fix |
| --- | --- |
| Box AND model both visible | Greybox `MeshInstance3D` content not replaced — swap content keeping name/position; delete the box only in step 5 |
| A wall moved / cover shifted after swap | Asset scaled the cell instead of fitting it — re-seat to the greybox `position`/`rotation`; scale the asset to the cell, never move the cell |
| Placeholder deleted, replacement missing | Greybox retired before validation — restore from VCS; ALWAYS swap+validate, delete LAST (step 5) |
| Enemies stop pathing / walk through new walls | Navmesh stale — re-bake `NavigationRegion3D` over final geometry (step 6) |
| Wall replaced by a wall-shaped model, looks off | Large flat surface should be a texture on the BoxMesh, not a model — use godot-texture-import-pixel-art |
| Arena reads as a kitbash | Structural pieces don't share a material — re-source the building set with ONE shared material family |
| Second importer / build script appeared | Fork — extend the existing builder/swap, one build path |
| Prop giant/speck/floating/crushed | Per-node scale/seat issue — see godot-mesh-import-pixel-art Error→Fix (near-uniform Root Scale, AABB to y0) |
| Build fails godot-verify Transform3D ban | Author swaps via `position`+`rotation`, never a `Transform3D` literal |
| Wall panel invisible from inside | cull=Back panel facing wrong way — front face must point to playable/open side; rotate 180° or set cull_mode=CULL_DISABLED |
| Wall-wall shared edge has double panel / gap | Using per-cell instead of per-edge — skip placing on edges where both sides are wall cells |
| Corner gap at room convex/concave turns | Corner-piece pass not run — classify 2×2 vertex, place L-corner GLB at convex (1 wall) and concave (3 wall) vertices |
| Door blocks the opening | Door uses solid `2×6×2` collision — use pillar-only collision flanking the opening, or source a door-frame GLB |
| Wall segments float or sink | GLB origin not at y=0 base — recenter: `inst.position = -mesh.get_aabb().get_center()` with y clamped to 0 |
| Corner legs don't align with wall segments | Corner GLB at different scale than wall — derive both from `cell_size / native_width`; for this kit: 0.5 uniform |

---

For a Resource-driven arena assembled at RUNTIME, see `godot-runtime-arena` (not this). The per-node
import mechanics live in `godot-mesh-import-pixel-art` / `godot-texture-import-pixel-art`; sourcing lives
in the asset-advisor loop — this skill only orchestrates the migration order + safety over them.

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
