# Reserve-Ammo Economy — magazine + reserve pool per weapon

**Goal** — F5: each weapon holds a loaded magazine PLUS a finite reserve; reloading pulls rounds
from the reserve into the mag (partial when reserve is low, blocked when reserve is empty); ammo
crates now refill the **reserve**; the HUD reads `AMMO  mag / reserve`; the gun runs fully dry when
both mag and reserve are empty.

**Why** — Turns the one-magazine model (no reserve) into a managed ammo economy: reloads now cost
finite rounds, so pickups matter as sustain. Roadmap moves reserve-ammo from Out-of-scope IN scope
(new **Track K**), same ratification given Track C/F/G/H/I. POC-minimal: no ammo types/calibers,
no buy/currency, no new pickup beyond the existing `pickup.gd` AMMO crate.

**Decisions applied (interview — recorded so you can override):**
- **Per-weapon reserve, NOT shared.** Each `Weapon` owns its own reserve (`@export var reserve_max`,
  `var _reserve`). Pistol `reserve_max = 48` (4 spare mags), rifle `reserve_max = 90` (3 spare mags;
  set on `rifle.tscn`). Shared pool was rejected — needs a rework, not POC-minimal.
- **Start with FULL reserve.** `_ready()` sets `_reserve = reserve_max` (and mag full as today).
  Simplest; pickups matter once the reserve is burned through.
- **Reload draws from reserve (partial allowed).** Reload tops the mag up to `ammo_max`, limited by
  what's in `_reserve`; the moved rounds leave the reserve. Empty reserve → reload no-ops.
- **Ammo crate adds a FIXED amount to the ACTIVE weapon's reserve = one mag (`ammo_max`), capped at
  `reserve_max`.** Pistol crate +12, rifle crate +30 (it's the held weapon's own `ammo_max`). No-op
  only when the reserve is already full.
- **HUD reads `AMMO  mag / reserve`** (e.g. `AMMO  12 / 48`) — current loaded over reserve remaining.
- **Fully dry = plain dry-click as now.** Mag AND reserve empty → `out_of_ammo` / dry-click SFX, no
  fire, no forced swap. Melee (V) is already the always-available fallback.

## Scope (in)
- **`weapon.gd`**: `@export var reserve_max: int = 48` + `var _reserve: int = 0`. `_ready()` sets
  `_reserve = reserve_max`.
