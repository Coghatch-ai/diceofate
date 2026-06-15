# FPS Player — Perspective Eye-Camera + Controller (A1 + A2)

**Goal** — F5 drops you into the Firing Yard looking out through the player's eyes in first-person perspective; mouse looks around (clamped pitch), WASD moves relative to facing, Space jumps — all still pixelated by the SubViewport downscale.

A1 (perspective rig) and A2 (controller) are **one build**: the new FPS player *is* the perspective rig (its eye-camera becomes the SubViewport's current Camera3D). Splitting them would leave a camera with no body to drive it.

## Scope (in)
- Rebuild `entities/player/player.tscn` per skill `godot-first-person-controller`: root `Player` (CharacterBody3D) → `CollisionShape3D` (CapsuleShape3D) + `Head` (Node3D, local Y ≈ 1.6) → `Camera3D` (child of Head, identity transform, **Perspective**). Keep a small mesh on the body (optional; first-person you won't see it) — collider is what matters.
- Rewrite `entities/player/player.gd` per the skill: raw `InputEventMouseMotion` mouse-look (yaw body / pitch head, clamp ±90°), camera-relative WASD via `transform.basis`, gravity from ProjectSettings, jump on `is_on_floor`, `MOUSE_MODE_CAPTURED` in `_ready`, `ui_cancel` releases the mouse. Drop the old orthographic-rig fields (`camera_rig`, `get_yaw_radians` dependency, `inventory`/`add_item` — foundation-POC leftovers, not in FPS scope).
- **Camera takeover:** the player's `Camera3D` must be the SubViewport's current camera. The persistent orthographic `CameraRig` in `main.tscn` must yield — one current Camera3D per viewport.
- **Update `main.gd`:** stop wiring `Player` → `CameraRig` (the FPS player owns its own camera). After instancing the level, make the player's eye-camera current (e.g. `camera.make_current()`), and either remove the `CameraRig` wiring block or guard it so it only runs for levels that ship a player with a `camera_rig` field. The orthographic rig stays in `main.tscn` (other/old levels may want it) but is inert for the FPS genre — do not delete it.
- Player stays a baked node in `firing_yard.tscn` at spawn (24, ~1, 30), facing −Z (B1a already instances it; the rebuilt scene drops in).

## Scope (out)
- `shoot` input action + weapon — that is A3, next slice. Do NOT wire shooting here.
- Coyote-time / jump-buffer / variable-jump / dash / wall-jump — parked (skill's Later).
- Deleting the orthographic `CameraRig` or its scene — kept inert for camera-agnostic/old levels; not this slice's job.
- Visible first-person arms / weapon viewmodel — Later.

## Acceptance
- F5 launches Main → Firing Yard in **first-person perspective** (not top-down/floating), pixelated by the downscale, outlines intact, no distortion.
- Mouse left/right turns the whole view (body yaw); up/down tilts and **stops** at straight up/down (no somersault).
- WASD walks relative to facing; strafing is perpendicular. Space jumps only when grounded; player falls and lands.
- Esc releases the mouse (cursor returns); re-clicking/capture behaviour is acceptable as-is.
- `Camera3D.rotation == (0,0,0)`; pitch is on `Head`, yaw on `Player`. Exactly one current camera in the SubViewport.
- `tools/validate.sh` passes; `godot-verify` passes on `main.tscn` (it exercises `_ready` → the level load + camera takeover).

## Skill notes
- `godot-first-person-controller` — the controller + scene contract (Head/Camera split, pitch clamp, capture). Camera3D stays Perspective; pixel look is the downscale, not the projection.
- `godot-3d-pixelation` — eye-camera renders inside the existing SubViewport; nothing changes about the rig itself.
- `godot-main-scene` — camera ownership: one current Camera3D per viewport; `main.gd` must `make_current()` the player camera and stop forcing the orthographic rig.
- `godot-composition` — movement on the body, look-pitch on the Head child.
- `godot-code-rules` — strict typed GDScript; gate `tools/validate.sh`.
- `godot-verify` — verify on `main.tscn` (changes what F5 renders); watch for the black-screen/"two current cameras" signature.

## Later
- Game-feel pass (coyote-time, jump-buffer, variable jump) from GodotPrompter player-controller skill.
- First-person weapon viewmodel / arms.
- Per-genre camera selection wired cleanly in Main (so the orthographic and FPS paths coexist by config, not by inert nodes).

## Open questions
None.
