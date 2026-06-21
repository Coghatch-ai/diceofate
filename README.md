# DiceOfFate

Arena-survival first-person shooter tech demo built on **Godot 4.6 (Forward+)**. This is a POC — a pipeline proof that AI agents can build a playable 3D FPS end-to-end, not a finished game.

> [!WARNING]
> **`project.godot` targets Godot 4.6 (Forward Plus).** Opening in a newer engine version triggers a conversion prompt — accepting rewrites `project.godot` and the project will no longer open in older versions. Keep everyone on the same engine version before accepting.

## What it is

Endless arena survival: kill enemies to escalate the wave, lose a life when touched (3 lives total), reach a score target to win. Five enemy types — grunt, runner, tank (3-hit), magnet (bullet-curving, needs melee), shooter (ranged). Weapon loadout: pistol, rifle, hammer — each with its own ammo pool, reload, and feel.

Built entirely through the Xenodot Forge agent pipeline (Claude Code + godot-* skills). No hand-coding by the author outside the pipeline.

## How to run

**From source (Godot editor):**
1. Open the project in Godot 4.6.
2. Press **F5** to launch `main.tscn` (the arena).
3. Press **F6** to run individual scenes standalone.

**From exported builds (`build/`):**

| Platform | Path |
|---|---|
| macOS | `build/macos/` (`.zip`) |
| Windows | `build/windows/` (`.exe`) |
| Linux | `build/linux/` (`.x86_64`) |

macOS build is unsigned — right-click → Open on first launch, or run `xattr -dr com.apple.quarantine <app>`.

## Controls

| Action | Key |
|---|---|
| Move | WASD |
| Sprint | Shift (hold) |
| Crouch | Ctrl (hold) |
| Jump | Space |
| Fire / swing | LMB |
| Aim (guns only) | RMB |
| Cycle weapon | Q (pistol → rifle → hammer) |
| Reload | R |
| Cycle level | Tab |
| Toggle controls hint | H |
| Restart (end screen) | Enter |

Note: `V` (separate melee key) was removed — LMB now uses whatever weapon is equipped (hammer swings, guns fire).

## About the name

The original plan was a complex RPG — many systems, lots of moving parts. That turned out to be more complicated than expected. So the author is building a series of small tech demos first, to validate the foundation before tackling the real game. The name "DiceOfFate" is a personal reminder of that goal.

## Project structure

```
entities/   player, enemies, weapons, HUD, pickups
levels/     arena scenes (firing_yard, ruined_warehouse)
scripts/    headless level builders
design/     design docs (scope of record)
docs/       roadmap, releases
tools/      validate/verify pipeline (gitignored, from plugin)
build/      exported binaries (gitignored)
```

Full roadmap: [`docs/roadmap/fps_poc.md`](docs/roadmap/fps_poc.md)

## Agent workflow

Repo ships Claude Code config in `.claude/`:

- `.claude/agents/` — sub-agents (godot-dev, code-reviewer, …)
- Godot-* skills load from the xenodot plugin (gitignored `tools/`, `library/` symlink)

Run Claude Code from this directory so agents and skills are discovered. See `CLAUDE.md` for conventions.