- **Reload pulls from reserve** (replaces refill-from-nothing in `_on_reload_done` + the reload guard):
  - `_on_reload_done()`: `var need := ammo_max - _ammo`; `var pulled := mini(need, _reserve)`;
    `_ammo += pulled`; `_reserve -= pulled`; `_reloading = false`; emit `reload_finished` +
    `ammo_changed(_ammo, _reserve)`; restore view-model.
  - `start_reload()` guard becomes `if _reloading or _ammo >= ammo_max or _reserve <= 0: return`
    (can't reload a full mag OR with an empty reserve).
- **`try_fire()` empty branch**: at `_ammo <= 0`, still emit `out_of_ammo` + dry SFX, but only
  `start_reload()` if `_reserve > 0` (auto-reload). Mag+reserve both empty → dry-click only, no reload.
- **`ammo_changed` signal now carries `(current, reserve)`** instead of `(current, maximum)`. Every
  emit site (`_ready`, `try_fire`, `refill_ammo`, `start_reload` path, `_on_reload_done`, `emit_ammo`)
  passes `(_ammo, _reserve)`. (`ammo_max`/`reserve_max` are exports the HUD doesn't need live.)
- **`refill_ammo()` becomes a reserve add** (the AMMO-pickup seam, unchanged signature `-> bool`):
  rename intent — `if _reserve >= reserve_max: return false`; else `_reserve = mini(_reserve + ammo_max,
  reserve_max)`; emit `ammo_changed(_ammo, _reserve)`; return `true`. (Keeps `pickup.gd` /
  `player.collect_pickup` callers untouched — same method, now adds to reserve, capped.)
- **`rifle.tscn`**: add `reserve_max = 90` (pistol keeps the 48 export default).
- **HUD `arena_hud.gd`**: `set_ammo(current, reserve)` formats `"AMMO  %d / %d"`. `set_reloading(true)`
  still shows `RELOADING…`, `false` re-shows the last ammo text. (Param renamed `maximum`→`reserve`;
  format string already matches — two numbers.)
- **Player**: no logic change — it already forwards `_weapon.ammo_changed` → `hud.set_ammo` and calls
  `emit_ammo()` to seed. The signal's 2nd arg is now reserve; the HUD label updates accordingly.

## Scope (out)
- Shared cross-weapon ammo pool — rejected; per-weapon reserve only (shared needs a rework).
- Fill-to-max ammo crate — chose fixed +1-mag-to-reserve instead.
- Ammo TYPES / calibers / multiple reserve kinds — one reserve number per weapon.
- Buy/economy currency, ammo crates beyond the existing `pickup.gd` AMMO — reuse the one pickup.
- Forced melee/auto-swap when fully dry — plain dry-click (melee V already the fallback).
- Lean-start reserve — chose full reserve at spawn.
- Three-number HUD (`mag / mag-max · reserve`) — chose `mag / reserve`.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` clean on `weapon.gd`, `arena_hud.gd` (+ `player.gd` if touched).
- `godot-verify` all three layers pass (`main.tscn` loads, smoke OK, render OK; AMMO line crisp).
- F5 (pistol): spawn shows `AMMO  12 / 48`. Fire the mag dry → auto-reload pulls 12 from reserve →
  `AMMO  12 / 36`. Repeat reloads → reserve steps 48→36→24→12→0.
- F5 (partial reload): fire ~6, with reserve at e.g. 8 → manual R refills the mag only as far as the
  reserve allows; reserve hits 0; the now-loaded mag still fires.
- F5 (fully dry): burn mag + reserve to 0/0 → trigger does NOT fire and does NOT reload — dry-click
  SFX only; HUD reads `AMMO  0 / 0`. Melee (V) still works.
- F5 (pickup): below-full reserve, walk onto an ammo crate → ACTIVE weapon reserve rises by one mag
  (pistol +12, rifle +30), capped at reserve_max; crate consumes/respawns. Full reserve → crate no-op.
- F5 (rifle): swap to rifle → `AMMO  30 / 90`; its reserve is independent of the pistol's.

## Skill notes
- `godot-travelling-projectile-3d` — reserve logic stays inside the one `try_fire()` / reload path;
  no new firing path. `mini()` clamps; no negative reserve.
- `godot-composition` — reserve state lives on the `Weapon` component; signals UP (`ammo_changed`
  now `(current, reserve)`); player forwards to HUD (calls down); HUD only displays. No autoload.
- `godot-code-rules` — typed `@export var reserve_max: int`, typed `var _reserve: int`; explicit
  return types preserved on `refill_ammo() -> bool`; gate `tools/validate.sh`. Don't weaken warnings.
- `godot-verify` — reserve is runtime state: verify the decrement, partial reload, empty-reserve block,
  pickup add, and per-weapon independence.
- **Signal-shape change** — `ammo_changed`'s 2nd arg semantics change (`maximum`→`reserve`). Audit ALL
  connect sites: only `player.gd` forwards it to `arena_hud.set_ammo`; `arena_hud.gd` is the only
  consumer. No other listener depends on the old `maximum` meaning (grep before building).

## Later
- Shared cross-weapon reserve / total-ammo budget.
- Reserve-aware low-ammo HUD warning (tint when reserve near 0).
- Partial-amount ammo crates / rarer big crates; reserve-only pickup vs mag-fill crate split.
- Per-weapon reserve tuning pass once more weapons exist.

**Open questions** — none blocking. Reuses `weapon.gd` + the existing `pickup.gd` AMMO seam + `ArenaHud`.
