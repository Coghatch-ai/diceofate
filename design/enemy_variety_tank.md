# Enemy Variety — a third "Tank" enemy type (slow, multi-hit)

**Goal** — F5: alongside the crimson grunt and orange runner, a visibly distinct slow "tank" enemy appears in waves — it shrugs off the first hits and takes 3 shots to kill, so you must commit or kite it.

**Why** — Two types both die in one shot read the same way (shoot on sight). A tank introduces the first **durability** axis — a threat you can't clear instantly — completing a rock-paper-scissors mix (rush / chase / soak). This is the parked "tankier slow type (third profile)" from `enemy_variety_runner.md`'s Later list. It needs **one** new piece of shared scope: a `health` value on `enemy.gd` (today every enemy is one-shot).

**Decisions applied (interview + repo seams — recorded so you can override):**
- **Tank = inherited scene + tiny tint script, like the runner.** New `entities/enemy/enemy_tank.tscn` (inherited from `enemy.tscn`) + `entities/enemy/enemy_tank.gd` (`extends Enemy`, mirrors `enemy_runner.gd`): `super._ready()` then apply the tank swatch via `set_surface_override_material` in code. **Recolour in `_ready()`, NOT a hand-authored `.tscn` material override** — per the updated `godot-mesh-import-pixel-art` skill a nested/inherited GLB override authored in `.tscn` silently vanishes and fails verify; the runner already does it the correct (code) way — copy that pattern.
- **Multi-hit via a `health` value on `enemy.gd` (the one new shared-scope item).** Add `@export var health: int = 1` + `var _health: int`. `_ready()`: `_health = health`. Change `on_hit()`: `_health -= 1`; if `_health > 0` → play a brief non-fatal hit flash (reuse a lightweight version of the existing flash, **no** `died` emit, **no** `queue_free`) and return; only at `_health <= 0` run the existing death path (`_play_death_sfx` + `died.emit` + `_flash_and_die`). Default `health = 1` keeps grunt + runner one-shot unchanged.
- **Tank profile = slow + tough.** `health = 3`; lower `move_speed` (≈2.2 vs 3.5) and `patrol_speed`; same `detect_range`/`attack_range`. Slow + durable reads opposite to the runner's fast + glass.
- **Distinct colour from a NEW named swatch.** Grunt = crimson, runner = orange; tank needs a third readable hue. Add a desaturated **steel-violet** ramp to `tools/art_style.gd` (`ENEMY_TANK_DARK/MID/LIGHT`) — cool + heavy reads as "armoured", clearly not crimson/orange. `enemy_tank.gd` uses `ENEMY_TANK_MID` (per `godot-art-style`, no hand-typed `Color()`).
- **WaveManager rolls three types.** Add `@export var enemy_scene_c: PackedScene` (tank) + `@export var tank_ratio: float = 0.2`. In `_spawn_one`, roll: `randf() < tank_ratio` → C, else existing runner roll → B, else A. Assign `enemy_scene_c = enemy_tank.tscn` on the `WaveManager` node in `firing_yard.tscn`. Connect/escalate/reset/markers untouched.

## Build steps (godot-dev)
1. **`tools/art_style.gd`** — add `ENEMY_TANK_DARK/MID/LIGHT` (steel-violet ramp; documented exception above `SATURATION_CEILING` like the crimson/orange ramps, since it's a threat colour).
2. **`entities/enemy/enemy.gd`** — add `@export var health: int = 1`, `var _health: int`; set `_health = health` in `_ready()`; gate `on_hit()` on `_health` (non-fatal flash above 0, existing death path at ≤0). No change to grunt/runner scenes (default health 1).
3. **`entities/enemy/enemy_tank.gd`** — copy `enemy_runner.gd` shape; tint with `ENEMY_TANK_MID`.
4. **`entities/enemy/enemy_tank.tscn`** — inherited from `enemy.tscn`; script = `enemy_tank.gd`; override exports `health = 3`, `move_speed ≈ 2.2`, `patrol_speed` lower. **No `.tscn` material override** (code tint only).
5. **`levels/wave_manager.gd`** — add `enemy_scene_c`, `tank_ratio`; extend the `_spawn_one` type roll to three.
6. **`firing_yard.tscn`** — assign `enemy_scene_c = res://entities/enemy/enemy_tank.tscn` on `WaveManager`.

## Scope (in)
- `health` on `enemy.gd` (default 1) + multi-hit `on_hit()` gate with a non-fatal hit flash.
- `enemy_tank.tscn` + `enemy_tank.gd` (tint via code, slow + `health = 3`).
- `ENEMY_TANK_*` swatch ramp in `art_style.gd`.
- `enemy_scene_c` + `tank_ratio` + three-way roll in `wave_manager.gd`; assigned in `firing_yard.tscn`.

## Scope (out)
- A fourth type / boss — one new type this slice.
- New behaviour states (ranged, fleeing, shielded-from-front) — tank reuses patrol→chase→attack FSM.
- Per-type kill scoring / score weighting in the HUD — flat count (pairs with HUD Later).
- A health BAR over the tank — multi-hit is felt via the hit flash; no per-enemy UI this slice.
- New mesh geometry / sourced model — colour + scale reuse of the existing greybox kitbash (tank may scale up slightly via the inherited scene if desired, but no new asset).
- Tuning tank ratio dynamically with kills — fixed `tank_ratio`.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `enemy.gd`, `enemy_tank.gd`, `wave_manager.gd`, `art_style.gd`.
- `godot-verify` passes on `firing_yard.tscn` (F6) + `main.tscn`: all THREE enemy scenes load, render, path on the navmesh; tank tint visible (the code-recolour did NOT silently drop).
- F5: waves contain all three types; tank is a distinct steel-violet, visibly slower.
- Shooting the tank: first 2 hits flash it but it survives; 3rd hit kills it. Grunt + runner still die in ONE hit (regression check).
- Tank death feeds the same escalation + reset + HUD count + win-kill total as the others.
- `tank_ratio` roughly governs the mix; no spawn errors, no orphans after kills/resets.

## Skill notes
- `godot-mesh-import-pixel-art` — recolour the inherited/nested mesh in `_ready()` via `set_surface_override_material` (copy `enemy_runner.gd`); a `.tscn`-authored override on a nested GLB vanishes + fails verify. This is the load-bearing build note.
- `godot-composition` — variant via inherited scene + data + a tiny tint script (mirrors runner), not a new behaviour class; `health` lives on the shared `enemy.gd`.
- `godot-art-style` — tank colour from a NEW named swatch, not a hand-typed `Color()`; keep it a documented threat-colour exception above `SATURATION_CEILING`.
- `godot-enemy-ai` — tank reuses the same nav + node-FSM; slower `move_speed` is safe for `NavigationAgent3D`. Spawns land on the unchanged `NavFloor` marker set.
- `godot-code-rules` — typed `@export var health: int`; explicit return types; gate `tools/validate.sh`.
- `godot-verify` — multi-hit + mixed spawns are runtime state; verify the 3-hit kill, that one-shots still one-shot, and the tint renders.

## Later
- Per-type kill scoring (tank worth more) in the HUD.
- A ranged enemy (new FSM attack state + projectile) — the bigger fourth type.
- Health bar / hit-number feedback over multi-hit enemies.
- Escalating `tank_ratio`/`runner_ratio` with kill count for a difficulty curve.
- Front-armoured tank (directional damage) once a hit-direction seam exists.

## Open questions
None blocking. `enemy.gd` `on_hit()` is the only shared touch; the runner already proves the inherited-scene + code-tint pattern.
