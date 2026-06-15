# FPS Targets (B2)

**Goal** — F5: a projectile hit makes a target visibly vanish, completing the shootable loop (look + move + jump + fire + hit) — all readable in pixel-art.

**Decision applied (from interview):** a target is a **static shootable block that despawns on the first projectile hit**. No multi-hit, no Health component, no colour-flip — the smallest thing that proves the loop end-to-end. Enemy-follow AI stays out of scope per the roadmap.

## Scope (in)
- Build `entities/target/target.tscn`: root `Target` (StaticBody3D) → `CollisionShape3D` (BoxShape3D) + `MeshInstance3D` (a ~1 m `BoxMesh`, bright flat albedo — e.g. `#e0c020` yellow — so it reads as a shootable against the dark arena). On the collision **layer** the projectile's mask hits (the "targets" layer from A3).
- `entities/target/target.gd` (StaticBody3D): on a projectile hit, `queue_free()`. Cleanest wiring: the Target listens for the projectile's `hit` signal (signals up) — or, since the projectile already despawns itself and emits `hit(body)`, have the projectile-side reaction call into the body group; pick the composition-clean path per `godot-composition` (Target reacts to being hit; projectile does not reach into the Target's internals). A minimal `func on_hit() -> void: queue_free()` called from the projectile's `hit` handler is acceptable.
- **Place 3–4 Target instances** as baked nodes in `firing_yard.tscn` at readable positions in front of the spawn (player spawns at cell (12,15) facing −Z, world (24,~1,30)): e.g. a small spread on the floor and one on each platform deck (the +1 m and +2 m platforms from B1b), so testing exercises aim + verticality. Targets are baked into the level `.tscn`, not spawned at runtime.

## Scope (out)
- Moving / patrolling targets, enemy-follow / pathfinding AI — roadmap out-of-scope (off-video; harvest separately if ever needed).
- Health / multi-hit / damage — explicitly cut; one hit despawns.
- Respawn / wave spawning — Later.
- Score / hit counter UI — Later.
- Hit VFX / sound — Later (covered by the weapon's parked VFX item).

## Acceptance
- F5: aiming at a target and firing makes that specific target **disappear** on the projectile hit; other targets remain.
- Targets are solid before the hit (the projectile's `hit`/`body_entered` registers against the target's collider).
- At least one target sits on a raised platform so you must aim up to clear it — confirms vertical aim works.
- No leftover/orphan nodes after a target despawns; node count is sane.
- `tools/validate.sh` passes; `godot-verify` passes on `main.tscn` (and `firing_yard.tscn` standalone via F6).

## Skill notes
- `godot-composition` — Target reacts to its own hit (despawn); the projectile signals the hit and does not implement the target's reaction. Keep the boundary clean.
- `godot-gridmap-level` / `firing_yard.tscn` — targets are computed-position instances baked into the level scene (like the B1b props), not part of the GridMap.
- `godot-code-rules` — strict typed GDScript; gate `tools/validate.sh`.
- `godot-verify` — a hit changes runtime state; verify the despawn renders and the scene still runs.

## Later
- Respawn or wave spawning keyed to the arena.
- Hit counter / score UI.
- Moving targets; (separately scoped) enemy AI.
- Hit VFX + sound.

## Open questions
None.
