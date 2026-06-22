# Flying Enemy (6th type — Stinger, melee dive-bomber)

**Goal** — An airborne enemy hovers high above the arena, forcing the player to look and aim UP; on a clear sight-line it swoops down to body-check the player (costs a life via the existing touch seam) then pulls back up to hover. Killable in one shot like every other light enemy.

## Decisions applied (from interview — user override recorded)

- **Attack = melee dive-bomb** (user picked; ranged-from-above was the smaller alt, declined). The flyer hovers, then on the cooldown gate dives straight at the player, body-contacts, and returns to hover.
- **Hover height ~6 m** (recommended default; user left blank = accept). `@export var hover_height: float = 6.0` so it's tunable per arena without a code edit.
- **Bob + slow XZ-track applied** (recommended): hovers above the navmesh, ignores gravity, gently bobs vertically and tracks the player horizontally at a slow speed so it reads as a moving aim-up target, never landing.
- **Killable contract kept VERBATIM**: `health`/`score_value`/`died`/`on_hit()` inherited from `enemy.gd` unchanged. One-shot (`health = 1`). `score_value = 3` (a bit above runner/shooter — it's the most annoying light target to hit, being airborne and mobile).
- **No new FSM state.** Same trick as `enemy_shooter`/`enemy_magnet`: reuse the node-FSM untouched (Chase→Attack branches at `dist <= attack_range`; AttackState `stop()`s + calls `perform_attack()` on cooldown). The flyer subclass overrides MOVEMENT (`move_along_path`/`stop` → hover+bob, no gravity, no floor-snap) and `perform_attack()` (→ dive tween). `attack_range` becomes the dive-trigger distance.
- **Colour = new `ENEMY_STINGER_*` swatch (violet-grey "airborne" ramp).** Distinct from crimson/orange/violet-tank/cyan/acid. Tank already uses violet — Stinger goes desaturated grey-violet + a bright cyan-white edge highlight so it reads "metallic/flying" not "tank". Code-tint via `set_surface_override_material`, per `enemy_runner.gd`.
- **6th wave roll**: `enemy_scene_f` + `flyer_ratio` in `wave_manager.gd`, mirroring the b/c/d/e branches. Seed/re-seed force-grunt path untouched (flyer only enters via escalation roll).

## Scope (in)

- `tools/art_style.gd`: add `ENEMY_STINGER_DARK/MID/LIGHT` (grey-violet ramp + bright edge), documented like the others.
- `entities/enemy/enemy_flying.gd` (`extends Enemy`, copy `enemy_shooter.gd` shape):
  - `super._ready()`, `score_value = 3`, apply Stinger tint, `_target_y` set to `hover_height` so the body rises off the floor spawn.
  - `@export var hover_height: float = 6.0`, `@export var bob_amplitude: float = 0.4`, `@export var bob_speed: float = 2.0`, `@export var hover_track_speed: float = 2.0`, `@export var dive_time: float = 0.45`, `@export var rise_time: float = 0.6`.
  - **Override `move_along_path(speed, delta)`**: ignore gravity; drive XZ toward the nav next-point at `hover_track_speed` (reuse `_nav.get_next_path_position()` for wall-aware horizontal tracking), set Y toward `hover_height + sin(time)*bob_amplitude`. `velocity.y` is computed here, NOT from gravity. Keep `look_at` facing the player (flatten pitch).
  - **Override `stop(delta)`**: same hover/bob hold but zero XZ drift (used by AttackState between dives).
  - **Override `perform_attack()`**: guard `_diving`; LOS-gate via `can_see_target()` (won't dive through walls); a Tween that (1) lunges the body down to the player's capsule centre over `dive_time`, fires `touched_player.emit(self)` + `bumped_player.emit(self)` at the bottom (the touch→life seam, magnet-style), then (2) rises back to `hover_height` over `rise_time`. Guard `is_instance_valid(self)` after the emit (the life seam may free the enemy on level-advance — same guard `enemy.gd:perform_attack` already uses).
- `entities/enemy/enemy_flying.tscn` (inherited from `enemy.tscn`): script swap; `attack_range = 7.0` (dive-trigger distance — flyer commits the dive from a distance), `detect_range = 16.0`, `escape_range = 20.0`, `attack_cooldown = 2.0` (recovery between dives). Tint applied in code, not a `.tscn` override.
- `levels/wave_manager.gd`: `@export var enemy_scene_f: PackedScene`, `@export var flyer_ratio: float = 0.1`; add the 6th branch to the `_spawn_one` roll, FIRST in the priority chain (before shooter), consistent with the existing `roll < a + b + c + …` cumulative pattern. Lower one existing ratio slightly so the cumulative stays < 1.0.
- `levels/firing_yard.tscn` (and `ruined_warehouse.tscn` if it wires the type list): set `enemy_scene_f = enemy_flying.tscn` + `flyer_ratio` on the WaveManager node, mirroring the `enemy_scene_e` wiring.

## Scope (out)

- Ranged attack from above — user chose melee dive; ranged variant parked.
- New FSM dive/return STATES — the dive is a `perform_attack()` tween, not new states (keeps it one slice; matches shooter/magnet).
- Vertical NAVIGATION / 3D pathfinding — flyer tracks the player in XZ via the existing flat navmesh and just holds an altitude; it does NOT path through 3D airspace or over walls vertically. Good enough to read "flying".
- New HP/damage model — a life stays the health unit; one shot kills the flyer.
- Dive VFX / wind-up particles / per-dive SFX — emission flash + the dive motion is the only tell this slice (parked; reuse `godot-oneshot-vfx`/`godot-audio` later).
- Flock/swarm behaviour, multiple flyers coordinating — single-unit behaviour only.

## Acceptance (observable, F5)

1. Run opens with the normal seed (grunt/magnet — H19 intact, no flyer at seed).
2. Kill into escalation → a **grey-violet airborne** enemy appears, hovering ~6 m up, visibly distinct from all 5 grounded types; the player must tilt the camera UP to see/aim it.
3. The flyer bobs and drifts to track the player horizontally; it never lands or touches the floor.
4. With line of sight and within ~7 m horizontally, it **dives down to the player, then pulls back up to hover**; the dive is paced by `attack_cooldown` (no faster than one dive / 2 s).
5. Standing where it dives → **a life is lost + the run re-seeds** (same seam as a ground touch). Side-stepping the dive avoids the hit.
6. Flyer behind a wall does NOT dive (LOS gate). A player bullet aimed UP kills it in one shot; its kill feeds SCORE/HUD/escalation (`score_value = 3`).
7. `tools/validate.sh` clean; `godot-verify` all layers pass (flyer renders, is tinted, hovers off the floor at runtime).

## Skill notes

- `godot-enemy-ai` — reuse the node-FSM + flat navmesh for XZ tracking; the flight + dive are MOVEMENT/`perform_attack()` overrides on the subclass, NOT new states. Override `move_along_path`/`stop` to drop gravity and hold altitude.
- `godot-fps-enemy-combat` — keep `health`/`score_value`/`died`/`on_hit()` verbatim so the flyer stays one-shot shootable; connect death idempotently.
- `godot-composition` — signals up (`touched_player`/`bumped_player`), calls down; the dive reuses the existing touch→life seam, no new WaveManager wiring beyond the ratio export.
- `godot-art-style` — add `ENEMY_STINGER_*` to `art_style.gd`; never inline the Color.
- `godot-code-rules` — strict typed GDScript; gate `tools/validate.sh`. Mind the `_gravity`/`is_on_floor` paths in the base `move_along_path`/`stop` are fully replaced (no `super` call) so the flyer never falls.
- `godot-verify` — verify the flyer renders, is tinted, and HOVERS off the floor at runtime (a flyer stuck on the ground = the altitude override failed).
- `godot-runtime-smoke` (optional, recommended) — a headless assert that a simulated dive emits `touched_player` with arity 1, and `on_hit()` emits `died`. Cheap regression guard for the new movement override.

## Later

- Dive telegraph cue (emission ramp + a downward "ready" tilt) and a dive/impact SFX + VFX burst.
- Ranged-from-above variant (the alt attack) as a 7th type or a flyer behaviour toggle.
- True vertical navigation / flying over walls; altitude variety per flyer.
- Swarm of 2–3 coordinated flyers; escalating `flyer_ratio` over the run.

## Open questions

None — buildable as one slice.
