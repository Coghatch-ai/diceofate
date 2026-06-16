# Firing Yard NPC — standing shootable characters

**Goal** — F5: five character-shaped NPCs stand in the firing yard in clear line of sight from spawn; shooting one makes that NPC vanish on the projectile hit.

**Roadmap** — Track B2 (Targets / enemies) of `docs/roadmap/fps_poc.md`. A *stationary* shootable character is in scope (it is just a character-shaped target). **Movement / patrol / chase / player-awareness AI is OUT of scope** per the roadmap's out-of-scope list ("enemy pathfinding AI — until separately scoped") and B2's open question. That intent is parked in **Later**, gated on a roadmap amendment.

**Decisions applied (from interview):**
- NPC = stationary, character-shaped, **shootable**, despawns on first projectile hit (same contract as the existing `Target`). No movement, no awareness of the player.
- 5 NPCs, standing on the open floor in front of spawn, in clear line of sight.
- Appearance target is a **sourced low-poly .glb character with a looping idle animation** (art director / asset-advisor to produce). Built **greybox-first** so godot-dev can ship and verify now; the sourced model swaps in as a second slice.
- The user's patrol/chase request was cut and parked — see Later.

## Build as two ordered slices

### Slice 1 — greybox standing NPCs (build now, no asset dependency)
**Scope (in)**
- New entity `entities/npc/npc.tscn` + `entities/npc/npc.gd`. Root `Npc` (StaticBody3D) → `CollisionShape3D` (CapsuleShape3D, ~1.8 m tall) + `MeshInstance3D` (a `CapsuleMesh`, or a kitbashed blocky humanoid via `tools/gen_models.gd`) with a flat-colour material distinct from the yellow `Target` blocks (e.g. a desaturated figure colour from `tools/art_style.gd`) so it reads as a *person*, not another block.
- `npc.gd` (StaticBody3D): `func on_hit() -> void: queue_free()` — identical hit contract to `Target` (the projectile already calls `on_hit()` via `has_method` duck-type). Set `collision_layer = 8` (the targets layer the projectile masks), `collision_mask = 0`, matching `target.tscn`.
- Bake **5 `Npc` instances** into `firing_yard.tscn` on the open floor in front of the spawn. Player spawns at world ~(24, 1, 30) facing −Z, so place the five spread across the mid-floor ahead of that (around world Z 14–22, X 18–30), all in direct line of sight, not behind cover/props, not overlapping the existing targets or platforms. Stand them on the floor (capsule centre at y ≈ 0.9).

**Acceptance (Slice 1)**
- F5: five upright character-shaped figures stand ahead of spawn, visibly distinct in colour from the yellow target blocks, all in line of sight.
- Aiming at one and firing makes **that** NPC disappear on the hit; the other four remain; targets unaffected.
- NPCs are solid before the hit; no orphan nodes after despawn; node count sane.
- `tools/validate.sh` passes; `godot-verify` passes on `main.tscn` and on `firing_yard.tscn` via F6.

### Slice 2 — swap in the sourced animated .glb (after art director delivers)
**Depends on:** an animated rigged character `.glb` (model + looping idle clip) landing in `assets/models/` via the **art director / asset-advisor** loop. **User/asset task — blocks this slice only.**
**Scope (in)**
- Replace the greybox `MeshInstance3D` inside `entities/npc/npc.tscn` with the imported `.glb` character (instanced per `godot-mesh-import-pixel-art`), scaled to ~1.8 m. Keep the `Npc` StaticBody3D root, the capsule collider, the layer/mask, and `on_hit()` unchanged so the hit contract is untouched.
- Add an `AnimationPlayer` playing the looping **idle** clip on `_ready()` (per `godot-animation-libraries`; retarget if the clip targets a foreign skeleton).
**Acceptance (Slice 2)**
- F5: the five NPCs render as the sourced character with a visible looping idle; still shootable and despawn on hit exactly as in Slice 1.
- Import correct (not blurry/black/mis-scaled); `tools/validate.sh` + `godot-verify` pass.

## Scope (out)
- Movement / patrol / chase / player-awareness / pathfinding AI — out of roadmap scope; parked (Later), needs a roadmap amendment.
- Health / multi-hit — cut; one hit despawns (matches existing targets).
- Hit reaction beyond despawn (ragdoll, death anim, VFX, sound) — Later.
- Respawn / waves / score UI — Later.

## Skill notes
- `godot-composition` — the NPC reacts to its own hit (`on_hit` → despawn); the projectile signals the hit, does not own the reaction. Same boundary as `Target`.
- `godot-mesh-import-pixel-art` — Slice 2 character import + scaling; instance the .glb in place of the greybox mesh, keep collision on the StaticBody3D root.
- `godot-animation-libraries` — Slice 2 idle clip; merge into an AnimationLibrary on the NPC's own AnimationPlayer; retarget if the clip is for a foreign skeleton.
- `godot-procedural-model` / `godot-art-style` — Slice 1 greybox figure; pull its colour from `tools/art_style.gd`, distinct from the target yellow.
- `godot-gridmap-level` / `firing_yard.tscn` — NPCs are computed-position instances baked into the level scene (like the targets and props), NOT part of the GridMap.
- `godot-code-rules` — strict typed GDScript; gate `tools/validate.sh`.
- `godot-verify` — a hit changes runtime state; verify the despawn renders and the scene still runs.

## Later
- **Enemy AI (the user's original ask):** patrol routes, line-of-sight detection, chase/approach, attacking the player. Out of scope now — requires reopening `docs/roadmap/fps_poc.md` with a dedicated enemy-AI phase + gate before it can be designed/built.
- Health / multi-hit NPCs.
- Death animation / ragdoll / hit VFX + sound.
- Respawn or wave spawning; hit/kill counter UI.
- NPC variety (multiple character models / colours).

## Open questions
None blocking Slice 1. Slice 2 is blocked only on the sourced animated `.glb` (art director / asset-advisor).
