# Melee Feedback / Game-Feel

**Goal** — A hammer swing that reads as a real swing: you see it wind up and arc, and a connected hit feels distinct from a whiff (it bites, the screen jolts, the enemy gets shoved).

## What's wrong now (diagnosis)
- View-model = procedural `hammer.glb` (tiny: ~0.28 m long, box head). At view-model scale + a flat L→R Y-rotation slide, it reads as a moving square.
- Swing is a pure horizontal Y-rotation slide (`melee.gd` `_VM_WINDUP_ROT`/`_VM_SLASH_ROT`) — no arc depth, weak wind-up, and a **hit looks identical to a whiff**.
- Slow timing (cooldown 0.75 s) is GOOD — keep it.
- Ranged hit-juice already exists and melee already feeds it: `melee.gd` emits `hit_confirmed`/`kill_confirmed` → `player.gd` → crosshair `hit_pop`/`kill_pop`; enemy `on_hit()` does a hit/death flash; hit SFX plays. Melee adds NOTHING swing-specific on top.

## Decisions (from user; override here)
- **Weapon stays a hammer** — keep `hammer.glb`, do not swap to knife or source a new `.glb`. Reframe the swing for a blunt weapon (overhead/diagonal smash), not a side slash.
- **Juice picked:** hit-stop on connect + target knockback on hit.
- **Applied default (not asked, but required):** the **view-model arc + wind-up rework is in scope** — it's the base layer the user actually complained about ("animation really bad, square just moving"). Hit-stop and knockback only fire ON a hit; without a readable arc, every whiff still looks like the square sliding. So the arc fix leads.

## Two slices (sequence them; each is one godot-dev task)

### Slice 1 — Readable smash arc + scale (the visible base fix)
**Scope (in)**
- Re-pose the swing in `melee.gd` as a **diagonal overhead smash**: wind-up lifts the hammer up-and-back (raise +Y, rotate back on X, slight off-screen on +X), then a fast down-and-across arc that **enters from top and exits low**, then a slower recover to rest. Drive X **and** Y rotation (pitch the smash), not just Y yaw — that's what gives arc depth.
- Bump the **view-model scale** of `HammerViewModel` (or the smash end-pose travel) so the hammer head clearly fills/crosses frame at the swing apex instead of reading as a small square. Tune in-editor against the camera.
- Keep `cooldown = 0.75` and the three-phase windup/slash/recover split; only the poses/axes and timing-feel change.

**Scope (out)** — model swap (stays hammer); slash-streak VFX (roadmap VFX ban); any hit logic (slice 2).

**Acceptance (F5 + godot-verify)**
- Press V: hammer visibly **lifts (anticipation), then smashes down across frame**, then recovers — reads as a swing, not a sliding box, from the player's eye.
- Apex pose: hammer head is large/central enough to read; not a corner square.
- godot-verify: scenes load/render; `tools/validate.sh` passes.

### Slice 2 — Impact juice: hit-stop + knockback (fires only on connect)
**Scope (in)**
- **Hit-stop:** when `_swing()` actually hits ≥1 body (the existing `hit_confirmed` path), trigger a brief global freeze (~0.05–0.07 s) via `Engine.time_scale` dip then restore (one Tween / SceneTree timer using `ignore_time_scale`). Whiff = no bodies hit = no freeze → instant hit/whiff tell. Player-side seam (`player.gd._on_hit_confirmed`) so the freeze is owned by the player, not the weapon.
- **Camera kick on hit** (cheap add, reinforces the freeze): reuse `player.gd._do_camera_kick`, a sharper downward kick on melee connect.
- **Knockback:** shove the hit enemy away from the player on melee connect. Requires an enemy-side seam — `enemy.gd` drives `velocity = safe_velocity; move_and_slide()` every frame from nav, so a raw velocity poke is overwritten. Add a short **stun window** (`_stun_timer`, ~0.15 s): while stunned, skip the nav-velocity drive and instead apply a decaying knockback velocity + `move_and_slide()`. `on_hit()` (or a new `apply_knockback(from: Vector3)`) starts it. Melee passes the player position as the shove origin.

**Scope (out)** — knockback on the magnet only vs all enemies: apply to **all** non-dying hit enemies (simplest); slash VFX; whiff whoosh SFX (Later); ragdoll/stagger anim.

**Acceptance (F5 + godot-verify)**
- Melee a grunt/tank in reach → screen briefly freezes, camera kicks, enemy is visibly shoved back; kill-confirm/score still fire exactly as before.
- Whiff (no enemy in reach) → no freeze, no kick, no knockback; cooldown still applies.
- Hit-stop never permanently alters `Engine.time_scale` (restores to 1.0 even on rapid repeat swings).
- Knockback never breaks nav: enemy resumes chasing after the stun window; no stuck/launched-through-wall enemies.
- godot-verify: scenes load/render; `tools/validate.sh` passes; no "Signal already connected" on repeat melee of a surviving tank.

## Skill notes
- `godot-fps-enemy-combat` (load-bearing) — hit-stop/knockback hang off the existing `hit_confirmed`/`died`/`on_hit()` contract; do NOT invent a new damage path. Knockback adds a stun seam to `enemy.gd` but keeps `on_hit()` semantics.
- `godot-enemy-ai` — knockback must cooperate with NavigationAgent3D: gate the nav-velocity drive behind the stun timer, don't fight it frame-by-frame.
- `godot-first-person-controller` — camera kick reuses the existing `_do_camera_kick` head-pitch seam.
- `godot-composition` — `melee.gd` stays a sibling component under `Head`, signals up; hit-stop owned by `player.gd`; knockback owned by `enemy.gd`. No inheritance.
- `godot-procedural-model` — hammer model is from `tools/gen_models_props.gd` ("hammer" spec); slice 1 may bump the view-model **node** scale rather than regenerate the mesh (cheaper, no asset loop).
- `godot-code-rules` / `godot-verify` — typed GDScript; gate `tools/validate.sh`; load/render smoke + the no-double-connect check.

## Later
- Whiff whoosh SFX + distinct on-connect impact SFX (audible hit/whiff tell, cheap next slice).
- Screen-space slash-streak VFX (blocked by roadmap VFX ban — revisit when lifted).
- Real sourced knife/sword/bat `.glb` with its own swing clip.
- Knockback tuned per enemy type (light grunts fly, tank barely moves) via a `knockback_resist` export.
- Heavy/charged melee, combo timing.

## Open questions
None blocking. Both user forks resolved (hammer kept; hit-stop + knockback chosen). One flagged scope note for the orchestrator: **knockback is not a one-liner** — it needs the enemy-side stun seam above, which is why it's slice 2 and not folded into slice 1.
