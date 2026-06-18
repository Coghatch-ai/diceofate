# Player Feel Port — movement accel + slower aim + spring recoil

**Goal** — Player moves with a weighty accel/decel ramp instead of robotic snap, aims ~20% slower and resolution-independent, and gun recoil settles with a springier feel — all tuned live in F5.

## Comparison findings (existing vs salvaged addon)

Movement:
- Ours (`player.gd` step 7): instant `velocity.x/z = direction * effective_speed`, snap stop via `move_toward`. No accel/friction → robotic.
- Addon (`run_state_script.gd`/`idle_state_script.gd`): `velocity = lerp(velocity, target, accel*delta)`, separate idle decel. Weighty ramp = the main feel win. Plus FSM, head-bob, move-tilt, air-curves, bunny-hop (all extra).

Aim:
- Ours (`player.gd` `_unhandled_input`): raw `relative * mouse_sensitivity (0.002)`, no window-scale norm.
- Addon (`player_camera_script.gd`): raw `relative * (sens/10) / window.content_scale_factor` → resolution-independent. "Better aim" = norm + value; "too fast" = the raw number.

Recoil:
- Ours (`player.gd` step 5 + `_on_weapon_fired`): additive `_recoil_pitch`/`_recoil_yaw` on head, LINEAR decay (`recoil_recover`), clamp `recoil_max`. Works, layered correctly (never overwrites look — roadmap I2).
- Addon (`camera_recoil_holder_script.gd`): two-stage lerp spring — `target = lerp(target,0,base_speed*dt)`; `current = lerp(current,target,target_speed*dt)`. Springier snap-and-settle.

## Scope (in) — ONE slice, all in `entities/player/player.gd` (+ player.tscn export defaults)

1. **Accel/decel movement.** Add `@export move_accel: float`, `@export move_decel: float`. Replace step-7 instant set with: when input, `velocity.x/z = lerp(velocity.x/z, target.x/z, move_accel*delta)`; when no input, `lerp(..., 0.0, move_decel*delta)`. Keep ADS speed scaling. Starting values: `move_speed=4.0`, `move_accel=10.0`, `move_decel=12.0`.
2. **Slower, resolution-independent aim.** `mouse_sensitivity` default `0.002 → 0.0016`. In `_unhandled_input`, divide yaw+pitch delta by `get_window().content_scale_factor` (guard ≥ 0.001). No smoothing (keep raw).
3. **Spring recoil decay.** Replace step-5 linear decay with two-stage lerp: keep `_recoil_pitch`/`_recoil_yaw` as the applied (`current`) values, add `_recoil_target_pitch`/`_recoil_target_yaw`; each frame `target = lerp(target,0,recoil_settle*delta)`, `current = lerp(current,target,recoil_snap*delta)`. `_on_weapon_fired` adds impulse to TARGET (not applied). Add `@export recoil_settle: float = 8.0`, `@export recoil_snap: float = 14.0`. Drop/repurpose `recoil_recover`. Keep additive-on-head layering (still never overwrites `_look_pitch`) and `recoil_max` clamp on target.

## Scope (out)
- Head-bob — parked; motion-feedback polish, can desync feel, not the core win.
- Move-tilt (forward punch / side lean) — parked; same reason.
- State machine (idle/walk/run/jump FSM) — parked; structural, only needed when run/crouch/slide arrive.
- Air-control curves / bunny-hop / coyote / jump-buffer — parked; addon extras, out of current feel ask.
- Per-state FOV — parked; ADS FOV already exists.

## Acceptance (F5 feel-check, user runs)
- Strafe start/stop: noticeable ramp-up + glide-to-stop, not instant snap.
- Overall traversal feels slower/heavier than before, controllable.
- Mouse-look clearly slower than before; same feel if window resized (content_scale_factor norm).
- Fire pistol/rifle: muzzle climbs then springs back and settles (not a flat linear slide). Sustained fire still capped by `recoil_max`; recoil never fights mouse-look (look still fully responsive while recoiling).
- `tools/validate.sh` passes (strict typed GDScript).
- godot-verify: scene loads + renders, no dropped props.

## Skill notes
- `godot-first-person-controller` — yaw body / pitch head, camera-relative WASD: preserve; only the velocity-set + sensitivity lines change.
- `godot-code-rules` — strict typed GDScript; new exports typed; run `tools/validate.sh` before reporting.
- `godot-verify` — mandatory after the .gd change.
- `godot-composition` — keep it in `player.gd` (single controller, one job: feel). Do NOT introduce the addon's FSM/component tree.
- Salvage = REFERENCE patterns only, not drop-in (untyped Godot 3/4). Re-implement clean.

## Decisions captured (user, 2026-06-18)
- Movement model: **adopt accel/decel lerp**.
- Starting move_speed: **4.0** (flagged tune-by-feel placeholder).
- Starting mouse_sensitivity: **0.0016** (~20% slower) + window-scale norm.
- Recoil: **adopt addon spring-lerp feel**.
- Head-bob / move-tilt / FSM: **parked** (none selected).

## Later
- Head-bob + move-tilt camera feedback.
- Movement FSM (enables run/crouch/slide/wallrun).
- Air-control curves, bunny-hop, coyote-time, jump-buffer.
- Per-state FOV (run kick).

## Open questions
None — buildable.
