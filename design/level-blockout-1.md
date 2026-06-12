# Level Blockout 1 — Arena One

**Goal** — First blockout arena: 20×20 floor, four walls, two platforms (low + high), walkable and fully collidable.

Follows `design/level-blockout.md` (shared recipe). This doc states only what differs. **Build this level first — it proves the recipe.**

**Scope (in)**
- Scene `res://levels/blockout_01.tscn`, root `Blockout01` (Node3D).
- Two platforms:
  - `Platform1` — Low tier (height 0.5), footprint 5×5, at `position = Vector3(-5, 0.25, -5)`.
  - `Platform2` — High tier (height 3.0), footprint 3×3, at `position = Vector3(5, 1.5, 5)`.
- Spawn `Player` at `position = Vector3(0, 1, 0)` (center, clear of both platforms).
- Distinct albedo: floor, walls, low platform, high platform — four readable colors.

**Acceptance** — per the shared recipe, with `<snake_name> = blockout_01`. Confirm both platforms are distinct heights and the high one is clearly taller than the low one in the F5 view.

**Open questions** — none.
