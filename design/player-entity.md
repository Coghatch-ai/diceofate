# Player Entity

**Goal** — A controllable player capsule moves around basic_room with WASD and jumps with Space; the camera follows it.

**Scope (in)**
- New entity scene `res://entities/player/player.tscn`: root `Player` (CharacterBody3D), children `MeshInstance3D` (CapsuleMesh placeholder, 0.5 radius x 1.8 height, flat color material) and `CollisionShape3D` (matching CapsuleShape3D).
- New script `res://entities/player/player.gd` attached to root:
  - `_physics_process`: read move_left/right/forward/back actions into a direction vector, apply horizontal velocity, add gravity (use `ProjectSettings.get_setting("physics/3d/default_gravity")`), call `move_and_slide()`.
  - Jump: when `is_on_floor()` and jump action just pressed, add upward velocity impulse.
  - Movement aligned to world axes (no camera-relative steering this slice).
  - Exports: `speed: float = 5.0`, `jump_velocity: float = 4.5`.
- Instance `player.tscn` in `basic_room.tscn` at `(0, 1, 0)` (above floor center).
- In `main.gd`: after the level is loaded, find the player node and assign it to `CameraRig.target` so the camera follows.

**Scope (out)**
- Camera-relative movement (requires yaw rotation input and extra math) — parked.
- Animations or model — capsule placeholder only.
- Combat, health, dice interaction — not requested.
- Collision on walls/furniture — walls are MeshInstance3D only; player will clip through them (acceptable for POC; add collision shapes in a later slice if needed).
- Coyote time, variable jump height, acceleration curves — polish, not POC.

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- entities/player/player.tscn levels/basic_room.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- F5: player capsule visible in the room, falls and lands on the floor (no infinite fall), WASD moves it around, Space jumps, camera smoothly follows.

**Skill notes**
- `godot-verify`: mandatory after all scene/script changes.
- CLAUDE.md conventions: use `position = Vector3(...)` in .tscn, not `transform = Transform3D(...)`.
- `godot-composition`: Player is a single-responsibility entity this slice (CharacterBody3D + placeholder mesh + one movement script). No component extraction yet — that earns a separate slice when a second consumer appears.

**Later**
- Camera-relative movement (when camera yaw rotation is added).
- Wall/furniture collision shapes so player cannot clip through.
- Sprint, dash, or run speed modifier.
- Replace capsule with animated character model.
- Footstep sounds, dust particles.

**Open questions** — none.
