# FPS Weapon & Projectile (A3)

**Goal** — F5: clicking fires a projectile that visibly travels forward from the player's eye-line and despawns on range or hit; holding fire is capped by a cooldown.

## Scope (in)
- **Add the `shoot` input action** to `project.godot` Input Map (deadzone 0.5): primary bind = left mouse button (`MOUSE_BUTTON_LEFT`). This is the A3 build-time action named by the skills but not yet in the map.
- Build `entities/projectile/projectile.tscn` per skill `godot-travelling-projectile-3d`: root `Projectile` (Area3D) → `CollisionShape3D` (small SphereShape3D) + a visible `MeshInstance3D` (small bright sphere so it reads in pixel-art). Put the projectile on its own collision **layer**; set its **mask** to the layers it should hit (walls + targets), excluding the player's layer so it never hits the firer.
- `entities/projectile/projectile.gd` per the skill: travel along local −Z each `_physics_process`, despawn at `max_range`, `body_entered` → emit `hit(body)` → `queue_free()`. `top_level` set at spawn.
- Build the `Weapon` (Node3D) sub-tree per the skill: `Muzzle` (Marker3D, local −Z forward) + `Cooldown` (Timer, one_shot). `weapon.gd` with `try_fire()` gated by the Timer; spawns the projectile into `get_tree().current_scene`, `top_level = true`, `global_transform = muzzle.global_transform`.
- **Mount the Weapon under the player's `Head`** (so shots travel along the look direction) and have `player.gd` call `_weapon.try_fire()` on `Input.is_action_pressed("shoot")`.

## Scope (out)
- Object pooling, muzzle-flash / impact VFX, projectile gravity/arc, recoil — parked (skill's Later).
- Hitscan / raycast firing — explicitly not this skill's design.
- Ammo / reload / weapon switching — roadmap out-of-scope.
- Damage numbers / Health — B2 targets are one-hit despawn (see `design/fps_targets.md`); no Health component.
- Visible first-person weapon viewmodel / arms — Later.

## Acceptance
- F5: left-click spawns a projectile at the muzzle that **visibly travels** forward along where you look (not an instant hit).
- Holding fire is capped at `fire_rate` (shots don't come every frame).
- Projectiles despawn after `max_range` — node count does not climb forever (watch the remote tree).
- A projectile entering a wall (or a B2 target, once built) fires the `hit` signal and despawns.
- Projectiles travel in world space (don't drag when the player moves after firing) and never hit the firer or each other.
- `tools/validate.sh` passes; `godot-verify` passes on `main.tscn`.

## Skill notes
- `godot-travelling-projectile-3d` — the two-component design (Weapon firing component + travelling Projectile), Timer-gated cadence, `top_level` detach, collision layer/mask discipline. NOT hitscan.
- `godot-composition` — Weapon and Projectile are independent components; host calls down (`try_fire`), projectile signals up (`hit`); no component reaches into its host.
- `godot-first-person-controller` — mount the Weapon/Muzzle under the `Head`; copy the muzzle `global_transform` so shots follow the look direction.
- `godot-code-rules` — strict typed GDScript; type `instantiate() as Projectile`; gate `tools/validate.sh`.
- `godot-verify` — firing changes runtime behaviour; verify it renders and runs.

## Later
- Object pooling; muzzle-flash + impact VFX; recoil; arc/gravity.
- First-person weapon viewmodel.

## Open questions
None. (Projectile collision layer numbers and the wall/target layers are an implementation detail for godot-dev; the player must be excluded from the mask.)
