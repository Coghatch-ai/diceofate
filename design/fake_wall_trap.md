# Fake-Wall Fall-Through Trap

**Goal** — Some perimeter wall segments look identical to the real arena walls but have no collision, so a player who trusts one walks through it, drops through a hole in the floor into the void, and respawns at the spawn point a moment later.

## Build method
Extend the existing headless builder `scripts/build_firing_yard.gd` (`@tool extends SceneTree`,
skill `godot-gridmap-level`) and re-run it to regenerate `levels/firing_yard.tscn`. The fake walls,
the floor holes, and the fall-detect trigger are all baked there — never hand-author `.tscn` walls.
The respawn behaviour is a small new `Area3D` + signal handled on the level root (`levels/firing_yard.gd`).

**Grid → world contract (unchanged):** cell `(col,row)` → `Vector3(col*2, y, row*2)`;
`CELL_SIZE = Vector3(2, 4, 2)`. The 24 fake-wall cells are the `items` id-3 entries in
`levels/drawn/current.json` (all on the perimeter: top row 0, left col 0, right col 23, bottom row 15).
Spawn is `Vector3(24, 1.0, 30)`, facing −Z (`SPAWN_ROT_Y = 180`).

## Scope (in)
- **Fake-wall blocks (id-3, all 24 cells):** for every id-3 item cell, place a `MeshInstance3D`
  that is a solid 2×4×2 `BoxMesh` with the **exact same** `WALL_COLOR` (`#404050`) material as a
  real GridMap wall — visually identical, no tell. **No collision** (plain `MeshInstance3D`, not a
  body). Replaces the removed pale-grey id-3 markers from B1b.
- **Floor holes under fake walls:** the floor must NOT be a single 48×32 slab anymore where fake
  walls sit. Open a gap at each id-3 cell so there is nothing to stand on beyond/through the fake
  wall. Cheapest robust approach: rebuild the floor as a small set of `StaticBody3D` slabs that
  cover the playable interior but **leave the id-3 cells (and the one-cell strip just outside each,
  off-grid) open**, OR keep one slab and subtract per-cell holes — builder's choice as long as
  stepping through a fake wall lands the player over open void, not solid floor. Real walls must
  still sit on solid floor.
- **Fall-detect trigger:** one `Area3D` (`FallZone`) with a wide flat `BoxShape3D` placed well below
  the arena (e.g. top at y ≈ −6, spanning past the 48×32 footprint). `monitoring = true`; detects
  the player body (player is `collision_layer = 2`, so the Area's `collision_mask` includes layer 2).
- **Respawn on fall:** `FallZone.body_entered` → handler on `levels/firing_yard.gd` resets the
  player's `global_position` to `SPAWN_POS` (`Vector3(24, 1.0, 30)`), zeroes `velocity`, and restores
  `rotation.y` to face −Z. A brief fall is visible before the reset (the Area being below the arena
  gives the player ~1 s of drop). No health, no UI, no death screen.

## Scope (out)
- Health / damage / lives — the fall just resets position; not a death system.
- A lower area or second floor to climb back from — would add a whole level tier; respawn instead.
- Death UI / screen flash / fade — out of POC scope; raw teleport is enough to verify.
- Any visual tell on fakes — confirmed "identical, no tell" (the trap only works if you can't tell).
- Changing which cells are fake — exactly the 24 id-3 cells from the drawn grid; no subset.
- id-1 hazard and id-2 wall-cling mechanics — still Later, unchanged by this slice.

## Acceptance
- Re-run `scripts/build_firing_yard.gd` headless; it regenerates `levels/firing_yard.tscn` with no
  push_error, and the project still loads (no node-name-clash error — see Skill notes).
- F5 lands in Firing Yard as before; real walls still block the player and stand on solid floor.
- The 24 fake-wall segments are **indistinguishable** from real walls by eye (same size, colour).
- Walking into a fake wall: the player passes through it (no collision) AND drops — there is no
  floor to stand on past it.
- After the drop, the player is caught by `FallZone` and reappears at the spawn point facing into
  the arena, able to move/jump/fire again (one human F5 look confirms the gotcha + respawn).
- `tools/validate.sh` passes on the changed `.gd` files.

## Skill notes
- `godot-gridmap-level` — fake walls, floor holes, and the trigger are all baked in the headless
  builder; fake walls are computed-position instances (one per id-3 cell), not GridMap tiles, so
  they can omit collision while real walls keep theirs. Express each fake wall as one cell block at
  the cell centre — never a `×N` count.
- `godot-code-rules` — load before editing `scripts/build_firing_yard.gd` and `levels/firing_yard.gd`;
  strict typed GDScript; pass `tools/validate.sh`. JSON parse already uses the SEAM cast pattern.
- `godot-verify` — mandatory 3-layer gate; plus: scene loads with no node-name clash, GridMap real
  walls intact, fake-wall count == 24, FallZone present, F5 walk-through + respawn observed.
- **Owner gotcha (already burned once, see `_add_targets` line ~441):** when baking, do NOT set
  `owner` on an instanced scene's *internal* children. For freshly-`.new()` nodes you create
  (the fake-wall meshes, FallZone, floor slabs), set `owner = scene_root` as the existing code does;
  the rule only bites on children that come *inside* an instanced PackedScene.

## Later
- A subtle audio/visual cue on respawn (whoosh, fade) — pure polish.
- Make some perimeter segments real walls so the trap is "fair" — design choice, parked.
- Sourced low-poly wall art replacing the greybox blocks (asset-advisor loop) — fakes must keep
  matching the reals.

## Open questions
None — all three forks resolved with the user (fall→respawn-after-brief-void-fall; all 24 id-3
cells identical with no tell; open floor holes under fakes + a fall-detect Area3D).
