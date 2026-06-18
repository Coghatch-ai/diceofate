# Level Progression — advance on win & on life-loss

**Goal** — Losing a life (lives remain) or winning a level moves the run to the NEXT level in
rotation (firing_yard → ruined_warehouse → wrap) carrying score + lives, instead of re-seeding /
restarting the same level. Only lives==0 ends the run.

**Run-state approach (decided): thin run-state autoload `RunState`.**
Why: the swap calls `current_level.free()`, so score/lives currently held in the level's
`WaveManager` are destroyed with the node. Composition/signals (signals-up/calls-down) cannot carry
data across a node that no longer exists, and the new level's `WaveManager._seed_start()` resets
both to its own exports on load. CLAUDE.md prefers composition over autoloads, but the
skill-researcher named "a thin run-state autoload + registry metadata" as the sanctioned path
exactly for state that must persist across a swap — this is that case. Kept minimal: a 3-field
data holder, no game logic.

```
# RunState (autoload) — carries run state across a level swap. Data only, no logic.
var active: bool = false   # true while a progression carry is in flight
var score: int = 0         # score to restore into the next level's WaveManager
var lives: int = 0         # lives to restore into the next level's WaveManager
```

## Scope (in)

- **Add `RunState` autoload** (`project.godot` `[autoload]`), the 3 fields above. Pure data holder.
- **WaveManager: emit a "advance" intent instead of acting in place.**
  - New signal `advance_level(score: int, lives: int)`.
  - On life-loss with `_lives > 0`: stop the in-place re-seed + player teleport; instead set
    `_run_over = true`, free live enemies, emit `advance_level(_score, _lives)`. (The decrement
    already happened, so it carries the reduced lives.)
  - On win (`_score >= win_score`): set `_run_over = true`, emit `advance_level(_score, _lives)`
    instead of `run_won`. (Win no longer shows the YOU-WIN panel mid-rotation — see wrap below.)
  - On `_lives <= 0`: unchanged — still emit `run_lost(_score)` (the only real game-over).
- **WaveManager: restore carried state on seed when a carry is in flight.** In `_seed_start()`,
  if `RunState.active`: set `_score = RunState.score`, `_lives = RunState.lives` (override the
  per-level `lives`/`0` defaults), then clear `RunState.active`. Emit the same `*_changed` signals
  so the HUD shows carried values, not 0 / level-default. Enemy seeding (grunt-first, H19) unchanged.
- **main.gd: handle `advance_level`.** Connect `wave_manager.advance_level` in `load_level()`.
  Handler: `RunState.active = true; RunState.score = score; RunState.lives = lives;` advance
  `_level_index = (_level_index + 1) % _levels.size()` and `load_level(_levels[_level_index])`.
  No pause, no result panel.
- **main.gd: HUD continuity on a progression swap.** `load_level()` currently hard-sets
  `set_score(0)` / `set_active(0)`. Guard the score reset: when `RunState.active` is true, do NOT
  zero the HUD score — let the restored `score_changed` emit drive it. `set_active(0)` stays (new
  level genuinely starts with its own live count). Lives line already follows `set_lives`.
- **End-of-rotation = wrap (no final-win screen).** `(idx + 1) % size` loops firing_yard →
  warehouse → firing_yard … indefinitely, score + lives accumulating. POC default: an endless
  escalating run; the only end states are lives==0 (GAME OVER) and the manual restart from it.

## Scope (out)

- Final "you beat all levels" / victory screen — POC is endless; wrap instead (cut: no defined end,
  avoids new UI + new end-state wiring).
- Per-level difficulty curve / score-target scaling across the rotation — each level keeps its own
  `win_score` export; carried score makes later levels end faster, accepted for POC (cut: scope).
- Carrying ammo / weapon / reload state across the swap — out; weapons re-init per level as today
  (cut: not requested, adds per-entity serialization).
- Changing the manual Tab cycle's behaviour — see below, it stays a debug jump (cut: not in ask).

## Coexistence & edge cases (decided defaults)

- **Manual Tab (`cycle_level`)**: stays a raw debug jump — loads the next level WITHOUT setting
  `RunState.active`, so the new level seeds fresh from its own `lives`/`score=0` defaults. No
  conflict: the autoload flag is only set by the `advance_level` path. Documented as debug-only.
- **`restart` from GAME OVER**: still reloads `_levels[_level_index]` (the level the player died on).
  `RunState.active` is false on this path → fresh seed. No change needed.
- **Real game-over**: only `_lives <= 0` → `run_lost` → pause + panel. Win + life-loss-with-lives
  no longer pause.
- **Carry correctness**: life-loss carries the ALREADY-decremented lives; win carries current lives
  unchanged. Score always carries current `_score`.

## Acceptance

- F5 firing_yard: take a hit with lives>1 → warehouse loads immediately (no teleport-in-place),
  LIVES shows the decremented count, SCORE unchanged (not 0), enemies re-seed (grunt-first).
- Reach `win_score` in firing_yard → warehouse loads immediately, SCORE carried (not 0), LIVES carried.
- Continue: win/lose-a-life in warehouse → wraps back to firing_yard, state still carried.
- Deplete to 0 lives anywhere → GAME OVER panel (paused), Enter restarts that same level fresh
  (LIVES = level default, SCORE 0).
- Press Tab any time → jumps to next level, seeds FRESH (level-default lives, score 0) — debug path.
- godot-verify: validate.sh clean; smoke + render OK on main.tscn; no "Signal already connected".

## Skill notes

- `godot-main-scene` — swap stays under `%LevelHost` via `load_level()`; never `change_scene_to_file`.
  The autoload is the sanctioned cross-swap persistence holder; keep Main the wiring point.
- `godot-composition` — WaveManager signals the intent UP (`advance_level`); Main owns the swap +
  RunState writes. WaveManager only READS RunState in `_seed_start`. Autoload is data-only (no logic),
  the documented exception to composition-over-autoload for state surviving `free()`.
- `godot-code-rules` — strict typed GDScript on the new autoload + signal + handler; gate validate.sh.
- `godot-verify` — re-verify after the .gd + project.godot change; confirm no double signal connect
  across repeated swaps.

## Later

- Final victory screen + a finite level list (turn wrap off).
- Carry ammo/weapon loadout across the swap.
- Per-rotation difficulty scaling (raise `win_score` / ratios each lap).
- A "level N" / lap counter on the HUD.

## Open questions

(none — POC defaults applied above.)
