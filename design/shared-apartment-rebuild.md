# Shared Apartment — Clean Rebuild Plan (2026-06-14)

**Goal** — Regenerate `levels/shared_apartment.tscn` from scratch so the player can walk the full greybox apartment AND the master bedroom reads as a textured pixel-art room — restoring the state described by Slices 1–3 after the scene file was lost from disk.

## Context (why this exists)
`levels/shared_apartment.tscn` no longer exists on disk (only `.godot/editor/` cache). The committed assets that survive — builder `tools/build_shared_apartment.gd`, MeshLibrary `resources/apartment_tiles.meshlib.tres`, grid `levels/drawn/current.json` — are enough to regenerate it. User intent (confirmed 2026-06-14): rebuild fresh **through all three slices**; grid unchanged; `apt_flat_a/b` are dead references (ignore); no new scope.

## Key re-scope: 3 docs → 2 dispatches
Slices 1 and 2 are **already one builder run** — `_build()` calls `_place_props()`, emitting shell + 5 master-bedroom props in a single headless pass. They do NOT need separate dispatches. So the rebuild is **two** godot-dev tasks, sequenced.

---

## Dispatch A — Regenerate shell + master props (Slices 1 + 2)
**Build method:** run the existing builder; do NOT hand-author the `.tscn`.
```
$GODOT --headless --path . --script tools/build_shared_apartment.gd
```
This reads `current.json`, builds the GridMap (walls/windows per zone colour), floor slab, sun + WorldEnvironment, Player spawn, and the five flat-greybox master-bedroom props, then saves `res://levels/shared_apartment.tscn`.

**Scope (in)**
- Run the builder; confirm it saves the scene with non-empty GridMap cells + the 5 named prop nodes.
- `tools/validate.sh` passes on `tools/build_shared_apartment.gd` (it is committed, but re-gate it).
- `godot-verify` 3-layer check on `levels/shared_apartment.tscn`.

**Scope (out)**
- Any texturing — that is Dispatch B.
- Editing the builder logic, MeshLibrary, or grid — all unchanged; this is a regeneration, not a redesign.
- `main.gd` already lists `shared_apartment.tscn` — no registration change needed.

**Acceptance** (from Slices 1 & 2):
- `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/shared_apartment.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run finds no `SCRIPT ERROR|ERROR`.
- GridMap: MeshLibrary assigned, `get_used_cells()` non-empty, `cell_size == Vector3(1.5,3,1.5)`, cells baked into the `.tscn`.
- F5: walk the full apartment — every room reachable through door gaps, corridor reads open vs. tighter bedrooms, each zone's walls a distinct colour, windows line the top edge, every wall has a collider. Master bedroom shows 5 flat-grey props (bed, wardrobe, nightstand, chair, desk) on the floor, inside the walls.

---

## Dispatch B — Master bedroom textures (Slice 3) + import-drift fix
**Run only after Dispatch A verifies.** On a fresh builder run ALL five props are flat albedo (including BedMaster — the old scene's bed texture was a hand-edit that did not survive). So this dispatch textures FOUR props, not three.

**Scope (in)**
- Fix the import sidecar FIRST: `assets/textures/desk_wood.png.import` must be `compress/mode=0` and `mipmaps/generate=false` (currently `2` / `true` — drift). Reimport. Same check for `bed_fabric.png.import`.
- Re-wire four master-bedroom prop materials in `levels/shared_apartment.tscn` from flat `albedo_color` to `albedo_texture`, `texture_filter = 1` (NEAREST — the trap is `3`), `albedo_color` left white:
  - **Wardrobe**, **NightstandMaster**, **DeskMaster** → `desk_wood.png`.
  - **BedMaster** → `bed_fabric.png` (re-apply — it is flat after the rebuild).
- **ChairMaster** stays flat Color(0.45,0.45,0.50) — no upholstery texture on disk; deliberate observable boundary.

**Scope (out)**
- Per-face / strip UVs, texel-density tuning — parked (Slice 3 Later).
- New textures `wood_2/wood_3/wood_seamless_sprite` — not used; user confirmed no scope change.
- Walls/floor/other-room textures — separate future slices.

**Acceptance** (from Slice 3, amended for the bed):
- `verify_scene.gd` prints `VERIFY: OK`; smoke run clean.
- In the saved `.tscn`: Wardrobe, NightstandMaster, DeskMaster materials reference `desk_wood.png`; BedMaster references `bed_fabric.png`; each `texture_filter = 1` (not `3`).
- F5 in the master bedroom: wardrobe, nightstand, desk show crisp wood-grain pixel art; bed shows its bedding; texels blocky at SubViewport scale (no blur, no moiré — proves NEAREST + no-mipmap). Chair remains a flat grey-blue box (expected).

---

## Skill notes
- `godot-gridmap-level` (Dispatch A) — the build method; builder + MeshLibrary already author the tiles. Do not hand-author Transform3D walls.
- `godot-texture-import-pixel-art` (Dispatch B) — `texture_filter = 1`, `.import` `mipmaps/generate=false` + `compress/mode=0`; the `=3` filter trap and the gitignored-sidecar regeneration are the live risks.
- `godot-code-rules` — load before touching the builder; `tools/validate.sh` gate.
- `godot-verify` — mandatory after each dispatch.

## Later (unchanged from the source slices)
- Chair upholstery texture (asset-sourcing loop) → texture ChairMaster.
- Per-face / strip UVs + texel density on the textured props.
- Remaining room prop slices: kitchen/living, bathroom, twin bedroom.
- Wall/floor tiled textures; bathroom floor-tile override + raised step; door-frame meshes; window-tile fidelity (glass pane + floor-seat offset — see `design/levels/shared_apartment.md` Later).
- Per-tenant bedroom personality; functional doors; exterior skybox view; prop collision.

## Open questions / flags for the orchestrator
- **Dead refs:** `main.gd._levels` lists `res://levels/apt_flat_a.tscn` and `res://levels/apt_flat_b.tscn`, which do not exist on disk. User confirmed they are dead. Not part of this rebuild — flag for a separate cleanup task (a one-line `main.gd` edit via godot-dev) so the level list does not point at missing files.
