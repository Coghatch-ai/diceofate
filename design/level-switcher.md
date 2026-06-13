# Level Switcher

**Goal** — Pressing Tab during play swaps the current arena for the next blockout, so you can tour levels without restarting.

**Scope (in)**
- New input action `cycle_level` bound to Tab (added to `[input]` in `project.godot`).
- A hardcoded ordered level list in `main.gd`: `["res://levels/blockout_01.tscn", "res://levels/blockout_02.tscn"]`.
- An index tracking the current level; `_ready()` sets it from `initial_level` (default 0 if not in the list).
- `_unhandled_input()` (or `_input()`) on Main: when `cycle_level` is pressed, advance the index (wraps with `% size`) and call the existing `load_level()` with the next path.
- Reuses `load_level()` unchanged — it already frees the old level and re-wires the Player to the camera rig.

**Scope (out)**
- blockout_03 — not built yet; listing it would point at a missing file. Add to the list (one line) when it exists.
- On-screen buttons / level-select panel — a UI slice with its own conventions; parks the "easiest" goal.
- Number-key direct jump (1/2/3) — needs more actions/wiring; cycling is enough to tour two levels.
- Player spawn / state carry-over, transitions/fades, level-completion logic — switching is instant and resets the level.

**Acceptance**
- `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
- Layer 1: `$GODOT --headless --path . --script tools/verify_scene.gd -- main.tscn` prints `VERIFY: OK` (exit 0).
- Layer 2 (smoke): `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"` finds nothing.
- Human F5: launch Main (loads blockout_01). Press Tab → arena swaps to blockout_02 (Player respawns at its spawn, camera follows). Press Tab again → wraps back to blockout_01. No flicker of two levels, no orphaned camera, no errors in the Output log.

**Skill notes**
- `godot-main-scene` — switching MUST go through `main.gd`'s `load_level()` under `Main/LevelHost`; never `change_scene_to_file()`. `load_level()` already does `free()` (not `queue_free()`) and re-wires the Player — do not duplicate that logic.
- `godot-code-rules` — load before editing `main.gd`; strict typed GDScript, the new array/index must be typed, run `tools/validate.sh` before reporting.
- `godot-verify` — mandatory after the `main.gd` + `project.godot` change; verify `main.tscn`.
- Conventions — `cycle_level` joins the documented input actions; record it in CLAUDE.md's `## Project conventions` input list as part of this change.

**Later**
- Add `res://levels/blockout_03.tscn` to the list once that level is built (one-line edit).
- Reverse-cycle (Shift+Tab) if touring backward becomes useful.
- On-screen level-select panel once a UI layer exists.

**Open questions** — none.
