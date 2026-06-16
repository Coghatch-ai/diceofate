# Arena HUD — kills + active-enemy count on screen

**Goal** — F5: a small on-screen readout shows your kill total and the live enemy count, both updating in real time as you fight — the survival data that today only prints to the console.

**Why** — The whole loop (WaveManager kills/escalation/reset) communicates only via `print`. A player not watching the console feels no progress. This surfaces data the game ALREADY tracks; no new gameplay. Unblocks every later UI feature (health pips, score, win screen) by establishing the HUD surface.

**Decisions applied (recommendations — repo seams resolve all forks):**
- **HUD home = the persistent shell**, not the level. New `entities/hud/arena_hud.gd` (`class_name ArenaHud`, `extends Control`), placed under the existing UI CanvasLayer in `main.tscn` (sibling of `%Crosshair`). Reason: the shell already owns the crosshair the same way; HUD survives `cycle_level`.
- **Rendered at window resolution, crisp** — on the CanvasLayer (outside the SubViewport), exactly like `Crosshair`. Per `godot-3d-pixelation`: UI text must NOT be downscaled or it turns to mush. (No pixel-font sourcing this slice — default theme font is fine for a POC readout.)
- **Data flows UP via signals** (`godot-composition`). `WaveManager` is the arena authority that owns the counts; it emits, the HUD displays. Add to `wave_manager.gd`:
  - `signal kills_changed(total: int)`
  - `signal active_changed(count: int)`
  - a `var _kills: int = 0`, incremented in `_on_enemy_died`, emitting `kills_changed`.
  - emit `active_changed(_active_enemies.size())` after every change: end of `_seed_start`, `_spawn_one`, `_on_enemy_died`, `_on_enemy_touched_player`.
  - on reset (`_on_enemy_touched_player`): set `_kills = 0`, emit `kills_changed(0)` (a run reset zeroes the score). Emit a fresh `active_changed` after re-seed.
- **`main.gd` is the wiring host.** After `load_level`, find the `WaveManager` in the level and connect its two signals to the injected `ArenaHud` (same injection pattern as `player.set_crosshair(_crosshair)`). If no WaveManager (other levels later), HUD stays at zeros — no crash.
- **Display format** = two short lines, top-left, e.g. `KILLS  12` / `ENEMIES  5`. Monospace-ish alignment not required this slice.

## Scope (in)
- `entities/hud/arena_hud.gd` + a node for it under `main.tscn`'s UI CanvasLayer: two `Label`s (or one with `\n`), top-left anchored, readable over the arena.
- Public methods on `ArenaHud`: `set_kills(n: int)` and `set_active(n: int)` that update the labels.
- `wave_manager.gd`: the two signals, the `_kills` counter, the emits listed above, kills-zeroed-on-reset.
- `main.gd`: locate `WaveManager` in the loaded level, connect `kills_changed`→`set_kills`, `active_changed`→`set_active`; seed the HUD with current values on connect.

## Scope (out)
- Player health / health bar — separate future slice (touch still = instant reset).
- Score weighting, combos, high score, timers — kills is a raw count this slice.
- Win/lose panel — needs this HUD first; its own slice.
- Pixel/bitmap font sourcing, fancy styling, animation on the numbers — default font, static text.
- Wave-number readout — escalation is per-kill, not per-wave; not meaningful to show.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript) on `arena_hud.gd`, `wave_manager.gd`, `main.gd`.
- `godot-verify` passes on `main.tscn` (loads, renders, HUD text visible over the arena).
- F5: HUD shows `KILLS 0` / `ENEMIES 2` at start.
- Kill an enemy → KILLS increments, ENEMIES tracks the live count as it escalates (2→3→4…, holds at 30).
- Get touched → KILLS resets to 0, ENEMIES back to 2. Repeatable.
- HUD text is crisp (not pixelated/blurred), stays through play, doesn't block the crosshair.

## Skill notes
- `godot-3d-pixelation` — HUD lives on the CanvasLayer ABOVE/OUTSIDE the SubViewport so text renders at window res. Do NOT parent it inside the pixelation rig.
- `godot-composition` — `WaveManager` signals UP (`kills_changed`/`active_changed`); HUD only displays, never reaches into the manager. `main.gd` wires them; no autoload, no singleton.
- `godot-main-scene` — the HUD belongs to the persistent shell (`main.tscn`), not the level, so it persists across `cycle_level`.
- `godot-code-rules` — typed signals, explicit return types, gate `tools/validate.sh`.
- `godot-verify` — counts are runtime state; verify start values, increment on kill, reset on touch.

## Later
- Player health pips next to the count (this HUD is their home).
- Score weighting per enemy type (pairs with the enemy-variety slice).
- Win/lose end panel reusing this surface.
- Pixel-font theme + styled panel; number-tick animation.

## Open questions
None blocking. All seams exist (`WaveManager` counts, `main.gd` injection pattern, CanvasLayer UI).
