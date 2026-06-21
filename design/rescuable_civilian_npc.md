# Rescuable Civilian NPC

**Goal** — F5: a distinct civilian figure stands in the firing yard; standing near it for 3 s "rescues" it (it flashes, despawns, player gains +1 life up to the cap); shooting it instead kills it, costs a life, and despawns it.

**Roadmap** — Track B2 (Targets / enemies) of `docs/roadmap/fps_poc.md`. Stationary character only; no movement/patrol/chase AI (parked, needs roadmap amendment — same gate as `firing_yard_npc.md`).

**Decisions applied (from interview):**
- Role = **rescuable civilian** (risk/reward, not a second enemy).
- Rescue = **survive-near timer**: player stays within range 3 s → reward banks.
- Reward = **+1 life via `wave_manager.add_life()`** (already caps at `lives`; no-op at cap — that's fine).
- Shooting it = **penalty**: `wave_manager.lose_life()` + distinct "killed" flash, then despawn.
- **1 civilian**, baked into `firing_yard.tscn` in clear line of sight from spawn.

## Scope (in)
- Extend **existing** `entities/npc/npc.gd` (`Npc`, StaticBody3D) + new `entities/npc/npc.tscn`. Keep `class_name Npc`, keep `signal died(npc)`, keep the duck-typed `on_hit()` seam.
- Scene tree: `Npc` (StaticBody3D) → `CollisionShape3D` (CapsuleShape3D ~1.8 m) + `MeshInstance3D` (capsule or `tools/gen_models.gd` blocky humanoid) in a **friendly colour** from `tools/art_style.gd`, distinct from yellow targets and enemy tints → `RescueArea` (Area3D + CollisionShape3D, ~3 m radius) → `RescueTimer` (Timer, one_shot, 3 s).
- Collision: body `collision_layer = 8`, `collision_mask = 0` (shootable like targets/enemies). `RescueArea` masks the **player** layer only (read player's layer from `player.tscn`; do NOT collide with enemies/projectiles).
- **DI for WaveManager** — `@export var wave_manager: WaveManager` on `npc.gd`, injected by `firing_yard.gd` in `_ready()` (the level root already holds `wave_manager`; it injects the same ref into the NPC). NO `find_child`/`has_method` lookup — reuses the exact pattern `FiringYard` already uses. Null-guard before calling.
- **Rescue flow** (signals up / calls down): `RescueArea.body_entered` → if `body.is_in_group("player")` start `RescueTimer`; `body_exited` (player) → stop/reset timer. `RescueTimer.timeout` → `_rescue()`: `wave_manager.add_life()`, play "saved" flash (e.g. green emission tween), `died.emit(self)`, `queue_free()`.
- **Shoot flow** — `on_hit()` becomes: `wave_manager.lose_life()` (null-guarded), "killed" flash (red), `died.emit(self)`, `queue_free()`. (Distinct flash colour from rescue.)
- Bake **1 `Npc`** into `firing_yard.tscn` on the open mid-floor ahead of spawn (player at ~(24,1,30) facing −Z), in line of sight, not behind cover, not overlapping targets/platforms; capsule centre at y ≈ 0.9. Wire its `wave_manager` from `firing_yard.gd`.

## Scope (out)
- Movement / patrol / chase / awareness AI — out of roadmap scope; parked.
- Sourced animated `.glb` character + idle anim — Later (greybox-first; swap is a separate slice, see `firing_yard_npc.md` Slice 2).
- Rescue progress bar / HUD indicator — Later (timer is invisible this slice; verify by counting lives).
- Press-to-interact input action — cut (timer chosen instead).
- Multiple civilians / spawning via WaveManager / per-wave civilians — Later.
- Abstract HitReceiver/Damagable base — **forbidden**; use the duck-typed `on_hit()` seam (tech_debt.md #1).

## Acceptance
- F5 (or F6 on `firing_yard.tscn`): one civilian figure stands ahead of spawn, friendly-coloured, visibly NOT a target/enemy, in line of sight.
- Walk up to it and stay ~3 s → it flashes "saved", despawns, and the lives HUD increases by 1 (no increase if already at max — acceptable).
- Leaving range before 3 s → no reward; re-entering restarts the timer.
- Shooting it → "killed" flash, despawns, lives HUD decreases by 1.
- No orphan nodes after despawn (either path); `died` fires once; node count sane.
- `tools/validate.sh` passes; `godot-verify` passes on `main.tscn` and `firing_yard.tscn`.

## Skill notes
- **godot-fps-enemy-combat** — shootability via the existing duck-typed `on_hit()` (projectile already calls it); reparent-before-free only if a death SFX is added (none this slice). Keep `died` idempotent (emit once before free).
- **godot-composition** — NPC reacts to its own hit/rescue (calls down to WaveManager via injected `@export`; signals up via `died`). WaveManager is **injected by the level root**, not reached via `get_parent()`/`find_child` (rule 5, DI) — mirrors `FiringYard.wave_manager`. Modularize on demand only: no StateMachine/components (it's stationary).
- **godot-procedural-model / godot-art-style** — greybox figure colour from `tools/art_style.gd`, distinct from target yellow + enemy tints.
- **godot-code-rules** — strict typed GDScript; null-guard the injected `wave_manager`; gate `tools/validate.sh`.
- **godot-verify** — both rescue and shoot change runtime state + lives; verify each path renders and the scene still runs.
- NOT reusing enemy nav/StateMachine/perception (stationary, no need) — deliberately omitted to keep the slice small.

## Later
- Sourced animated `.glb` civilian + idle (see `firing_yard_npc.md` Slice 2).
- Rescue-progress HUD / radius indicator.
- Death/rescue SFX + VFX beyond the flash.
- Civilians spawned by WaveManager per-wave; multiple at once; civilian variety.
- Enemies targeting the civilian (objective-defense variant).

## Open questions
None blocking. Reward at life-cap is a silent no-op (accepted). Rescue timer is invisible this slice (verify via lives count).
