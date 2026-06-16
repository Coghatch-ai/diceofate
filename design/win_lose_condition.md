# Win / Lose Condition — kill target, lives, end panel

**Goal** — F5: reach 25 kills → "YOU WIN" panel; lose all 3 lives to enemy touches → "GAME OVER" panel; press Enter on either to restart the run. The endless arena now has a defined start, end, and stakes.

**Why** — The loop is endless-escalating with no end state (touch = silent instant reset, run never finishes). A target + lives give the run a shape (something to reach, something to lose) and turn the existing touch trigger into a real stake. This is the **first** roadmap item pulled out of "Out of scope" (win/lose screen) — kept minimal: text panel only, no VFX.

**Decisions applied (interview — user choices, recorded so you can override):**
- **WIN = reach 25 kills.** `WaveManager` already owns `_kills`; when `_kills >= win_target` (export, default 25) it emits a new `run_won(kills)` signal. Reuses the kill counter the HUD already shows — no new counting.
- **LOSE = 3 lives deplete.** `@export var lives: int = 3`. An enemy touch costs one life (not an instant run reset). At 0 lives → `run_lost(kills)`.
- **Touch is reconciled, NOT replaced (⚠ changes C2 behaviour).** Today `_on_enemy_touched_player` clears enemies + re-seeds + teleports the player **and zeroes `_kills`**. New behaviour: a touch still clears/re-seeds/teleports (keep that rail), but **decrements lives and does NOT zero kills** — kills persist toward the 25 target across lives lost. Only `run_lost`/`run_won` end the run. Emit a new `lives_changed(lives)` after each touch.
- **END = minimal panel + Enter restart, paused.** On win or lose, `get_tree().paused = true` and the HUD shows a centered panel (`YOU WIN` / `GAME OVER` + `KILLS  n`). Pressing the new `restart` action (Enter) unpauses and reloads the level fresh. No auto-restart, no VFX.
- **Panel home = the HUD surface** (`ArenaHud` on `main.tscn`'s UI CanvasLayer), per `arena_hud.md`'s parked "win/lose end panel reusing this surface". Add a hidden `ResultPanel` child + `show_result(won: bool, kills: int)` / `hide_result()`. Panel + its restart input must run while paused (`process_mode = PROCESS_MODE_ALWAYS`).
- **Lives shown on HUD.** `ArenaHud` gains a `set_lives(n: int)` → third line e.g. `LIVES  3`. Default font, like the existing readout.
- **New input action `restart`** (Enter / `KEY_ENTER`) added to the input map — flagged as project-setting scope (godot-dev edits `project.godot`'s input map, allowed for input actions per conventions).

## Build steps (godot-dev)
1. **`wave_manager.gd`** —
   - Add `@export var win_target: int = 25`, `@export var lives: int = 3`; `var _lives: int`.
   - New signals: `run_won(kills: int)`, `run_lost(kills: int)`, `lives_changed(remaining: int)`.
   - `_seed_start`: set `_lives = lives`, emit `lives_changed(_lives)`.
   - `_on_enemy_died`: after `_kills += 1` / `kills_changed`, if `_kills >= win_target` → emit `run_won(_kills)` and **return early** (don't respawn into a won run).
   - `_on_enemy_touched_player`: **remove** the `_kills = 0` + `kills_changed(0)` lines (kills persist). Keep clear + re-seed + teleport. Add: `_lives -= 1`, `lives_changed.emit(_lives)`; if `_lives <= 0` → emit `run_lost(_kills)` (skip the re-seed when the run is over).
2. **`entities/hud/arena_hud.gd`** —
   - `set_lives(n: int)` → `LIVES  %d` label.
   - A hidden `ResultPanel` (Panel + centered Label) child; `show_result(won, kills)` sets text (`YOU WIN` / `GAME OVER` + `KILLS  n` + `Press Enter`) and `visible = true`; `hide_result()` hides it.
   - `ArenaHud.process_mode = PROCESS_MODE_ALWAYS` (panel input survives the pause).
3. **`main.gd`** —
   - In `load_level`, also connect `run_won`→`_on_run_ended.bind(true)`-style, `run_lost`→ end handler, `lives_changed`→`_arena_hud.set_lives`. Seed `set_lives` too.
   - End handler: `get_tree().paused = true`; `_arena_hud.show_result(won, kills)`.
   - `_input` (or `_unhandled_input`): when a result panel is showing and `restart` pressed → `get_tree().paused = false`, `_arena_hud.hide_result()`, `load_level(_levels[_level_index])`.
4. **`project.godot`** — add input action `restart` bound to Enter.

## Scope (in)
- 25-kill win, 3-life lose, kills persist across lives; signals + counters on `wave_manager.gd`.
- `ArenaHud`: lives line + result panel (`show_result`/`hide_result`), runs while paused.
- `main.gd`: wire the three new signals; pause + show panel on end; `restart` reloads the level.
- `restart` input action (Enter).

## Scope (out)
- Player health/damage model — touch costs a whole life, not HP (a life IS the health unit this slice). (Later.)
- VFX on win/lose (flashes, particles, slow-mo) — text panel only. (Roadmap keeps VFX out.)
- Score weighting, high-score, persistence, timer — kills is a flat target.
- Difficulty ramp on win, multiple levels, menu — single level reload only.
- Pixel-font / styled panel — default theme font.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `wave_manager.gd`, `arena_hud.gd`, `main.gd`.
- `godot-verify` passes on `main.tscn` (loads, renders; HUD shows KILLS / ENEMIES / LIVES; result panel hidden at start).
- F5 start: `KILLS 0 / ENEMIES 2 / LIVES 3`, no panel.
- Get touched → LIVES drops to 2, enemies re-seed, player teleports to spawn, **kills are NOT zeroed**; repeat to 0 → `GAME OVER` panel + final kills, game paused.
- Reach 25 kills → `YOU WIN` panel + `KILLS 25`, game paused, no further spawns.
- Press Enter on either panel → run restarts: LIVES 3, KILLS 0, ENEMIES 2, unpaused. Repeatable.

## Skill notes
- `godot-composition` — `WaveManager` emits `run_won`/`run_lost`/`lives_changed` UP; HUD only displays; `main.gd` wires + owns the pause/restart. No autoload, no singleton.
- `godot-main-scene` — panel lives on the persistent shell HUD, not the level, so it survives the reload; `main.gd` owns `load_level` restart.
- `godot-3d-pixelation` — result panel + lives text on the CanvasLayer (window res), NOT inside the SubViewport.
- `godot-code-rules` — typed signals (`run_won(kills: int)`…), explicit return types; gate `tools/validate.sh`.
- `godot-verify` — win/lose/pause/restart are runtime state; verify each path and that Enter cleanly restarts (no orphans, no double-paused).
- ⚠ This **changes C2 reset-on-touch semantics** (touch no longer zeroes kills / no longer = full run reset). Note it against Track C in the roadmap; verifier owns the gate flip.

## Later
- Per-enemy-type kill scoring; combo/streak.
- A "you survived N waves" stat on the panel.
- Win/lose VFX + SFX (sting on the panel) once VFX comes in scope.
- Health pips instead of discrete lives; partial damage.
- Menu / level select on restart instead of straight reload.

## Open questions
None blocking. All seams exist (`_kills`, touch handler, `main.gd` signal wiring, ArenaHud surface). `restart` input action is a one-line `project.godot` add.
