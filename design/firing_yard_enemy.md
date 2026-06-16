# Firing Yard Enemy — patrolling AI character

**Goal** — F5: two greybox enemies walk a waypoint loop in the firing yard; when the player gets close in clear sight, an enemy turns and chases, paths around walls/props, stops at melee range to telegraph an attack, and returns to patrol if the player escapes or breaks line of sight. The player can shoot an enemy and it despawns on the hit.

**Roadmap** — Track B3 (Enemy AI) of `docs/roadmap/fps_poc.md` (newly in scope; built with the adopted `godot-enemy-ai` skill — native NavigationRegion3D + NavigationAgent3D + node-FSM, no addon). Sits ALONGSIDE the B2 targets and the parked B2 stationary NPCs (`firing_yard_npc.md`) — that NPC slice is untouched.

**Decisions applied (from interview):**
- Attack = **visible but harmless telegraph**. No player health/damage system in this slice. `perform_attack()` plays a cheap telegraph (a brief mesh colour-flash / scale-lunge) and prints on the cooldown; the player takes no damage. Real damage parked to Later.
- Enemy is **shootable, one hit despawns** — same contract as `target.tscn`/the NPCs: `on_hit() -> queue_free()`, `collision_layer = 8` (the layer the projectile masks), `collision_mask = 0`. The existing weapon kills it; no health bar.
- **Add 2 enemies alongside** the existing targets; do NOT modify `firing_yard_npc.md` or its NPC slice.
- Patrol = **3-waypoint closed loop** on the open mid-floor, pausing at each. Two enemies share or get separate loops (see Scope-in); two agents also exercise the NavigationAgent3D RVO avoidance.
- Skill defaults kept: `patrol_speed 1.75`, `move_speed 3.5`, `detect_range 12`, `attack_range 1.8`, `escape_range 16`, `attack_cooldown 0.8`, `patrol_wait 1.0`.

## Build prerequisites (godot-dev — do these before/while wiring the enemy)
1. **Baked `NavigationRegion3D`** covering the firing-yard floor. The floor is many `FloorSlab*` `StaticBody3D` box slabs (not a GridMap floor) spanning roughly world X 0–48, Z 0–32 at y≈0. Add a `NavigationRegion3D` with a `NavigationMesh` (agent radius < 0.5 so it fits between props; agent height ~1.8) and **bake it over the walkable floor** at edit time. Without a baked mesh the enemies stand still. Re-bake if the floor changes.
2. **Player in group `player`** (lowercase). The scene's `Player` node is currently in group `Player` (capital P) only — the skill finds its target via `get_first_node_in_group("player")`, so **add the lowercase `player` group** to the `Player` node (keep the existing one if anything relies on it). Without it, `target()` returns null and enemies never aggro.
3. `EyeRay` (RayCast3D) `collision_mask` = the **wall/world layer only** (so walls/props block sight, the player does not register as a wall). Player is on `collision_layer = 2`; walls/floor/props are the world layer(s) — set the eye mask to the world layer(s), excluding 2 and excluding the target layer 8.

## Scope (in)
- New entity per `godot-enemy-ai`: `entities/enemy/enemy.tscn` + `entities/enemy/enemy.gd` (`class_name Enemy`, CharacterBody3D), with the FSM component under `entities/enemy/state_machine/` (`state.gd`, `state_machine.gd`, `patrol_state.gd`, `chase_state.gd`, `attack_state.gd`) and the node tree from the skill (Mesh greybox capsule, CollisionShape3D, NavigationAgent3D, EyeRay, AttackTimer, PatrolWaitTimer, StateMachine + 3 state children; `initial_state = PatrolState`).
- **Greybox look:** `Mesh` = capsule (or blocky humanoid) with a flat-colour material from `tools/art_style.gd`, distinct from the yellow targets AND from the NPC figure colour (e.g. a hostile red/maroon swatch) so an enemy reads as a threat, not a target/NPC.
- **Shootability:** `enemy.gd` has `func on_hit() -> void: queue_free()`; root `collision_layer = 8`, `collision_mask = 0` (matches `target.tscn`). The projectile already duck-types `on_hit()`.
- **Attack telegraph:** `perform_attack()` does a brief visible tell on the `Mesh` (colour-flash or scale-lunge) + a `print`. No damage to the player.
- **Two enemies** baked into `levels/firing_yard.tscn`, spawned standing on the floor near the far/mid yard (e.g. world ~(22, 1, 8) and ~(30, 1, 10)), clear of platforms/props, on the baked navmesh. Player spawns at ~(24, 1, 30) facing −Z, so enemies patrol ahead and aggro as the player advances.
- **Waypoints:** `Marker3D` nodes placed in the level scene (world anchors, NOT children of the enemy), assigned to each enemy's exported `patrol_waypoints: Array[Marker3D]`. Place 3 per loop on open mid-floor (around world Z 12–22, X 18–32), clear of `BarrelA/B`, `CrateA`, the platforms, and the existing targets, all reachable on the navmesh. Two enemies may share one 3-marker loop or get two small loops — godot-dev's call, keep markers on open floor.
- Register nothing new in `main.gd`/`main.tscn` — the enemy lives inside `firing_yard.tscn`, which is already a registered level.

