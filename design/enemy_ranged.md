# Ranged Enemy (5th type — shooter)

**Goal** — A distinct new enemy that stops at a distance and fires a slow, dodgeable projectile at the player; a hit costs a life via the same seam a touch uses; it's killable like every other enemy.

## Design decisions (applied — no interview)

- **Behaviour: stop-and-shoot, NOT kite.** Smallest build. Reuses the existing node-FSM untouched: ChaseState already branches Chase→Attack at `dist <= attack_range`; AttackState already `stop()`s and calls `perform_attack()` on the cooldown gate. The ranged enemy just sets a large `attack_range` (preferred range) and overrides `perform_attack()` to FIRE instead of touch — exactly the override pattern `enemy_magnet.gd` already uses. No new FSM state.
- **Killable contract kept verbatim.** Inherited from `enemy.gd`: `health`/`score_value`/`died`/`on_hit()` unchanged. One-shot (`health = 1`) like grunt/runner.
- **Hit = life, no new damage model.** The enemy projectile, on hitting the player, calls a duck-typed `report_ranged_hit()` on the firing enemy, which emits the existing `touched_player(self)` — the SAME seam `WaveManager._on_enemy_touched_player` already handles (life loss + re-seed). Zero WaveManager change.
- **Telegraph for fairness.** A wind-up before each shot: reuse the scale-lunge tween shape, recolour the mesh emission to a bright warn flash over ~0.4 s, THEN spawn the projectile. Projectile speed `12` (vs player's `30`) — slow enough to strafe out of.
- **LOS gate on fire.** Override re-checks `can_see_target()` before firing (AttackState alone doesn't), so it won't blind-fire through walls.
- **Colour: new `ENEMY_SHOOTER_*` swatch — acid-yellow/green ramp.** Maximally distinct from crimson/orange/violet/cyan. Code-tint via `set_surface_override_material` (NOT a `.tscn` override), per `enemy_runner.gd`.
- **5th wave roll.** `enemy_scene_e` + `shooter_ratio` in `wave_manager.gd`, mirroring the b/c/d branches. H19 deterministic-grunt-first-wave intact (shooter only enters via the escalation roll, never seeds/re-seeds).

## Scope (in)

- `tools/art_style.gd`: add `ENEMY_SHOOTER_DARK/MID/LIGHT` (acid-yellow-green ramp, documented saturation exception like the others).
- `entities/enemy/enemy_shooter.gd` (code-tint, copy `enemy_runner.gd` shape): `super._ready()`, `score_value = 2`, tint, `add_to_group` not needed; override `perform_attack()` → telegraph tween then `_fire_at_player()`; export `@export var projectile_scene: PackedScene`, `@export var projectile_speed: float = 12.0`, `@export var telegraph_time: float = 0.4`.
- `entities/enemy/enemy_shooter.tscn` (inherited from `enemy.tscn`): script swap; `attack_range = 9.0` (preferred fire distance), `escape_range = 16.0` (keep), `attack_cooldown = 1.6`, `detect_range = 14.0`. Add a `Muzzle` `Marker3D` child at ~chest height (`position = (0, 1.4, -0.4)`).
- `entities/projectile/enemy_projectile.tscn` (new, copy `projectile.tscn`): `collision_layer = 16` (new enemy-bullet bit), `collision_mask = 3` (world + player; NOT enemy layer 8, so it can't hit other enemies and player bullets can't hit it). Recolour mesh to the shooter swatch. Reuses `projectile.gd` as-is — its duck-typed `on_hit()` path already no-ops on bodies without `on_hit()`, and the player-hit life seam is wired in `enemy_shooter.gd` (see below), not in the projectile.
- `enemy_shooter.gd._fire_at_player()`: instance `projectile_scene`, add to `current_scene`, `top_level`, aim `-Z` at player capsule centre (`+0.9 y`, like the magnet aim), set `speed = projectile_speed`; connect the projectile's `hit(body)` signal → if `body` is in group `"player"`, call `report_ranged_hit()` on self.
- `enemy_shooter.gd.report_ranged_hit()`: `touched_player.emit(self)` (reuses the touch→life seam; magnet-style override means base touch is bypassed).
- `levels/wave_manager.gd`: `@export var enemy_scene_e: PackedScene`, `@export var shooter_ratio: float = 0.1`; add the 5th branch to the `_spawn_one` random roll (priority before runner, after tank, consistent with existing chain). Lower `magnet_ratio`/`runner_ratio` slightly so ratios stay < 1.0.
- `levels/firing_yard.tscn`: wire `enemy_scene_e = enemy_shooter.tscn` + `shooter_ratio` on the WaveManager node (mirrors `enemy_scene_d` wiring at lines 706–707).

## Scope (out)

- Kiting / retreat behaviour — stop-and-shoot is enough to read as "ranged"; kite = new FSM state, parked.
- Projectile arc/gravity, lead-the-target prediction — straight slow shot is dodgeable and simpler.
- New HP/damage model — a life stays the health unit (POC guardrail).
- Particles / muzzle flash on the enemy — emission flash on the body is the only tell (no VFX beyond the sanctioned outline pass).
- Per-shot SFX for the enemy — out for this slice (parked; can reuse `godot-audio` one-shot later).

## Acceptance (observable, F5)

1. Run opens with 2 grunts (H19 intact — no shooter at seed).
2. Kill into escalation → an **acid-yellow/green** enemy appears, visibly distinct from grunt/runner/tank/magnet.
3. Shooter stops at ~9 m from the player (does NOT walk into melee contact) and, with line of sight, flashes a wind-up then fires a slow glowing projectile that travels toward the player.
4. Standing still in the line → projectile hits → **a life is lost + the run re-seeds** (same as a touch). Strafing sideways dodges it (speed 12 is beatable).
5. Shooter behind a wall does NOT fire (LOS gate); player bullets still kill the shooter in one shot; its kill feeds SCORE/HUD/escalation.
6. Enemy projectiles do NOT damage or despawn on other enemies; player projectiles still hit all enemies normally.
7. `tools/validate.sh` clean; godot-verify all layers pass.

## Skill notes

- `godot-enemy-ai` — reuse the node-FSM; the ranged behaviour is a `perform_attack()` override on the inherited enemy, NOT a new state (mirrors `enemy_magnet.gd`).
- `godot-fps-enemy-combat` — keep `health`/`score_value`/`died`/`on_hit()` verbatim so the shooter stays shootable; connect death idempotently.
- `godot-travelling-projectile-3d` — the enemy bullet reuses `projectile.gd` (spawn→`top_level`→move −Z→despawn). MIND collision: enemy bullet `layer 16` / `mask 3`; player bullet stays `layer 4` / `mask 9`.
- `godot-composition` — signals up (`touched_player`), calls down; the projectile→enemy→WaveManager chain reuses the existing touch seam, no new manager wiring.
- `godot-art-style` — add the `ENEMY_SHOOTER_*` swatch to `art_style.gd`; never inline the Color elsewhere.
- `godot-code-rules` — strict typed GDScript; gate `tools/validate.sh`.
- `godot-verify` — `.tscn`/`.gd` load + render check; confirm the new projectile renders and the enemy is visibly tinted.

## Later

- Shooter kite/retreat FSM state (keeps distance actively).
- Enemy fire SFX + a brighter telegraph cue.
- Projectile arc / target leading for higher difficulty.
- Per-type difficulty ratios that escalate over the run.

## Open questions

None — buildable as one slice.
