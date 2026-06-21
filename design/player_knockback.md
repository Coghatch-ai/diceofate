# Player Knockback on Enemy Contact

**Goal** — when an enemy attack-touches the player, the player is shoved away from that enemy, giving physical + directional feedback about where the hit came from.

## Scope (in)
- New enemy signal `bumped_player(enemy: Enemy)` emitted from base `Enemy.perform_attack()` (every attack-range touch), alongside the existing `touched_player`. Carries the enemy so the receiver knows the hit source.
  - Inherited by grunt/runner/tank (use base `perform_attack`). Magnet + shooter override `perform_attack` — add the same `bumped_player.emit(self)` in their overrides so all five enemy types push.
- New player method `apply_knockback(hitter_pos: Vector3)` — mirrors the enemy's exact duck-typed signature/feel: push direction = `global_position - hitter_pos` (flattened to XZ, fallback to player facing if zero), sharp impulse decaying to zero over a short stun window during which player movement input is ignored. Reuse enemy tunables as the reference values (`_KNOCKBACK_SPEED = 6.0`, `_STUN_DURATION = 0.15`); expose as player `@export`s so they tune independently.
- `wave_manager.gd` wires it: in `_connect_enemy`, connect `bumped_player` to a handler that calls `player.apply_knockback(enemy.global_position)` (duck-typed, guard `has_method`). Existing `touched_player` → `lose_life()` path is untouched.

## Scope (out)
- Life-loss-only push — rejected: `lose_life()` teleports the player to spawn + frees all enemies the same frame, so the shove would be invisible and unverifiable.
- Camera kick / screen shake / screen-edge directional indicator — parked; pure impulse first.
- Shooter knockback from projectile travel direction — POC uses enemy `global_position` as source (good enough); projectile-direction is a Later.
- @abstract `HitReceiver` base for the seam — parked tech debt (`design/tech_debt.md` #1); keep duck-typed.
- Changing what costs a life / decoupling bump from the attack schedule — out; bump rides the existing attack telegraph.

## Acceptance
- Walk the player into a grunt's attack range: player is visibly pushed back away from the grunt, with a brief (~0.15s) loss of movement control, then recovers.
- Push direction is away from the enemy regardless of which side the contact came from (approach from front vs behind → opposite shove).
- All five enemy types (grunt, runner, tank, magnet, shooter) push the player on contact.
- Life-loss / respawn behaviour unchanged from before (lives still tick on the existing schedule; run still loses at 0).
- `tools/validate.sh` passes.

## Skill notes
- `godot-composition` — duck-typed `apply_knockback(hitter_pos)` seam, signals up (enemy `bumped_player`) / calls down (wave_manager → player); no new base class.
- `godot-code-rules` — strict typed GDScript; `@warning_ignore` on the duck-typed `has_method`/call seam, matching the enemy's existing `apply_knockback` pattern.
- `godot-verify` — run after the change; confirm the scene still loads and the push renders.
- Mirror `entities/enemy/enemy.gd` `apply_knockback` / `_physics_process` stun-decay block on the player side (same shape: stun timer gates input, knockback velocity decays via `move_toward`, applied through `move_and_slide`). Player already calls `move_and_slide()` once per frame — fold the knockback override into that path, do not add a second call.

## Files changed
- `entities/enemy/enemy.gd` — add `bumped_player` signal + emit in `perform_attack`.
- `entities/enemy/enemy_magnet.gd`, `entities/enemy/enemy_shooter.gd` — emit `bumped_player.emit(self)` in their `perform_attack` overrides.
- `entities/player/player.gd` — add `apply_knockback(hitter_pos)` + stun/knockback state in `_physics_process` (skip movement input while stunned).
- `levels/wave_manager.gd` — connect `bumped_player` in `_connect_enemy`, relay to player.

## Later
- Camera kick away from hit; screen shake.
- Screen-edge directional damage indicator (`godot-screen-effects`).
- Shooter knockback sourced from projectile travel direction, not enemy position.
- Per-enemy-type knockback strength (tank shoves harder).

## Open questions
- None.