## Scope (out)
- **Player health / damage** — no system exists; attack is a harmless telegraph. (Later; would be its own slice.)
- Enemy health / multi-hit — cut; one shot despawns (matches targets).
- Sourced/animated enemy model, walk/attack animations — Later; greybox capsule now.
- Death VFX / ragdoll / sound; hit-reaction beyond despawn — Later.
- Waves / respawn / spawner; score or aggro UI — Later.
- Touching `firing_yard_npc.md` or its 5 stationary NPCs — out; separate slice.

## Acceptance (godot-dev + human F5)
- `tools/validate.sh` passes (strict typed GDScript, no weakened warnings); `godot-verify` passes on `main.tscn` and on `firing_yard.tscn` via F6.
- F5: two enemies (distinct hostile colour) walk a closed waypoint loop and pause at each marker; they stay on the floor (no float/sink).
- Walking the player into detect range with clear sight flips an enemy to chase — it turns and pursues.
- The chasing enemy paths AROUND a wall/prop between it and the player (proves the navmesh, not a straight line).
- Standing behind a barrel/crate (in range, no sight) does NOT trigger chase; stepping into the open does.
- At attack range the enemy stops and the telegraph fires no faster than `attack_cooldown`; the player takes no damage.
- Running past `escape_range` or breaking sight returns the enemy to patrol from where it is.
- Shooting an enemy despawns THAT enemy on the hit; the other enemy and the targets are unaffected; no orphan nodes; node count sane.

## Skill notes
- `godot-enemy-ai` — full build (nav + node-FSM + perception). REQUIRES a baked `NavigationRegion3D` and the player in group `player` (see prerequisites). Keep movement on the entity (`move_along_path`/`stop`), behaviour in the states; throttle re-path in ChaseState (`REPATH_INTERVAL`); `EyeRay.enabled = false`, driven via `force_raycast_update`.
- `godot-composition` — enemy = CharacterBody3D base + component children (StateMachine, NavigationAgent3D); states call DOWN, entity never reaches UP. Same hit boundary as `Target`: the enemy reacts to its own `on_hit`, the projectile only signals it.
- `godot-code-rules` — strict typed GDScript on every new `.gd`; gate `tools/validate.sh`.
- `godot-art-style` / `godot-procedural-model` — greybox enemy colour from `tools/art_style.gd`, distinct from target-yellow and the NPC figure colour.
- `godot-verify` — a hit + state changes alter runtime state; verify chase/attack render and the despawn renders, scene still runs.
- `godot-gridmap-level` / `firing_yard.tscn` — enemies + `Marker3D` waypoints are computed-position nodes baked into the level scene (like targets/props), NOT part of the GridMap; navmesh bakes over the `FloorSlab*` geometry.

## Later
- Player health + damage so the attack hurts; death/respawn loop.
- Sourced animated enemy `.glb` (idle/walk/attack clips) via `godot-mesh-import-pixel-art` + `godot-animation-libraries`, swapping the greybox mesh (same pattern as the NPC slice 2).
- Death VFX / ragdoll / hit + attack sound.
- Enemy waves / spawner / score + aggro-state UI.
- Smarter perception (FOV cone instead of full-radius sight, hearing on shots).

## Open questions
None blocking. The two prerequisites (bake navmesh, add lowercase `player` group) are build steps, not open decisions.
