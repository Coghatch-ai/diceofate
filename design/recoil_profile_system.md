# RecoilProfile System (data-driven per-shot recoil pattern)

**Goal** — Each bullet type kicks with its own authored climb PATTERN (per-axis curve scaling per-shot impulse), tuned by editing a `.tres` — no firing-path change. First entry = the Rifle's current bullets.

## System first (data-driven foundation, then the feature)
The feature ("better recoil") is the FIRST ENTRY in a `RecoilProfile` resource system, mirroring the existing `CastData` pattern (`godot-data-driven-effect-composition`). New recoil feel = new `.tres`. The existing two-stage spring stays as baseline/fallback; the profile only shapes the per-shot impulse SIZE fed into it. A `RecoilProfile` with null curves reproduces today's flat behaviour exactly (no regression).

## Where it plugs in (grounded in real files)
Current path (verified): `gun.gd` exports scalar `recoil_pitch`/`recoil_yaw` → `weapon_controller.gd` `_on_gun_fired` adds impulse to `_recoil_target_pitch/yaw` → `update_recoil` two-stage spring lerp + `recoil_max` clamp → `player.gd` reads offsets, sums ADDITIVE on `_head.rotation.x` (`_look_pitch + _recoil_pitch`) and `rotation.y`. Spring lives in `weapon_controller`, NOT player. Accuracy (spread) is ALREADY separate in `gun._fire()`.

## RecoilProfile resource (DATA)
New file `tools/lib/recoil/recoil_profile.gd`, `class_name RecoilProfile extends Resource`:
- `@export pitch_curve: Curve` — climb shape over consecutive-shot index (0..1 X → impulse scale Y). Null = flat 1.0 (current behaviour).
- `@export yaw_curve: Curve` — horizontal sway shape per shot index. Null = flat 1.0.
- `@export pitch_amplitude: float = 0.08` — base pitch impulse (rad), scaled by `pitch_curve`. (Decouples shape from magnitude — transcript pt #3.)
- `@export yaw_amplitude: float = 0.03` — base yaw jitter (rad), scaled by `yaw_curve`.
- `@export shots_to_plateau: int = 6` — consecutive shots the curve spans before it holds at its end value (curve X normalised by this).
- `@export yaw_random: float = 0.5` — fraction of yaw impulse that is randomised `±` (keeps the existing per-shot flip; 1.0 = fully random like today, 0.0 = deterministic pattern).

Authored `.tres` (one per bullet identity), in `entities/weapon/recoil/`: one per CastData slot — e.g. `electric_recoil.tres`, `fire_recoil.tres`, etc. Start by porting current scalar values into flat-curve profiles, then author distinct climbs (e.g. kinetic = hard vertical climb; rapid = light climb + S-shaped yaw walk).

## Attachment (decision: per-CastData slot)
`CastData` gets `@export recoil_profile: RecoilProfile` (null = fall back to the Gun's scalar `recoil_pitch`/`recoil_yaw`, current behaviour). Mirrors per-bullet `bullet_color`/effects identity. Active slot's profile drives the kick; switching Q/E/R/T/Y switches recoil feel for free.

## How the curve layers on the spring (decision: LAYER, not replace)
- `weapon_controller` tracks `_shot_index: int` (consecutive shots) + a no-fire reset timer (`_shots_reset_after` seconds idle → index back to 0).
- `_on_gun_fired` reads the active `CastData.recoil_profile` (via gun): if non-null, computes `t = clampf(float(_shot_index)/maxf(1,profile.shots_to_plateau-1), 0, 1)`; `pitch_impulse = profile.pitch_amplitude * profile.pitch_curve.sample(t)` (null curve → ×1.0); yaw similarly, split into deterministic part + `yaw_random` randomised part. If profile null → keep current scalar path.
- Impulse still added to `_recoil_target_pitch/yaw` then `recoil_max`-clamped; the two-stage spring (`update_recoil`) is UNCHANGED — it owns settle/decay/recovery.
- `_shot_index += 1` per shot; reset on idle gap.

## Additive-on-head guarantee (CRITICAL — do NOT regress)
The profile feeds ONLY the impulse magnitude into the SAME `_recoil_target_*` accumulators. `player.gd` still sums recoil additively onto `_look_pitch`/`rotation.y` and never overwrites mouse-look (roadmap I2). The transcript technique that OVERWRITES weapon rotation is explicitly NOT adopted. State this in the build task.

## Scope (in) — ONE slice
- `RecoilProfile` resource (fields above) + `tools/lib/recoil/`.
- `CastData` gains `recoil_profile` export (null-safe fallback).
- `weapon_controller` `_on_gun_fired` reads active profile, samples curve by shot-index, computes layered impulse; add `_shot_index` + idle-reset; spring untouched.
- Port current 5 bullet feels into flat-curve `.tres` (no behaviour change baseline) + author ≥1 distinct climb (kinetic) to prove the pattern reads.
- Extend `tools/smoke_cast.gd` (or new `tools/smoke_recoil.gd`) headless assert: load a profile, drive N consecutive `_on_gun_fired`, assert impulse for shot 4 > shot 1 (climb), assert null-profile path == current scalar, assert recoil never written onto `_look_pitch`.

## Scope (out)
- ADS-specific recoil — parked; ADS keeps affecting accuracy only (current). One field later.
- Spring REPLACEMENT (profile owning recovery) — not adopted; layering is smaller + keeps proven spring.
- Camera shake on fire — separate feel add (transcript #4), parked.
- Recoil-recovery-to-origin pull (auto counter to first-shot aim) — parked.
- New weapons / new HP / spread-bloom — untouched.

## Acceptance (validate + smoke + one F5 look)
- `tools/validate.sh` clean (strict typed; new `.gd` + `.tres` load).
- Smoke: consecutive-shot impulse climbs per `pitch_curve`; null profile == current scalar; no write to `_look_pitch`. Exit 0.
- godot-verify: weapon/rifle scenes load + render; bullets fire.
- F5: hold-fire kinetic bullet → muzzle climbs along authored shape (not uniform), settles via spring when released; switch to a flat-profile bullet → kicks like today; mouse-look fully responsive throughout (recoil never fights look); stop firing briefly → climb resets.

## Skill notes
- `cast-system` — `recoil_profile` is a new `CastData` export; `.tres` authoring + smoke-from-loaded-resource convention apply. NOT a new Effect.
- `godot-first-person-controller` — recoil offset ADDS to head pitch / body yaw; never replaces `_look_pitch`. I2.
- `godot-composition` — RecoilProfile = data Resource; spring stays in `weapon_controller` (calls down); player owns head. No autoload/manager.
- `godot-code-rules` — strict typed; `Curve.sample` null-guarded; new exports typed.
- `godot-runtime-smoke` — headless impulse-climb assert wired into validate.sh.
- `godot-fps-game-feel` — L3 "recoil reads on fire" criterion this serves; periodic, not a gate.

## Later
- ADS recoil multiplier on the profile (reduce/tighten while aiming).
- Camera shake on fire (additive trauma, additive-only).
- Recovery-pull-to-origin (CS-style recoil compensation feel).
- Promote curve-RecoilProfile to a framework `godot-fps-recoil` skill IF it proves reusable across weapons/engines.
- Per-shot SFX/VFX intensity driven off the same shot-index.

## Open questions
None — buildable.

## Decisions captured (user, 2026-06-25)
- Attach: per-CastData bullet slot; gun scalar = fallback.
- Curve LAYERS on spring (profile shapes impulse size; spring owns settle/decay).
- Climb curve spans 6 shots (`shots_to_plateau` default).
- One profile for v1; ADS recoil parked.
