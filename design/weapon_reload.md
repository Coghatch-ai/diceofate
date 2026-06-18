# Weapon Reload — cooldown refill of the magazine

**Goal** — F5: when the magazine is low/empty, pressing `reload` (R) refills it to the cap over a
short delay during which you cannot fire; the gun then shoots again. The dry gun from
`weapon_ammo_limit.md` becomes a sustainable loop.

**Why** — Second half of the seed "bullet limits + recharge time" pair. `weapon_ammo_limit.md` (#1)
added the `_ammo` counter + empty gate; this slice adds the **refill over time** so the player has a
recharge cadence to manage. Strictly depends on #1 (nothing to refill without the counter). Reload
*animation* (#4) and reload *SFX* (#5) are separate cosmetic slices that hook the state this one adds.

**Decisions applied (designer — recorded so you can override):**
- **Manual reload key + auto-reload on empty.** A new `reload` input action (R) starts a reload when
  pressed (if not already full and not already reloading). ALSO: a fire attempt at `_ammo == 0`
  auto-starts a reload (so the player is never stuck doing nothing). Both routes call one
  `start_reload()`. Reason: manual reload is the seed ask; auto-on-empty avoids a dead trigger.
- **Reload = a Timer, mirroring the existing cooldown pattern.** Add a `Reload` one-shot `Timer` node
  to `weapon.tscn` (sibling of `Cooldown`), `wait_time = reload_time`. `start_reload()` sets a
  `_reloading` flag, starts the timer; on `timeout` → `_ammo = ammo_max`, `_reloading = false`,
  emit `ammo_changed` + a new `reload_finished`. Emit a new `reload_started(duration)` when it begins
  (so #4 anim / #5 SFX / #3 HUD can react). `@export var reload_time: float = 1.2`.
- **Can't fire mid-reload.** `try_fire()` gains a guard: `if _reloading: return false` (before the
  ammo gate). Reload is interrupt-free this slice (no cancel-on-fire) — simplest correct behaviour.
- **Reload is idempotent / guarded.** `start_reload()` no-ops if `_reloading` or `_ammo == ammo_max`
  (don't reload a full mag, don't stack timers).
- **Input action `reload` (R)** added to `project.godot`'s input map — sanctioned godot-dev edit
  (input actions are explicitly allowed, like `restart` in `win_lose_condition.md`).
- **Player routes the input.** `player.gd` already polls `shoot`; add `if
  Input.is_action_just_pressed("reload"): _weapon.start_reload()` in `_physics_process` (or
  `_unhandled_input`). The weapon stays the authority; the player just forwards the press.

## Build steps (godot-dev)
1. **`entities/weapon/weapon.tscn`** — add a `Reload` `Timer` (child of `Weapon`): `one_shot = true`,
   `wait_time = 1.2`, `autostart = false`.
2. **`entities/weapon/weapon.gd`** —
   - `@export var reload_time: float = 1.2`; `var _reloading: bool = false`.
   - `@onready var _reload_timer: Timer = $Reload`.
   - New signals `reload_started(duration: float)`, `reload_finished`.
   - `_ready()`: `_reload_timer.one_shot = true; _reload_timer.wait_time = reload_time;
     _reload_timer.timeout.connect(_on_reload_done)`.
   - `try_fire()`: add `if _reloading: return false` at the top. In the existing `_ammo <= 0` branch
     (from #1), instead of only emitting `out_of_ammo`, also call `start_reload()` (auto-reload), then
     `return false`. (Keep `out_of_ammo` emit for the #5 dry-click.)
   - `func start_reload() -> void`: `if _reloading or _ammo >= ammo_max: return`; `_reloading = true`;
     `_reload_timer.start()`; `reload_started.emit(reload_time)`.
   - `func _on_reload_done() -> void`: `_ammo = ammo_max`; `_reloading = false`;
     `reload_finished.emit()`; `ammo_changed.emit(_ammo, ammo_max)`.
3. **`entities/player/player.gd`** — in `_physics_process`, near the `shoot` poll:
   `if Input.is_action_just_pressed("reload"): _weapon.start_reload()`.
4. **`project.godot`** — add input action `reload` bound to `KEY_R`.

## Scope (in)
- `reload_time` export + `Reload` Timer + `_reloading` flag on the weapon.
- `start_reload()` (guarded) + `_on_reload_done()` refill-to-cap; manual (R) and auto-on-empty.
- `try_fire()` blocks while `_reloading`.
- `reload_started(duration)` / `reload_finished` signals.
- `reload` input action (R); player forwards the press.

## Scope (out)
- Reload **animation** (view-model dip) — backlog #4 (hooks `reload_started`).
- Reload **SFX** / dry-click — backlog #5 (hooks `reload_started`/`reload_finished`/`out_of_ammo`).
- Reload on HUD (`RELOADING…`) — `weapon_ammo_hud.md` (#3) consumes these signals.
- Partial reloads, reserve ammo, cancel-reload-on-fire, per-bullet reload — out (single timed refill).

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `weapon.gd`, `player.gd`.
- `godot-verify` passes on `main.tscn` + `weapon.tscn` (F6).
- F5: fire the 12-round mag dry (per #1), press **R** → after ~1.2 s the gun fires again (refilled).
- During the reload window, the trigger does nothing (no projectile, no fire SFX).
- Firing the mag fully dry **auto-starts** a reload (no manual R needed); after the delay it fires.
- Pressing R on a full mag does nothing; pressing R mid-reload doesn't stack/extend it.

## Skill notes
- `godot-travelling-projectile-3d` — reload guards live in the SAME `try_fire()` gate as cooldown +
  ammo; the `Reload` Timer mirrors the existing `Cooldown` Timer pattern. One firing path only.
- `godot-composition` — reload state on the `Weapon` component; signals UP for anim/SFX/HUD; the
  player only forwards the input (calls down). No autoload.
- `godot-first-person-controller` — `reload` input added to the map; player polls it like `shoot`.
- `godot-code-rules` — typed export/signals; explicit return types on `start_reload`/`_on_reload_done`;
  gate `tools/validate.sh`.
- `godot-verify` — reload is timed runtime state; verify the can't-fire window AND that fire resumes.

## Later
- Cancel reload by firing (tactical reload); partial-mag reloads.
- Reserve ammo pool consumed by reloads (finite total ammo).
- Per-weapon `reload_time` once the 2nd weapon lands (#8).

## Open questions
None blocking. Depends only on `weapon_ammo_limit.md` (#1) being built first.
