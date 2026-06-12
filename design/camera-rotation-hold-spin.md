# Camera Hold-to-Spin

**Goal** — Hold Q/E to spin the camera continuously; release to stop immediately.

## Scope (in)

- Replace discrete step rotation with continuous hold-to-spin in `camera_rig.gd`
- New exports:
  - `rotation_speed_degrees: float = 90.0` (degrees per second)
  - `allow_full_rotation: bool = true`
  - `min_yaw_degrees: float = -45.0` (used only when `allow_full_rotation` is false)
  - `max_yaw_degrees: float = 45.0` (used only when `allow_full_rotation` is false)
- `_process(delta)`: check `is_action_pressed("rotate_left")` / `is_action_pressed("rotate_right")`, apply `rotation_degrees.y += speed * delta * direction`
- When `allow_full_rotation` is false: clamp `rotation_degrees.y` to `[min_yaw_degrees, max_yaw_degrees]`
- `get_yaw_radians()` returns `deg_to_rad(rotation_degrees.y)` directly
- Remove: `rotation_step_degrees`, `rotation_duration`, `_target_yaw`, `_tween`, `_rotate_by()`, `_sync_yaw()`

## Scope (out)

- Easing on start/stop — polish, not POC.
- Texel-snapping mitigation — acknowledged shimmer risk, separate slice.
- `_ready()` initialization of yaw — not needed; `rotation_degrees.y` is the source of truth now.

## Acceptance

1. godot-verify passes (property validation, smoke run, render check).
2. F5: hold Q — camera spins left continuously at constant speed; release — stops immediately.
3. F5: hold E — camera spins right continuously; release — stops immediately.
4. F5: hold Q for 2 seconds — camera rotates 180 degrees (at default 90 deg/sec).
5. F5: full 360+ rotation is allowed by default.
6. Inspector: set `allow_full_rotation = false`, `min_yaw_degrees = -45`, `max_yaw_degrees = 45`; F5: camera yaw clamps within that range.
7. Player movement remains camera-relative (existing `get_yaw_radians()` contract unchanged).

## Skill notes

- **godot-camera-rig**: This replaces the rotation system from that skill. Pitch stays fixed; only yaw changes.
- **godot-verify**: Mandatory after changes to `camera_rig.gd`.
- **CLAUDE.md convention**: Input actions `rotate_left` and `rotate_right` already exist; no project.godot changes needed.

## Supersedes

This doc replaces the rotation system in `design/camera-rotation.md`. That doc's "Hold-to-spin mode" Later item is now implemented here as the sole rotation mode. The camera-relative movement pattern in `camera-rotation.md` (player reads `get_yaw_radians()`) remains valid and unchanged.

## Later

- Easing on start/stop (smooth acceleration/deceleration).
- Rotation indicator UI.
- Gamepad shoulder-button rotation.
- Texel-snapping / shimmer mitigation shader.

## Open questions

None. All decisions confirmed.
