# Main Scene (entry point + level loading)

**Goal** — Pressing F5 launches the game into a thin `Main` scene that loads `basic_room` under a container and shows the room (no more launching the level directly).

**Scope (in)**
- New scene `res://scenes/main/main.tscn`, root `Main` (Node), flat structure `Main → LevelHost` (LevelHost is a plain `Node` with `unique_name_in_owner = true`). No SubViewport, no camera, no UI this slice.
- New script `res://scenes/main/main.gd` attached to `Main`, exactly the shape in the godot-main-scene skill:
  - `@export_file("*.tscn") var initial_level: String = "res://levels/basic_room.tscn"`
  - `_ready()` calls `load_level(initial_level)`.
  - `load_level(path)` frees the current level with `free()` (not `queue_free()`), instantiates the new one, and adds it under `%LevelHost`.
- Set `run/main_scene="res://scenes/main/main.tscn"` under `[application]` in `project.godot`.
- Record the new conventions in CLAUDE.md `## Project conventions` (entry point path; levels load under `Main/LevelHost`; never `change_scene_to_file()`; `free()` not `queue_free()` on swap; LevelHost migrates inside the SubViewport when godot-3d-pixelation runs).

**Scope (out)**
- SubViewport pixelation rig — not built yet; Main stays flat per the skill (own slice: godot-3d-pixelation).
- Camera rig in Main — Main owns no camera yet, so basic_room's in-scene camera stays current; no `make_current()` call needed this slice (own slice: godot-camera-rig).
- UI / CanvasLayer — no UI exists; the skill says omit it until there is (own slice).
- A second level / actual level switching — only the initial load is needed now; `load_level()` is written to support swaps but isn't exercised with a second scene this slice.
- Autoloads, loading screens, async/threaded loading, transitions — explicitly parked by the skill's scope boundary.

**Acceptance**
- `GODOT=/Applications/Godot.app/Contents/MacOS/Godot` then `$GODOT --headless --path . --script tools/verify_scene.gd -- scenes/main/main.tscn levels/basic_room.tscn` prints `VERIFY: OK` (no `VERIFY-FAIL` lines, exit 0).
- Smoke run with main scene now set: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"` finds nothing (this proves `run/main_scene` is wired and `_ready` → `load_level` runs clean).
- In the editor, F5 (not F6) launches `Main` and the basic room appears, lit, framed by basic_room's own orthographic camera — same view as launching the level directly, but now via Main.
- The scene tree at runtime is `Main → LevelHost → BasicRoom`.

**Skill notes**
- `godot-main-scene`: this slice is the "pixelation rig doesn't exist yet" path — build `Main → LevelHost` flat, note in CLAUDE.md that LevelHost moves inside the SubViewport later. Use `free()` (synchronous) on swap; never `change_scene_to_file()`. Set `unique_name_in_owner` on LevelHost so `%LevelHost` resolves.
- `godot-main-scene` (cameras): "exactly one current Camera3D per viewport." Since Main ships no camera, basic_room's camera remains the single current one — correct for now. When godot-camera-rig lands, the level-local camera gets deleted and Main's camera takes over.
- `godot-verify`: mandatory; run layer 1 on both scenes and layer 2 (smoke run) since the main scene is now set. Use plain `grep` in the pipe, not `rtk grep`.

**Later**
- Move `LevelHost` inside a `SubViewportContainer → SubViewport` (godot-3d-pixelation).
- Add a persistent `CameraRig` under the SubViewport; delete basic_room's in-scene camera; Main makes its camera current after loading (godot-camera-rig).
- Add a `UI` CanvasLayer under Main once there's HUD/menu content.
- Add a second level and exercise `load_level()` swapping (verify no doubled geometry / no two-current-cameras flicker).
- Introduce autoload(s) for state that outlives level swaps (score, run progress).

**Open questions** — none.
