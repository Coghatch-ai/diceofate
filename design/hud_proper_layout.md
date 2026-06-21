# Proper HUD — organized anchored layout

**Goal** — F5: the HUD reads like a real FPS — ammo bottom-right (big number + reload state), lives (heart pips) and a stamina bar bottom-left, score + live-enemy count top-center, with a red pulse on the lives block on the final life. Pure re-layout: every value reuses a signal that already exists.

**Why** — Current HUD is ad-hoc: score/enemies/lives plain-text stacked top-left, ammo+stamina dumped as bottom-right text. No grouping, no bars, no vitals emphasis. This organizes the existing surface; no new gameplay.

## Decisions applied (locked via form)
- **Anchors:** ammo bottom-right; lives + stamina bottom-left; score + enemies top-center; existing life-lost flash and win/die `ResultPanel` stay centered, unchanged.
- **Presentation:** ammo = big number (`c / r`); lives = row of heart/pip icons (N pips, not text); stamina = horizontal fill bar.
- **Stamina:** always visible (not auto-hide).
- **Low-health warning:** lives block pulses red while `lives == 1`. Reuses `lives_changed`; no new gameplay.
- **WAVE label — CUT (see Later).** `wave_manager.gd` has NO discrete-wave concept (continuous per-kill escalation, no `_wave` counter / `wave_changed` signal). A real WAVE number would require new gameplay state — out of this slice's "re-layout only" bound. Score stays as the top-center progress number.

## Scope (in)
- Rebuild `HUD/ArenaHud` node tree in `main.tscn` into 3 anchored containers + center overlays:
  - **TopCenter** (`VBoxContainer` or 2 Labels, top-center anchor): `SCORE n` / `ENEMIES n`.
  - **BottomLeft** (bottom-left anchor): `LivesContainer` (`HBoxContainer` of pip `TextureRect`s) + `StaminaBar` (`ProgressBar` or styled `ColorRect` fill) with a small `STAMINA` label.
  - **BottomRight** (bottom-right anchor): `AmmoLabel` big font (`c / r`), swaps to `RELOADING...` on reload.
  - Keep `ResultPanel`/`ResultLabel` + `LifeLostLabel` centered as-is.
- `arena_hud.gd` method signatures **unchanged** (`set_score`, `set_active`, `set_lives`, `set_ammo`, `set_reloading`, `set_stamina`, `flash_life_lost`, `show_result`, `hide_result`) — only their bodies update the new nodes. Existing `main.gd` / `weapon_controller.gd` / `player.gd` wiring keeps working with zero changes to callers.
  - `set_lives(n)`: show n pip icons (toggle visibility of a fixed pip row, or instance pips). Start = 3.
  - `set_stamina(cur,max)`: drive bar fill ratio; always visible.
  - `set_lives(n)`: when `n == 1` start a looping red modulate pulse on `LivesContainer`; when `n > 1` stop pulse + reset modulate to white.
- Pip icon: a simple heart/dot. Use `tools/gen_textures.gd` (procedural placeholder) OR a `ColorRect`/`Polygon2D` pip if simpler — godot-dev's call; no asset-sourcing this slice.

## Scope (out)
- WAVE number — no wave state exists; needs new gameplay (see Later).
- Per-hit health bar — lives = pips, touch still = instant life loss (no HP value to show).
- Stamina auto-hide, pixel/bitmap fonts, animated number ticks, themed panel backings — not requested / not blocking.
- Crosshair — untouched.
- New signals or WaveManager changes — this slice adds none; pure presentation.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `arena_hud.gd` (only file with code changes; `main.tscn` re-layout).
- `godot-verify` passes on `main.tscn` (loads, renders, all HUD groups visible, crisp, not blocking crosshair).
- F5 start: top-center `SCORE 0` / `ENEMIES 2`; bottom-left 3 heart pips + full stamina bar; bottom-right `AMMO` big number.
- Sprint → stamina bar drains/refills smoothly, always visible.
- Fire → ammo number drops; reload → `RELOADING...`; refills.
- Kill → SCORE rises, ENEMIES tracks live count.
- Lose a life → pip disappears; at 1 life left → lives block pulses red. Regain/reset → pulse stops, pips restore.
- Win/die → centered `ResultPanel` still shows; life-lost flash still fires.

## Skill notes
- `godot-main-scene` — HUD stays in the persistent shell's `HUD` CanvasLayer (sibling of `Crosshair`); survives `cycle_level`. Do NOT move it into a level.
- `godot-3d-pixelation` — HUD on the CanvasLayer OUTSIDE the SubViewport → renders at window res, crisp. Pips/bars must not be downscaled.
- `godot-composition` — display-only; HUD reads injected values via existing methods, reaches into nothing. No new autoload/singleton.
- `godot-code-rules` — strict typed GDScript; explicit return types; gate `tools/validate.sh`. Tween for the red pulse, `Tween.kill` before restarting it (avoid stacked tweens on repeated `set_lives(1)`).
- `godot-verify` — runtime state: verify start values, drain, reload swap, pip removal, last-life pulse.
- (Optional) `godot-procedural-texture` / `tools/gen_textures.gd` — only if godot-dev chooses a textured pip over a vector/ColorRect pip.

## Later
- Real WAVE system + `wave_changed` signal in WaveManager, then a WAVE label (own slice — gameplay, not HUD).
- Per-hit health bar if hit model changes from instant-life-loss to HP.
- Stamina auto-hide-when-full; themed panel backings; pixel font; number-tick animation.

## Open questions
None blocking. All values reuse existing signals; only `arena_hud.gd` bodies + `main.tscn` node tree change.
