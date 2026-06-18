# Ammo on HUD — magazine + reload state readout

**Goal** — F5: an on-screen `AMMO  n / max` line tracks the magazine live as you fire, and shows
`RELOADING…` (or `AMMO  -- / max`) while a reload is in progress — the ammo/reload state that #1 and
#2 added now reaches the player without watching projectiles.

**Why** — `weapon_ammo_limit.md` (#1) and `weapon_reload.md` (#2) added the counter + reload signals
but nothing surfaces them. This is pure display on the **existing** `ArenaHud` surface (already on
`main.tscn`'s UI CanvasLayer, already showing KILLS/ENEMIES/LIVES) — no new gameplay, lowest risk.
Depends on #1 + #2 (the signals it consumes). Mirrors exactly how `arena_hud.md` surfaced WaveManager
counts.

**Decisions applied (designer — repo seams resolve all forks; recorded so you can override):**
- **New line on the existing `ArenaHud`**, not a new HUD. Add an `AmmoLabel` to the HUD scene under
  `main.tscn`'s UI CanvasLayer (sibling of the existing `KillsLabel`/`ActiveLabel`/`LivesLabel`),
  bottom-right anchored (away from the top-left survival readout, near the crosshair's weapon zone).
  `godot-3d-pixelation`: it's on the CanvasLayer (window res), NOT inside the SubViewport.
- **`ArenaHud` gains `set_ammo(current: int, maximum: int)` and `set_reloading(active: bool)`**,
  matching the existing `set_kills/set_active/set_lives` shape. `set_ammo` →
  `"AMMO  %d / %d"`; `set_reloading(true)` → `"RELOADING…"`; `set_reloading(false)` re-shows the last
  ammo value. Default theme font (no pixel-font sourcing this slice, per arena_hud precedent).
- **Wired through the same injection path the crosshair uses.** The weapon is nested
  (`Player/Head/Weapon`) and the player is loaded per-level; reuse the existing injection seam:
  `main.gd` already does `player.set_crosshair(_crosshair)` after `load_level`. Add a
  `player.set_ammo_hud(_arena_hud)` (or pass the hud) so the **player** connects its `_weapon`'s
  `ammo_changed`/`reload_started`/`reload_finished` signals to the HUD. Reason: `main.gd` can't reach
  the nested weapon cleanly, but the player already holds `_weapon` and is the natural wiring host —
  signals still go UP from the weapon, the player forwards to the HUD (calls down).
- **Player forwards three signals:** `_weapon.ammo_changed` → `hud.set_ammo`;
  `_weapon.reload_started` → `hud.set_reloading(true)`; `_weapon.reload_finished` →
  `hud.set_reloading(false)`. Seed the HUD with the current ammo on connect (the weapon emits
  `ammo_changed` in its `_ready()`; connect before/at ready or re-emit — see build step note).
- **No new gameplay, no new input, no SFX.** Display only.

## Build steps (godot-dev)
1. **HUD scene (the `ArenaHud` node in `main.tscn`)** — add an `AmmoLabel: Label` child,
   bottom-right anchored, readable over the arena. (If the HUD is its own packed scene, edit there;
   per `arena_hud.gd` header it's a `Control` with the labels as children — add one more.)
2. **`entities/hud/arena_hud.gd`** —
   - `@onready var _ammo_label: Label = $AmmoLabel`; `var _last_ammo_text: String = ""`.
   - `_ready()`: `set_ammo(0, 0)` (or hide until first real value).
   - `func set_ammo(current: int, maximum: int) -> void`: `_last_ammo_text = "AMMO  %d / %d" %
     [current, maximum]`; `_ammo_label.text = _last_ammo_text`.
   - `func set_reloading(active: bool) -> void`: if `active` → `_ammo_label.text = "RELOADING…"`;
     else `_ammo_label.text = _last_ammo_text`.
3. **`entities/player/player.gd`** —
   - `var _ammo_hud: ArenaHud` (or store as the HUD type). `func set_ammo_hud(hud: ArenaHud) -> void`.
   - In that setter (or `_ready` if the hud is set before signals fire): connect
     `_weapon.ammo_changed.connect(_ammo_hud.set_ammo)`,
     `_weapon.reload_started.connect(func(_d: float) -> void: _ammo_hud.set_reloading(true))`,
     `_weapon.reload_finished.connect(func() -> void: _ammo_hud.set_reloading(false))`. Guard for
     `_ammo_hud == null`. Then push the current value once so the HUD isn't blank at spawn (e.g. the
     weapon exposes a small `func emit_ammo() -> void: ammo_changed.emit(_ammo, ammo_max)` the player
     calls after connecting — cleaner than relying on `_ready` order).
4. **`main.gd`** — after the existing `player.set_crosshair(_crosshair)`, add
   `player.set_ammo_hud(_arena_hud)`.

## Scope (in)
- `AmmoLabel` on the existing `ArenaHud` (bottom-right, window res, crisp).
- `set_ammo(current, maximum)` + `set_reloading(active)` on `arena_hud.gd`.
- Player wires `_weapon`'s `ammo_changed`/`reload_started`/`reload_finished` to the HUD; seeds initial value.
- `main.gd` injects the HUD into the player (one line, beside the crosshair injection).

## Scope (out)
- Low-ammo colour warning / blink — flat text this slice (parked).
- Dry-click / reload SFX — backlog #5 (separate, hooks the same signals).
- Reload progress bar / radial — text `RELOADING…` only.
- Pixel-font, styling, number-tick animation — default font.
- Per-weapon ammo display switching — only one weapon until #8; #8 will point the HUD at the active weapon.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `arena_hud.gd`, `player.gd`, `main.gd`.
- `godot-verify` passes on `main.tscn` (loads, renders; AMMO line visible, crisp, not blurred).
- F5: HUD shows `AMMO  12 / 12` at spawn; each shot decrements it (…11, 10…); at 0 it reads
  `AMMO  0 / 12`.
- Trigger a reload (R or auto on empty) → HUD shows `RELOADING…` for the reload window, then snaps
  back to `AMMO  12 / 12`.
- Ammo line doesn't overlap the crosshair or the KILLS/ENEMIES/LIVES readout; survives a run reset.

## Skill notes
- `godot-3d-pixelation` — `AmmoLabel` on the CanvasLayer (window res), NOT inside the SubViewport, or
  the text turns to mush. Same rule as the crosshair / existing HUD labels.
- `godot-composition` — weapon emits ammo/reload signals UP; player forwards to the HUD (calls down);
  HUD only displays. No autoload, no HUD reaching into the weapon.
- `godot-main-scene` — HUD lives on the persistent shell, survives `cycle_level`/run reset; the
  per-level player re-injects on each `load_level` (existing crosshair pattern).
- `godot-code-rules` — typed setters/signals, explicit return types, guard null hud; gate
  `tools/validate.sh`.
- `godot-verify` — ammo readout is runtime state; verify decrement, the RELOADING state, and reset.

## Later
- Low-ammo red tint / blink at ≤3 rounds.
- Reload progress radial around the crosshair.
- Point the AMMO readout at the active weapon when the 2nd weapon lands (#8).

## Open questions
None blocking. Depends on #1 + #2 (their `ammo_changed`/`reload_*` signals). All wiring seams exist
(crosshair injection in `main.gd`, ArenaHud label pattern).
