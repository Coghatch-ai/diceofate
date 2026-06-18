# Player Sprint + Crouch

**Goal** — Hold Shift to run faster; hold Ctrl to crouch lower, slower, and under low ceilings — first-person feel improves with no new scripts or scenes.

**Scope (in)** — all in `entities/player/player.gd` + 2 new input actions in `project.godot`. ~60–80 LOC, zero new scripts/scenes/nodes. Reuse existing `$Head` + `$CollisionShape3D`. Build from skill `godot-first-person-controller` (sprint/crouch extension) + digest `xenodot-forge/plugin/library/transcripts/fps-sprint-crouch.md`.

- **Input actions** (new, `project.godot`): `sprint` → Shift, `crouch` → Ctrl.
- **Sprint** — hold-to-sprint, computed bool each frame (NOT stored, NOT an FSM state):
  `is_sprinting = Input.is_action_pressed("sprint") and is_on_floor() and not _aiming and crouch_amount < 0.5 and input_dir != Vector2.ZERO and input_dir.y < 0` (moving, mainly forward).
  Apply as `effective_speed *= sprint_mult` in the existing `effective_speed` expr — existing accel/decel lerp chases it; no separate ramp.
- **Sprint FOV kick** — separate per-frame lerp toward `sprint_fov` (hip+6°) while sprinting, back to `hip_fov` otherwise. Run ONLY when `not _aiming` (ADS owns `_camera.fov` via its `create_tween`; sprint gated off while aiming → mutually exclusive). Do NOT touch the recoil spring.
- **Crouch** — hold-to-crouch, single `crouch_amount: float` (0..1) lerped each frame (`crouch_lerp_speed`) toward 1 while held (and stay 1 if blocked overhead), else toward 0. Drives:
  - capsule `height` = `lerpf(stand_height 1.8, crouch_height 1.2, crouch_amount)`;
  - capsule `shape.position.y = current_height/2` (center-anchored → bottom stays at local 0; position.y DECREASES on crouch — do NOT shift up);
  - `_head.position.y = lerpf(stand_eye 1.6, crouch_eye 1.3, crouch_amount)`.
  - speed: `effective_speed *= lerpf(1.0, crouch_speed_mult 0.5, crouch_amount)`.
- **Stand-up ceiling gate** — `test_move(global_transform, Vector3.UP * stand_delta)` (NOT a RayCast); if blocked, hold `crouch_amount` at 1 even on key release.
- **Layering** (one expr, after ADS): `effective_speed := move_speed; if _aiming: *= ads_move_scale; if is_sprinting: *= sprint_mult; effective_speed *= lerpf(1.0, crouch_speed_mult, crouch_amount)`.

**@export params + starting values**
- `sprint_mult: float = 1.6`
- `sprint_fov: float = 81.0`  (hip_fov 75 + 6; FOV kick widen)
- `sprint_fov_lerp: float = 8.0`
- `crouch_height: float = 1.2`  (stand 1.8; capsule min at radius 0.4 is 0.8 → safe)
- `crouch_eye: float = 1.3`  (stand eye 1.6)
- `crouch_speed_mult: float = 0.5`
- `crouch_lerp_speed: float = 12.0`
- (constants/read from rig: stand_height 1.8, stand_eye 1.6, radius 0.4)

**Scope (out)**
- Head-bob bump on sprint — no bob system exists today; adding one is net-new system work, breaks the one-task bar. Parked.
- Stamina meter — adds meter + drain/regen tuning + HUD; out of POC scope.
- Crouch-shooting accuracy bonus — couples to I2 spread; keep this slice pure movement.
- FSM / state classes (the jeh3no addon path) — explicitly rejected; flat multipliers only.

**Acceptance** (F5 feel-check)
- Hold Shift while moving forward on the ground → noticeably faster + slight FOV widen; release → speed/FOV settle back.
- Sprint does NOT engage while aiming (RMB), airborne, crouched, or with no movement input.
- Hold Ctrl → smoothly lower (eye + capsule), move ~half speed; player stays on the floor (no pop/hover at transition).
- Crouch under a low obstacle, release Ctrl while still under it → stays crouched; step clear → stands up.
- Crouch + sprint mutually consistent: crouched cancels sprint (crouch_amount ≥ 0.5 gates it off).
- godot-verify: `tools/validate.sh` clean; smoke + render OK on `main.tscn`.

**Skill notes**
- `godot-first-person-controller` (sprint/crouch extension) — primary; build from it + the digest.
- `godot-code-rules` — strict typed GDScript; load before editing `player.gd`; gate `tools/validate.sh`.
- Digest corrected facts (trust): radius 0.4 → min capsule height 0.8; center-anchored capsule → `shape.position.y = height/2` (crouch DECREASES y); ceiling = `test_move()` not RayCast; sprint = speed-multiplier the existing lerp chases (no FSM); FOV kick on a SEPARATE lerp, not the recoil spring.

**Later** — sprint head-bob bump (its own slice); stamina meter + HUD; crouch-shoot accuracy bonus (with I2 spread); toggle-vs-hold option for crouch.

**Open questions** — none.
