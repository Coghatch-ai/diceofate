# Shoulder Turret + TargetAcquisition

**Goal** — A rear-facing turret mounted on the player auto-aims and auto-fires at the nearest enemy within a 90° cone behind the player, so threats coming from behind get punished without the player turning around.

## System first (data-driven foundation)

Build a reusable `TargetAcquisition` component in `tools/lib/` BEFORE the turret. The turret is its **first consumer**, not a one-off. Same acquire→LOS→pick loop the enemy shooter does (`enemy_shooter.gd` / `behaviours/shooter_attack.gd`), generalised to "nearest-of-many in an arc" and authored as `.tres`.

- `tools/lib/target_acquisition.gd` → `class_name TargetAcquisitionConfig extends Resource` (DATA):
  - `target_group: String = "enemies"`
  - `arc_half_angle_deg: float = 45.0` (90° total cone)
  - `max_range: float = 30.0`
  - `los_required: bool = true`
  - `selection_rule: int` (enum NEAREST / MOST_CENTRED; v1 default NEAREST)
  - `reacquire_interval: float = 0.0` (0 = re-pick every fire cycle; reserved for decoupling later)
- `tools/lib/target_acquisition.gd` ALSO exposes a stateless helper (or a thin `Node` component) `acquire(origin: Node3D, cfg: TargetAcquisitionConfig) -> Node3D` that:
  1. Gets `get_tree().get_nodes_in_group(cfg.target_group)`.
  2. For each, computes yaw-relative position **reusing the radar math** from `radar_minimap.gd _world_to_radar()` — rotate (dx,dz) by `-origin.rotation.y`; **behind = positive rotated-Z** (radar's `rz` forward-negative convention). In-arc test: `abs(atan2(rx, rz_behind)) <= deg_to_rad(arc_half_angle_deg)` within `max_range`.
  3. LOS-gate each candidate when `los_required` (mirror `can_see_target()`: a `RayCast3D` / `intersect_ray` mask=1 from turret muzzle to enemy centre).
  4. Return the winner per `selection_rule` (NEAREST = min distance), else `null`.

New acquisition behaviour later = edit the `.tres` or add a `selection_rule` branch — no call-site change. The enemy shooter migrating onto this is a **Later** follow-up (optional, not this slice).

## The turret weapon entity

- `entities/weapon/shoulder_turret.tscn` — an **inherited scene off `weapon.tscn`** (same pattern `rifle.tscn` uses) so it IS a `Gun` and reuses the whole firing seam.
- Mounted on the player **body** as a sibling of `WeaponController` (NOT under `Head`) — body yaw `rotation.y` is what the radar math keys off, so the rear arc tracks the body, not the look direction. Small `TurretController` Node (composition, signals up / calls down) drives it; no new autoload.
- Each cycle (a `Timer`, `wait_time = 1.0`):
  1. `var enemy := TargetAcquisition.acquire(turret_muzzle, cfg)`; if `null`, skip.
  2. Orient the turret/muzzle at the enemy via `Basis.looking_at(-forward, Vector3.UP)` (exact mirror of `shooter_attack._fire_at_player`).
  3. Short telegraph (~0.25 s emission/scale tween) so the rear shot reads, then `gun.try_fire()`.
- Fires through the **existing Gun seam**: `gun.cast_data` is set to `pistol_cast.tres`; `try_fire()` spawns the Projectile and stamps the CastData exactly like the player rifle. No firing-path change, no new projectile code.

## Locked decisions (from interview)

- Arc: **45° half-angle** (90° total cone behind).
- Selection: **nearest** enemy in arc. LOS-gated.
- Fire rate / re-acquire: **1.0 s** (one timer drives both).
- CastData: **reuse `pistol_cast.tres`** (yellow, Damage(1)+Knockback).
- Ammo: **infinite** (fire-rate is the only throttle; no HUD change, no `BulletAmmoTracker` on the turret).
- Always-on (no toggle). Telegraph before each shot (rear readability).

## Scope (in)

- `TargetAcquisitionConfig` Resource + `acquire()` helper in `tools/lib/`, reusing the radar yaw-math.
- `turret_acquisition.tres` — first config instance (enemies / 45° / 30 m / LOS / nearest / 1.0 s).
- `shoulder_turret.tscn` (inherited Gun) + `TurretController` node wired onto the player body, rear-facing.
- Turret's Gun `cast_data = pistol_cast.tres`; fires via `try_fire()` on the acquisition cycle with a short telegraph.
- Headless smoke (`tools/smoke_turret.gd`): place 3 enemies (1 in rear arc, 1 in front, 1 in arc but out of range) → assert `acquire()` returns the single in-arc-in-range one; assert `try_fire()` returns true and spawns a projectile when a valid target exists.

## Scope (out)

- Migrating `shooter_attack.gd` onto the shared component — Later; not required to ship the turret.
- Dedicated turret CastData / distinct bullet colour — reuse pistol_cast for v1.
- Ammo pool / HUD for the turret — infinite, nothing to show.
- Lead/prediction — projectile is fast vs arena scale; not needed.
- `MOST_CENTRED` selection rule — field reserved, only NEAREST implemented v1.
- Toggle key / upgrade tiers — always-on POC.

## Acceptance

- `tools/validate.sh` passes (strict-typed; new `.gd` + `.tscn` + `.tres` load).
- `$GODOT --headless --script tools/smoke_turret.gd` → PASS: `acquire()` picks the correct single enemy; out-of-arc / out-of-range / in-front enemies rejected; `try_fire()` true + projectile spawned with a target, no-op with none.
- `godot-verify`: `shoulder_turret.tscn` loads + renders; turret visible on the player rear.
- Human F5 in `firing_yard` / `blast_court`: walk so an enemy is behind you → turret rotates to it, telegraphs, fires a **yellow** bullet that hits/knocks back; an enemy directly in front does NOT get auto-fired at; turret stays silent with no enemy behind.

## Skill notes

- `godot-data-driven-effect-composition` — the `TargetAcquisitionConfig` Resource is an instance of the data-as-resource pattern (`.tres`, never JSON).
- `cast-system` — turret fires an existing CastData via the unchanged Gun stamp seam; no new Effect/resolver.
- `godot-travelling-projectile-3d` — projectile lifecycle unchanged.
- `godot-fps-enemy-combat` — hit/death routes through the existing `apply_damage`/`died` contract via pistol_cast.
- `godot-composition` — `TurretController` is a child component on the player body; signals up / calls down; no autoload.
- `godot-runtime-smoke` — smoke harness pattern for `smoke_turret.gd`.
- `godot-verify` — Transform3D ban: turret orients via `Basis.looking_at` at runtime; the `.tscn` mount uses `position` + `rotation`, never a Transform3D literal.
- `godot-code-rules` — strict typed GDScript; duck-typed LOS/target seams guarded with `has_method` + `@warning_ignore`.

## Later

- Migrate `enemy_shooter` / `shooter_attack` onto `TargetAcquisition` (2nd consumer → proves the system; then consider a `godot-target-acquisition` skill promotion via skill-researcher).
- `MOST_CENTRED` selection rule; `reacquire_interval > 0` to decouple acquisition from fire cadence.
- Dedicated turret bullet identity (colour/VFX); turret upgrade tiers; toggle/aim-down behaviour.
- Lead/prediction if fast enemies outrun the projectile.

## Open questions

None — buildable.
