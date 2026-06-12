# Camera Rig

**Goal** — The game renders through a fixed-angle orthographic camera that lives in the persistent Main shell (not inside levels).

**Scope (in)**
- New scene `res://entities/camera_rig/camera_rig.tscn`: root `CameraRig` (Node3D), child `Camera3D`.
- `CameraRig` rotation: `(-30, 45, 0)` degrees (classic 3/4 view).
- `Camera3D`: position `(0, 0, 20)`, Projection = Orthogonal, Size = 10, Far = 100.
- New script `res://entities/camera_rig/camera_rig.gd` attached to root, per skill snippet (exports `target: Node3D`, `follow_speed: float = 8.0`; follows in `_physics_process` with exponential smoothing). No target assigned this slice — static camera is valid.
- Instance `camera_rig.tscn` under `Main/SubViewportContainer/SubViewport` (sibling to LevelHost).
- Delete any in-level camera from `basic_room.tscn` if present (exactly one current Camera3D per viewport).

**Scope (out)**
- Target assignment / follow behavior — no player entity exists yet; camera stays static (parked).
- Camera rotation input (Q/E to turn) — skill explicitly defers this (parked).
- Texel snapping / shimmer mitigation — future slice.
- Post-process quad on camera — separate skill (godot-postprocess-quad).

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- entities/camera_rig/camera_rig.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- F5 launches Main; the basic room appears with parallel edges (no vanishing point). Changing Camera3D Size zooms; moving Camera3D Z does not change framing — confirms orthographic.
- Inspector: Camera3D Projection = Orthogonal; CameraRig rotation = `(-30, 45, 0)`; Camera3D rotation = `(0, 0, 0)`.

**Skill notes**
- `godot-camera-rig`: follow the steps exactly; rig goes inside SubViewport because pixelation is already set up.
- `godot-verify`: mandatory after changes.
- CLAUDE.md convention: use `position` and `rotation_degrees` in .tscn, never hand-written `transform = Transform3D(...)`.

**Later**
- Assign `target` to player once player entity exists.
- Camera yaw rotation in 45/90 degree steps (Q/E input).
- Texel snapping to eliminate sub-pixel shimmer.

**Open questions** — none.
