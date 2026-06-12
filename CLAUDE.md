# DiceOfFate — Claude Context

POC for a game developer framework using Godot 4.x. The goal is to build small things and observe how agents behave.

## Project layout

```
main.tscn         entry point + main.gd, at project root (skill: godot-main-scene)
design/           design docs — one per agreed slice (written by game-designer only)
entities/         one scene+script per entity, entities/<name>/
levels/           level scenes
shaders/post/     post-process shaders
resources/        .tres resources
tools/            framework tooling (verify_scene.gd) — not game code
.claude/
  agents/         game-designer (Opus), godot-dev (Sonnet) — own context windows
  skills/         godot-* skills, scoped to this project
```

## How to work on this project

Pipeline: idea → **game-designer** (Opus — interviews the user, cuts scope, writes `design/<slug>.md`) → **godot-dev** (Sonnet — implements the doc) → **godot-verify** (3-layer checks) → human **runs** it (F5/F6). The editor viewport is NOT verification — it uses the editor's camera and hides camera/lighting bugs.

Role boundary: the orchestrator (main session) investigates and updates framework documentation only (`.claude/`, CLAUDE.md); ALL changes to game/project files (scenes, scripts, project.godot, tools) go through the agents. When something breaks, the deliverable is the framework fix, not a hand-patched file.

This is a framework/workflow to speed up development — not a vibe-coding tool. Requests that can't be built and verified in one small step go through game-designer first; it is expected to push back on scope. Keep tasks small and discrete.

## Skills (in .claude/skills/)

- `godot-project-conventions` — run FIRST in any new setup; records conventions here in CLAUDE.md
- `godot-main-scene` — Main scene entry point; owns the persistent shell, loads/swaps levels
- `godot-3d-pixelation` — SubViewport low-res render setup
- `godot-camera-rig` — orthographic fixed-angle follow camera
- `godot-postprocess-quad` — fullscreen quad rig for screen-space effects
- `godot-screen-textures` — depth/normal/screen texture reading in shaders
- `godot-verify` — 3-layer verification: property names, smoke run, render check (mandatory after scene/script changes); validators at `tools/verify_scene.gd` + `tools/verify_render.gd`

## Project conventions

- Engine: Godot 4.3+ (reversed-Z). Renderer: Forward+ (required by outline shaders).
- Art style: 3D pixel art. 3D content renders inside a SubViewport (skill: godot-3d-pixelation); post-process effects attach to the camera inside it.
- Camera: orthographic, fixed angle (skill: godot-camera-rig). Do not switch to perspective without flagging the texel-snapping consequence.
- Folders: scenes/, entities/, levels/, shaders/post/, resources/.
- Naming: node names PascalCase; files and folders snake_case; one scene per entity in entities/<name>/.
- Input actions: move_left, move_right, move_forward, move_back, jump.
- Shader contract: single post-process shader at res://shaders/post/post_process.gdshader; helpers get_linear_depth(), get_normal() (skill: godot-screen-textures).
- Entry point: `res://main.tscn` + `res://main.gd` at the project root (set as `run/main_scene`). F5 launches Main; F6 launches individual scenes. No generic `scenes/` folder — every scene lives in its domain folder (levels/, entities/, …); only the entry point sits at root.
- Level loading: levels are instanced and freed under `Main/LevelHost` (a plain Node, `unique_name_in_owner = true`). Never use `change_scene_to_file()` — it replaces the whole tree and destroys the persistent shell.
- Level swap uses `free()` (synchronous), not `queue_free()`. `queue_free()` leaves both levels alive for one frame, causing camera and WorldEnvironment conflicts.
- Migration note: when godot-3d-pixelation runs, `LevelHost` must move inside `SubViewportContainer → SubViewport` under Main. The script's `%LevelHost` unique-name reference will still resolve correctly after the move.
- Hand-authored .tscn: NEVER write `transform = Transform3D(...)` matrices by hand — a transposed basis is still a valid rotation and renders a black screen with zero errors (this happened). Use `position = Vector3(...)` and `rotation_degrees = Vector3(...)` properties instead; both load correctly in .tscn.
- An Environment with `background_mode = 2` (Sky) MUST have an actual Sky resource (e.g. ProceduralSkyMaterial) attached, or the background renders black.
- Rule for AI sessions: read this section before structural changes; record new project-wide decisions here, not in chat.
