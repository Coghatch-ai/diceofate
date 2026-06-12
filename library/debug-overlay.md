# Debug Overlay (FPS / Performance)
**Request** — In-game FPS, frame time, and memory/draw-call stats overlay for Godot 4.3, without building from scratch.
**Verdict** — parked — adopt was picked by an automated smoke test, confirm before installing (recommendation: adopt godot-debug-menu)

## Candidates
| Addon | Source | License | Godot | Language | Last activity | Notes |
|---|---|---|---|---|---|---|
| godot-debug-menu | https://github.com/godot-extended-libraries/godot-debug-menu | MIT | 4.2+ (tested 4.3) | GDScript | Nov 2025 | Asset Library #1902; maintained by Calinou (Godot contributor) |
| godot-fps-graph-overlay | https://github.com/SanderVanhove/godot-fps-graph-overlay | MIT | unspecified | GDScript | ~4 commits, low activity | FPS graph only; adds autoload; sparse docs |

## Why
godot-debug-menu is the clear choice. MIT license, GDScript throughout, maintained by a Godot core contributor (Calinou) with a commit as recent as November 2025. The addon is a single `CanvasLayer`-based scene registered as an autoload `DebugMenu` — one stray autoload, but it is self-contained and purely additive (no node injection into your scene tree, no dependency on SubViewport). It shows FPS, frame time, CPU/GPU time graphs in compact or detailed mode, toggled with F3. Works across Forward+, Mobile, and Compatibility renderers. The code is clean: `extends CanvasLayer`, `@export` refs, no inheritance abuse. The autoload convention conflict is minor — it can be disabled in export builds via `DebugMenu.style = DebugMenu.Style.HIDDEN` and is dev-only tooling, not game logic.

## Install
- **Pinned source:** `https://github.com/godot-extended-libraries/godot-debug-menu/archive/ff124615a7da981722b3927343b9965a6a156718.zip`
- **Target path:** `addons/debug_menu/`
- **Enable steps:** Project Settings → Plugins → "Debug Menu" → Enable. The plugin registers `DebugMenu` autoload automatically. Toggle in-game with F3.
- **godot-dev task:** Download and unzip the archive above into `addons/debug_menu/`, then enable the plugin in Project Settings. Verify by running the project (F5) and pressing F3 — compact overlay should appear showing FPS and frame time.
- **What godot-verify should observe:** `DebugMenu` node present in autoloads, F3 toggles a CanvasLayer overlay with FPS/frametime values updating each frame.

## Later
- `godot-fps-graph-overlay` (MIT, GDScript) — FPS graph only, low maintenance, no draw-call stats. Worth revisiting only if a purely visual FPS sparkline is wanted without the full DebugMenu overlay.
