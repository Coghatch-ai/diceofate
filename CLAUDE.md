# DiceOfFate — Claude Context

POC for a game developer framework using Godot 4.x. The goal is to build small things and observe how agents behave.

## Project layout

```
design/           design docs — one per agreed slice (written by game-designer only)
scenes/           .tscn scene files
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

Pipeline: idea → **game-designer** (Opus — interviews the user, cuts scope, writes `design/<slug>.md`) → **godot-dev** (Sonnet — implements the doc) → **godot-verify** (headless checks) → human look in the editor.

This is a framework/workflow to speed up development — not a vibe-coding tool. Requests that can't be built and verified in one small step go through game-designer first; it is expected to push back on scope. Keep tasks small and discrete.

## Skills (in .claude/skills/)

- `godot-project-conventions` — run FIRST in any new setup; records conventions here in CLAUDE.md
- `godot-3d-pixelation` — SubViewport low-res render setup
- `godot-camera-rig` — orthographic fixed-angle follow camera
- `godot-postprocess-quad` — fullscreen quad rig for screen-space effects
- `godot-screen-textures` — depth/normal/screen texture reading in shaders
- `godot-verify` — headless verification (mandatory after scene/script changes); validator lives at `tools/verify_scene.gd`

## Project conventions

- Engine: Godot 4.3+ (reversed-Z). Renderer: Forward+ (required by outline shaders).
- Art style: 3D pixel art. 3D content renders inside a SubViewport (skill: godot-3d-pixelation); post-process effects attach to the camera inside it.
- Camera: orthographic, fixed angle (skill: godot-camera-rig). Do not switch to perspective without flagging the texel-snapping consequence.
- Folders: scenes/, entities/, levels/, shaders/post/, resources/.
- Naming: node names PascalCase; files and folders snake_case; one scene per entity in entities/<name>/.
- Input actions: move_left, move_right, move_forward, move_back, jump.
- Shader contract: single post-process shader at res://shaders/post/post_process.gdshader; helpers get_linear_depth(), get_normal() (skill: godot-screen-textures).
- Rule for AI sessions: read this section before structural changes; record new project-wide decisions here, not in chat.
