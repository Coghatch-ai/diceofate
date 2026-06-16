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

## Agent workflow

This repo ships Claude Code configuration in `.claude/`:

- `agents/godot-dev` — Sonnet-powered sub-agent that implements Godot features
- `skills/godot-*` — project-scoped skills (conventions, pixelation, camera rig, post-processing)

Start Claude Code from this directory so the agent and skills are discovered. See `CLAUDE.md` for details.
