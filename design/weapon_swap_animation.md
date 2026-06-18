# Weapon Swap Animation (Q)

**Goal** — Pressing Q to swap pistol↔rifle plays a fast lower-then-raise of the view-model (a snappier version of the H4 reload dip) instead of an instant visibility toggle; the newly-equipped weapon can't fire until the raise completes.

## The problem this fixes
`player._swap_weapon()` (player.gd 101–108) swaps instantly — just flips `visible`. User wants a quick, NOT instant, swap with a lower/raise and a brief fire lockout.

## Decisions (applied defaults — override here)
- **Swap duration ~0.25 s total** (≈ half the 1.2 s reload dip → "snappier"). Lower ~0.12 s, raise ~0.13 s.
- **Visibility swaps at the bottom of the dip** (old weapon lowered out of view → toggle → new weapon raises up), so the swap looks like one weapon going down and the other coming up.
- **Fire locked for the whole swap.** Reuse the existing per-weapon `_reloading`-style gate: add a `_swapping` bool on `weapon.gd` (or a transient `can_fire` flag) set true during the raise, cleared on finish; `try_fire()` returns false while set. Owned by the weapon, not the player, so the lockout travels with the active weapon.
- **Swap is debounced:** a Q press during an in-progress swap is ignored (no queue), so you can't stack tweens.

## Scope (in)
- `weapon.gd`: a `play_holster()` (lower to a `_VM_DIP_POS`-style down position) and `play_draw()` (raise back to `_VM_REST_POS`) using the SAME `create_tween()` shape as `_play_reload_dip()`/`_restore_view_model()`, but at the snappier durations. A `swap_ready` signal (or callback) fires when the draw completes.
- `weapon.gd`: a fire gate (`_swapping` bool) — `try_fire()` early-returns false while swapping; cleared when `play_draw()` finishes.
- `player.gd._swap_weapon()`: instead of instant toggle, run: lock input → `current.play_holster()` → at bottom flip `visible` (old off / new on) → `next.play_draw()` → on draw-done the new weapon is fire-ready. Keep the existing HUD re-wire (`_wire_ammo_hud`) — call it when visibility flips.
- Debounce: ignore `equip_weapon` press while a swap is mid-flight.

## Scope (out)
- A swap SFX — Later (no clip sourced; not requested).
- Per-weapon distinct holster poses / unique draw arcs — both use the same dip shape, retuned.
- Animating the melee knife (separate doc) — knife is its own button, not in the Q cycle, no swap anim.
- Cancelling a reload to swap, or swap-cancelling a swap — debounced, simplest.
- Queuing a Q press during a swap — ignored, not buffered.

## Acceptance (F5 + godot-verify)
- Press Q → active view-model lowers (~0.12 s), the other rises (~0.13 s); total feels fast but clearly not instant.
- Holding fire across a Q press → no shot lands until the raise finishes; first shot fires the instant it's up.
- Spamming Q rapidly → no tween stacking, no drift; view-model always returns to `_VM_REST_POS`.
- HUD ammo line switches to the newly-active weapon's count as before.
- godot-verify: scenes load/render; validate.sh passes; view-model has no residual offset after repeated swaps.

## Skill notes
- `godot-code-rules` — typed; reuse `create_tween()`; gate validate.sh.
- `godot-composition` — lockout + tween live on the weapon; player orchestrates the holster→flip→draw sequence (calls down).
- `godot-first-person-controller` — `equip_weapon` already mapped (Q, keycode 81); no input change.
- `godot-verify` — no view-model drift after repeated swaps.
- No skill gap — pure reuse of the H4 dip tween + the existing swap path.

## Later
- Swap SFX (holster clack + draw rack).
- Per-weapon bespoke draw animations once real weapon models land.

## Open questions
None blocking.
