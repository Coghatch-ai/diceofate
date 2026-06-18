# Weapon Ammo Limit — bullet cap on the pistol

**Goal** — F5: the pistol holds a finite magazine; each shot consumes one round; when the magazine
hits 0 the gun stops firing (no projectile, no fire SFX) until refilled — you can run dry.

**Why** — Today `weapon.gd` fires forever, gated only by the cooldown timer. A finite magazine is the
first half of the seed "bullet limits / reload" pair and the seam every later weapon feature reuses
(reload #2, ammo HUD #3, the rifle's own cap #8). This slice adds the **counter + the empty gate
only** — refilling is the very next slice (`weapon_reload.md`), so on its own the gun runs dry and
stays dry until you reload (built next). That's intentional: keep this slice to one observable change.

**Decisions applied (designer — repo seams resolve all forks; recorded so you can override):**
- **Ammo lives on `weapon.gd`**, not the player or an autoload. The weapon is the firing authority
  (`try_fire()` already owns the cooldown gate); ammo is the same kind of state. `godot-composition`:
  state sits with the component that owns the behaviour.
- **`@export var ammo_max: int = 12`** (pistol magazine) + `var _ammo: int`. `_ready()` sets
  `_ammo = ammo_max` (full at start). 12 is a readable pistol mag; tune via the export.
- **Gate in `try_fire()`, before the cooldown check is consumed.** New order: if `_ammo <= 0` →
  return `false` (and emit a new `out_of_ammo` signal for the dry-click SFX/HUD later) WITHOUT
  starting the cooldown; else proceed, then `_ammo -= 1` on a successful fire and emit
  `ammo_changed(_ammo, ammo_max)`. Keeps the existing cooldown semantics intact.
- **New signals now (so #2/#3/#5 wire to them without re-editing this file):**
  `signal ammo_changed(current: int, maximum: int)` and `signal out_of_ammo`. Emit `ammo_changed`
  on every successful fire and once in `_ready()` (initial value). `out_of_ammo` emits when a fire is
  attempted at `_ammo == 0`.
- **No reload, no HUD, no SFX this slice.** Empty = silent block + the signals. Refill is `#2`,
  display is `#3`, dry-click sound is `#5`. Each is its own one-task slice.

## Build steps (godot-dev)
1. **`entities/weapon/weapon.gd`** —
   - Add `@export var ammo_max: int = 12` and `var _ammo: int`.
   - Add `signal ammo_changed(current: int, maximum: int)` and `signal out_of_ammo`.
   - In `_ready()`: after the existing cooldown setup, `_ammo = ammo_max`; `ammo_changed.emit(_ammo, ammo_max)`.
   - In `try_fire()`: at the very top, `if _ammo <= 0: out_of_ammo.emit(); return false`. Keep the
     existing `if not _cooldown.is_stopped(): return false`. After the successful `_fire()` /
     `_fire_sfx.play()` / `_cooldown.start()` / `fired.emit()` block, add `_ammo -= 1;
     ammo_changed.emit(_ammo, ammo_max)` then `return true`.
2. **No `.tscn` change** — `ammo_max` keeps its default; `weapon.tscn` already instances `weapon.gd`.

## Scope (in)
- `ammo_max` export (default 12) + `_ammo` counter on `weapon.gd`.
- Empty gate in `try_fire()`: at 0 ammo, no fire, no cooldown start, `out_of_ammo` emitted.
- `ammo_changed` + `out_of_ammo` signals; `ammo_changed` emitted on ready + each successful shot.

## Scope (out)
- Reload / refill — next slice (`weapon_reload.md`). On its own the gun stays empty after 12 shots.
- Ammo HUD display — `weapon_ammo_hud.md` (#3).
- Dry-click / empty SFX — backlog #5 (reuses `out_of_ammo`).
- Reload animation, second weapon, per-weapon ammo balancing beyond the one export — later.
- Player- or autoload-owned ammo; ammo pickups; reserve ammo (only a magazine, no reserve pool).

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript) on `weapon.gd`.
- `godot-verify` passes on `main.tscn` + `weapon.tscn` (F6): scene loads, renders, gun present.
- F5: hold fire → exactly **12** shots leave the muzzle (count the projectiles / fire SFX), then the
  13th+ trigger pulls produce **no projectile and no fire sound** — the gun is dry.
- Cooldown cadence on the first 12 shots is unchanged from today.
- No errors on the dry trigger pulls; firing never resumes this slice (refill is #2).

## Skill notes
- `godot-travelling-projectile-3d` — `try_fire()` is the documented firing seam (cooldown Timer gate);
  ammo is a second pre-gate in the SAME method. Do NOT add a parallel firing path.
- `godot-composition` — ammo state + signals live on the `Weapon` component; signals go UP
  (`ammo_changed`/`out_of_ammo`) for HUD/SFX hosts to consume later. No reach-in from player/HUD.
- `godot-code-rules` — typed `@export var ammo_max: int`; typed signals; explicit `-> bool` already on
  `try_fire`; gate `tools/validate.sh`. No `@warning_ignore` needed.
- `godot-verify` — ammo is runtime state; verify the 12-then-dry behaviour, not just that it loads.

## Later
- Reserve ammo pool + partial reloads (only magazine here).
- Per-weapon `ammo_max` tuning when the 2nd weapon lands (#8).
- Ammo pickups on the arena floor.

## Open questions
None blocking. `try_fire()` is the only logic touch; signals are additive.
