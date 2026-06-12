# Level Blockout 2 — Arena Two

**Goal** — Second blockout arena: 20×20 floor, four walls, three platforms (low + mid + high), walkable and fully collidable.

Follows `design/level-blockout.md` (shared recipe). Build after level 1 passes.

**Scope (in)**
- Scene `res://levels/blockout_02.tscn`, root `Blockout02` (Node3D).
- Three platforms, spread to read as a stepped layout:
  - `Platform1` — Low tier (height 0.5), footprint 4×4, at `position = Vector3(-6, 0.25, 0)`.
  - `Platform2` — Mid tier (height 1.5), footprint 4×4, at `position = Vector3(0, 0.75, 0)`.
  - `Platform3` — High tier (height 3.0), footprint 4×4, at `position = Vector3(6, 1.5, 0)`.
- Spawn `Player` at `position = Vector3(0, 1, -6)` (clear of the platform row).
- Distinct albedo: floor, walls, and one color per platform tier (low/mid/high) — five readable colors.

**Acceptance** — per the shared recipe, with `<snake_name> = blockout_02`. Confirm the three platforms ascend low → mid → high left to right in the F5 view.

**Open questions** — none.
