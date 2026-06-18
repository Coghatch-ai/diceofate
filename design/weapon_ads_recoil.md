# Weapon ADS Zoom + Recoil + Spread

**Goal** — Holding right-mouse aims down sights (camera zooms in, shots go dead-straight); each
shot kicks the view up and scatters the bullet in a cone — pistol and rifle feel different.

## Scope (in)
- New input action `aim` = right mouse button (button_index 2) in `project.godot`.
- **ADS** on `player.gd`: hold `aim` → tween `$Head/Camera3D.fov` from hip 75 → ADS 55 over 0.15 s;
  release → tween back. Move speed scaled to 0.6× while aiming. Crosshair hidden while aiming
  (`_crosshair.visible = false`) — restore on release.
- **Recoil** on `player.gd`: each `fired` adds an upward pitch impulse that ACCUMULATES on sustained
  fire and decays back to zero when not firing. Applied as a separate `_recoil_pitch` offset added
  to the head's mouse-look pitch each `_physics_process` — never overwrites mouse-look. Tiny random
  yaw per shot (±`recoil_yaw`). Replaces the current one-shot `_do_camera_kick()` tween.
- **Spread** in `weapon.gd._fire()`: before launch, perturb the projectile's heading by a random
  cone half-angle. Hip uses `spread_hip`; while aiming the host passes a tightened value toward 0.
  Weapon learns aim state via a setter `set_aiming(bool)` the player calls on `aim` press/release
  for the active weapon only.
- **Per-weapon data** — new exports so pistol vs rifle differ via the `.tscn`, no new code:
  - `weapon.gd`: `spread_hip: float = 2.5` (deg), `spread_ads: float = 0.3`, `recoil_pitch: float = 0.012` (rad/shot), `recoil_yaw: float = 0.004`.
  - `rifle.tscn` overrides: `spread_hip = 4.0`, `spread_ads = 0.6`, `recoil_pitch = 0.02`, `recoil_yaw = 0.008` (kicks more, scatters more — auto-fire trade-off).
  - `player.gd`: `ads_fov: float = 55.0`, `hip_fov: float = 75.0`, `ads_tween_time: float = 0.15`, `ads_move_scale: float = 0.6`, `recoil_recover: float = 8.0` (decay rate), `recoil_max: float = 0.18` (rad cap).
- **Recoil exposure to player**: weapon emits its `recoil_pitch`/`recoil_yaw` with the existing
  `fired` signal OR player reads them off `_active_weapon` in `_on_weapon_fired()` (reads exports —
  simplest, no signal change). Player owns accumulation + decay (it owns the head).
- **ADS cancels** on weapon swap (player calls `set_aiming(false)` + snaps `fov` to hip in
  `_swap_weapon()`); ADS allowed during reload (cosmetic only — firing already gated by `_reloading`).

## Scope (out)
- Scope/iron-sight overlay art — none; ADS is pure FOV zoom (POC, no scope art in scope).
- Spread-grows-with-sustained-fire (bloom) — recoil already escalates; bloom is parked, keep spread flat per-state.
- Particles / new VFX — banned by roadmap; recoil reuses head pitch, no new visuals.
- New weapons, new HP/damage model, ammo changes — untouched.
- ADS view-model reposition (gun pulled to centre) — cosmetic, parked; FOV zoom alone reads.

## Acceptance (F5, one run)
- Hold RMB → view zooms in (narrower FOV), move visibly slower, crosshair hidden; release → zooms
  back, crosshair returns. No blur, pixelation + outlines intact at both FOVs.
- Hip-fire pistol at a wall/target: bullets visibly scatter in a small cone; view kicks up per shot
  and climbs on held fire, then settles back down when you stop. Mouse-look still works during recoil.
- ADS-fire pistol: bullets land tight/dead-centre; recoil still present but shots accurate.
- Swap to rifle (Q): rifle kicks harder + scatters more than pistol; aiming tightens it the same way.
- ADS active, then press Q → aim cancels, FOV snaps to hip, swap completes normally.
- `tools/validate.sh` clean; godot-verify: scenes load + render (avg luminance non-black).

## Skill notes
- `godot-first-person-controller` — recoil/ADS live on the Head/eye-camera rig; FOV on the
  perspective `$Head/Camera3D` only; recoil offset must ADD to mouse-look pitch, not replace it.
- `godot-3d-pixelation` — FOV change is on the SubViewport eye-camera; downscale unchanged, so look
  holds. Confirm no resolution/SubViewport edits.
- `godot-screen-effects` — outline rig samples depth/normal, FOV-agnostic; verify outlines survive at ADS FOV (no shader edits expected).
- `godot-travelling-projectile-3d` — spread perturbs the spawn basis BEFORE launch in `weapon._fire()`; magnet steering (existing) runs after and may override — acceptable.
- `godot-composition` — signals up / calls down: player owns head+recoil accumulation; weapon owns spread + per-weapon data; player calls `set_aiming()` down to active weapon.
- `godot-code-rules` — strict typed GDScript; new exports typed; gate `tools/validate.sh`.
- `godot-verify` — mandatory after .gd/.tscn edits.

## Later
- ADS bloom (spread grows on sustained fire), recoil pattern curves (not just up).
- ADS view-model recentre + scope overlay art.
- Per-weapon FOV (sniper deeper zoom); FOV-based mouse-sensitivity scaling while aiming.

## Open questions
None — all decisions applied above; pistol/rifle values are starting points godot-dev exposes as exports for F5 tuning.
