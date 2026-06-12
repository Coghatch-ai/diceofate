# Level Blockout 3 — Arena Three

**Goal** — Third blockout arena: 20×20 floor, four walls, two platforms (mid + mid, offset), walkable and fully collidable.

Follows `design/level-blockout.md` (shared recipe). Build after level 2 passes.

**Scope (in)**
- Scene `res://levels/blockout_03.tscn`, root `Blockout03` (Node3D).
- Two platforms at the same mid tier but different footprints, placed in opposite corners to make a different silhouette from levels 1–2:
  - `Platform1` — Mid tier (height 1.5), footprint 5×5, at `position = Vector3(-5.5, 0.75, 5.5)`.
  - `Platform2` — Mid tier (height 1.5), footprint 3×3, at `position = Vector3(5.5, 0.75, -5.5)`.
- Spawn `Player` at `position = Vector3(0, 1, 0)` (center, between the two corner platforms).
- Distinct albedo: floor, walls, and the two mid platforms (give them two different colors so they're separable). Four readable colors.

**Acceptance** — per the shared recipe, with `<snake_name> = blockout_03`. Confirm two same-height platforms sit in opposite corners and the player can walk the open diagonal between them.

**Open questions** — none.
