# DiceOfFate

POC for a game developer framework using Godot 4.x. The goal is to build small things and observe how AI agents behave when doing game development.

> [!WARNING]
> **`project.godot` may be outdated for your Godot version.** This project currently targets **Godot 4.6 (Forward Plus)**. If you open it with a newer engine version, Godot will offer to convert the configuration file — accepting rewrites `project.godot` and the project will **no longer open in previous Godot versions**. Make sure everyone on the project is on the same engine version before accepting a conversion, and commit the converted file so the repo and the editor agree.

## Requirements

- Godot 4.6 or later

## Layout

```
scenes/    .tscn scene files
scripts/   .gd GDScript files
assets/    textures, audio, fonts
addons/    Godot plugins
```

Example assets sourced from free CC0 libraries live OUTSIDE this repo, in the framework's
external shared-asset library, and are mounted here as a gitignored symlink at
`res://x-shared-assets/` (`models/` + `textures/`). See the framework README (`x-shared-assets`).

## Roadmap

Active POC: first-person shooter arena. Full source of truth: [`docs/roadmap/fps_poc.md`](docs/roadmap/fps_poc.md).

| Track | What | Status |
|---|---|---|
| **A — Core FPS loop** | Perspective rig, first-person controller, weapon + projectiles | ✅ GATE: SHOOTABLE pass |
| **B — Arena & targets** | Greybox arena, static targets, patrolling enemy AI | ✅ GATE: ENEMY AI pass |
| **C — Survival loop** | Wave escalation, reset-on-touch, spawn hardening | ✅ C1/C2 pass; C3 build+verify, awaiting human F5 |
| **D — Ship v0.1** | Export presets, desktop builds, itch.io upload | ✅ SHIPPED (Linux/Win/macOS, 2026-06-16) |
| **E — Feel** | Audio bus + fire SFX, hazard floor, moving crusher | ✅ build+verify; awaiting human F5 |
| **F — Legibility** | Arena HUD (kills/enemies), Runner enemy type | ✅ build+verify; awaiting human F5 |
| **G — Stakes** | Tank enemy (3-hit), Win/Lose end panel + lives system | ✅ build+verify; G2 human-playtested (2026-06-16) |

## Agent workflow

This repo ships Claude Code configuration in `.claude/`:

- `agents/godot-dev` — Sonnet-powered sub-agent that implements Godot features
- `skills/godot-*` — project-scoped skills (conventions, pixelation, camera rig, post-processing)

Start Claude Code from this directory so the agent and skills are discovered. See `CLAUDE.md` for details.
