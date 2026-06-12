# Level Blockout — Shared Recipe

**Goal** — Three standalone blockout arenas you can walk around in: a flat 20×20 floor, four perimeter walls, and 2–3 raised platforms, everything solid. Each level is one godot-dev pass and one F5 look.

This is the **shared recipe**. The three per-level slices (`level-blockout-1.md`, `-2.md`, `-3.md`) only state what differs. Build level 1 first; it proves the recipe, then 2 and 3 are near-copies.

---

## The recipe (applies to every blockout level)

- New scene `res://levels/<snake_name>.tscn`, root `<PascalName>` (Node3D).
- **Floor** — `StaticBody3D` (Pattern A from `design/collision-shapes.md`) with child `MeshInstance3D` (BoxMesh `size = Vector3(20, 0.2, 20)`) and `CollisionShape3D` (BoxShape3D, same size). Top surface at y=0: place body at `position = Vector3(0, -0.1, 0)`.
- **Four perimeter walls** — `WallNorth/South/East/West`, each Pattern-A `StaticBody3D` + BoxMesh + matching BoxShape3D. Wall span 20, height 3, thickness 0.4. North/South at z=±10, East/West at x=±10 (rotate 90° on Y), centered at y=1.5. Walls sit flush on the floor edge, fully closing the arena.
- **2–3 platforms** — each a Pattern-A `StaticBody3D` (`Platform1`, `Platform2`, …) with BoxMesh + matching BoxShape3D. Use the fixed height tiers below. Place inside the floor, not overlapping walls. Box `position.y = height / 2` so the platform rests on the floor.
- **Distinct flat StandardMaterial3D albedo colors** per group (floor / walls / each platform tier) so elements read apart under the ortho camera. No textures.
- **Lighting + environment** — one `DirectionalLight3D` (e.g. `rotation_degrees = Vector3(-45, -30, 0)`, `shadow_enabled = true`) and one `WorldEnvironment` with a ProceduralSkyMaterial-based Sky (Sky resource required by godot-verify hand-authoring rules).
- **Player** — one `Player` instance (`res://entities/player/player.tscn`) named exactly `Player`, placed on the floor at a clear spawn (`position = Vector3(0, 1, 0)` or similar). main.gd's `find_child("Player")` auto-wires it to the camera rig.
- **No camera in the level.** Main owns the persistent `CameraRig`; a level-local camera would create two current cameras. (basic_room's in-scene camera was already removed for this reason.)

### Platform height tiers (pick 2–3 per level)
| Tier | Height (y-size) | Reads as |
|------|-----------------|----------|
| Low  | 0.5 | step / ledge |
| Mid  | 1.5 | table / cover |
| High | 3.0 | tower / vantage |

Platform footprint (x,z) is the designer's call per level (suggest 3×3 to 5×5); keep it clear of walls and the spawn point.

---

**Scope (out, all levels)**
- Runtime level switching / a level-select UI — main.gd loads only `initial_level`; viewing each level = set `initial_level` to that path (or call `load_level()` from the remote inspector). A switcher is its own slice.
- Ramps / stairs / reachable platforms by jumping logic tuning — platforms are blockout geometry; whether the player can climb them is not a goal of this slice.
- Textures, real meshes, decoration, theming beyond albedo color — placeholders only.
- Post-process / outlines, NPCs, interactables, pickups — not requested.
- Physics layers/masks — default layer 1 (per collision-shapes.md POC default).

**Acceptance (per level, run for each)**
- `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
- Layer 1: `$GODOT --headless --path . --script tools/verify_scene.gd -- levels/<snake_name>.tscn` prints `VERIFY: OK` (no `VERIFY-FAIL`, exit 0).
- Layer 2 (smoke): temporarily set `initial_level` to this level, `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"` finds nothing.
- Human F5: set `initial_level` to this level, press F5 (launches Main). Player spawns; arena is lit, pixelated through the SubViewport, framed by the ortho rig with parallel wall edges (no vanishing point). Walking the Player into each wall and each platform side **blocks** (collision works); the player cannot leave the arena or pass through a platform.

**Skill notes**
- `design/collision-shapes.md` — Pattern A (StaticBody3D as parent), BoxShape3D size == BoxMesh size, exactly. Default StaticBody3D for all geometry.
- `godot-main-scene` — levels load under `Main/LevelHost`; never `change_scene_to_file()`. Level carries no camera; Player must be named `Player` for auto-wiring.
- `godot-camera-rig` — camera is Main's, orthographic fixed angle; do not add one to the level.
- `godot-verify` — mandatory; hand-authoring rules: use `position`/`rotation_degrees`/`size` only, NEVER `transform = Transform3D(...)`; WorldEnvironment needs a real Sky resource.
- Conventions — nodes PascalCase, file snake_case under `levels/`; Forward+ renderer (already set).

**Later**
- A level-select / switcher (UI or input action) that calls `main.gd load_level()` to cycle the three blockouts at runtime.
- Ramps/stairs so all platform tiers are reachable on foot.
- Per-level theming (sky tint, light color, material palette) once blockouts are validated.
- Swap box placeholders for real low-poly meshes.

**Open questions** — none.
