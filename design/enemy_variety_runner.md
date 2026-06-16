# Enemy Variety — a second "Runner" enemy type

**Goal** — F5: alongside the standard enemy, a visibly distinct faster enemy appears in the waves — you can tell the two apart on sight and the fast one pressures you to react quicker.

**Why** — One enemy type = one threat pattern; the arena reads flat. A second type adds tactical texture (prioritise the fast one) at near-zero new code — `enemy.gd` already exposes every tuning knob as an `@export` (`move_speed`, `patrol_speed`, `detect_range`, `attack_range`, `attack_cooldown`). A variant is a re-tuned scene, not a new class. **Build AFTER the HUD slice** (`design/arena_hud.md`) so the count readout reflects mixed waves.

**Decisions applied (recommendations — repo seams resolve all forks):**
- **Variant = an inherited scene, NO new script.** New `entities/enemy/enemy_runner.tscn` inherited from `enemy.tscn`, overriding only exports + the mesh colour. `enemy.gd` is the single behaviour script for both. Reason: `godot-composition` — tune by data, don't fork logic.
- **Runner profile = fast + glass.** Higher `move_speed` (≈6.0 vs 3.5), higher `patrol_speed`, slightly shorter `detect_range` (≈9 vs 12) so it commits late then rushes. Same `on_hit()` one-shot death (already glass — projectile kills in one hit). Distinct hazard-leaning colour (e.g. red/orange) so it reads as "the dangerous fast one" at a glance — set via the mesh's material override in the inherited scene, NOT a shared resource (avoid flashing both types on death — `enemy.gd` already makes the flash material unique, but the BASE colour must differ per scene).
- **WaveManager spawns a mix.** Add `@export var enemy_scene_b: PackedScene` (the Runner) + `@export var runner_ratio: float = 0.3`. In `_spawn_one`, roll `randf() < runner_ratio` → instance B else A; everything else (markers, patrol paths, collision layers 8/mask 1, signal wiring) is identical, so the existing connect/escalate/reset code is untouched. Seed phase and respawns both roll.
- **Colour source = the art style module.** Pull the Runner colour from `tools/art_style.gd` (named swatch) per `godot-art-style`, not a hand-typed `Color()` — keeps the placeholder palette coherent. If no suitable swatch exists, add one named swatch there and reference it.

## Scope (in)
- `entities/enemy/enemy_runner.tscn` — inherited from `enemy.tscn`; override `move_speed`, `patrol_speed`, `detect_range` to the Runner profile; mesh material override to a distinct named swatch.
- `wave_manager.gd` — `enemy_scene_b` export, `runner_ratio` export, the per-spawn type roll in `_spawn_one`. No change to connect/escalate/reset.
- Assign `enemy_scene_b` = `enemy_runner.tscn` on the `WaveManager` node in `firing_yard.tscn`.
- (if needed) one new named swatch in `tools/art_style.gd` for the Runner colour.

## Scope (out)
- A third type / boss — one new type this slice.
- New behaviour states (ranged attack, fleeing, special abilities) — Runner reuses the patrol→chase→attack FSM as-is.
- Per-type score weighting in the HUD — KILLS stays a flat count for now (parked, pairs with HUD Later).
- Multi-hit health on either type — both stay one-shot (player health is its own future slice).
- New mesh geometry / sourced model — colour-differentiated reuse of the existing greybox capsule/kitbash.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes on `wave_manager.gd` (+ `art_style.gd` if touched).
- `godot-verify` passes on `firing_yard.tscn` (F6) and `main.tscn`: both enemy scenes load, render, path on the navmesh.
- F5: waves contain BOTH types; the Runner is visibly a different colour and visibly faster/chases harder.
- Shooting either type kills it in one hit; both feed the same escalation + reset; HUD ENEMIES count includes both.
- `runner_ratio` roughly governs the mix (≈30% runners over a dozen spawns); no spawn errors, no orphans.

## Skill notes
- `godot-enemy-ai` — Runner reuses the SAME `enemy.gd` (native nav + node-FSM); only exports differ. Spawns must still land on the baked `NavFloor` (unchanged marker set). Higher `move_speed` must stay within what `NavigationAgent3D` avoidance handles — verify it doesn't jitter/overshoot waypoints.
- `godot-composition` — variant via inherited scene + data, not a subclass or duplicated script. Tune by export.
- `godot-art-style` — Runner colour from a named swatch in `tools/art_style.gd`; don't hand-type a `Color()` literal.
- `godot-mesh-import-pixel-art` — material override goes on the inherited scene's mesh and must be unique to that scene (not the shared base resource) so the two types don't share one colour.
- `godot-code-rules` — typed export, gate `tools/validate.sh`.
- `godot-verify` — mixed spawns are runtime state; verify both types appear, path, die, and reset.

## Later
- Per-type kill scoring in the HUD (Runner worth more).
- Tankier slow type (third profile, same pattern) for a rock-paper-scissors mix.
- Type-specific death SFX/colour-coded hitmarker.
- Spawn-weight tuning that escalates the runner ratio with kill count.

## Open questions
None blocking. `enemy.gd` exposes all needed knobs; `wave_manager.gd` spawn path is the only logic touch.
