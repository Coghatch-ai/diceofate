# Camera Rotation (pattern doc)

**Goal** — The player can rotate the camera yaw in discrete steps (Q/E keys); movement automatically becomes camera-relative so "forward" always means toward the top of the screen.

This is a **pattern doc** — a reusable recipe, not tied to a specific implementation moment. Spawn godot-dev with this doc when the feature is needed.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rotation step | 90 degrees | Four cardinal directions keep the grid-aligned pixel-art readable. 45-degree steps (8 directions) are an option but increase shimmer risk and complicate camera-relative math for no POC benefit. |
| Rotation style | Tween snap, not free rotation | Free rotation causes continuous texel misalignment and shimmer. Discrete steps let the camera settle on clean angles. |
| Rotation target | CameraRig root node (yaw only) | Pitch stays fixed at -30 degrees; only yaw changes. The Camera3D child never rotates. |
| Input actions | `rotate_left` (Q), `rotate_right` (E) | Separate from movement actions. Use `is_action_just_pressed` to avoid repeat-fire. |
| Camera-relative movement | Transform input vector by camera yaw | Player reads the camera's current yaw and rotates the input direction by that angle before applying velocity. |
| Player-to-camera reference | Exported `camera_rig: Node3D` on player | Player needs the camera's yaw. An export is explicit and inspector-assignable; avoids autoload or global. |

---

## Pattern

### 1. Input actions (project.godot)

Add two new actions in `[input]`:

| Action | Key | Physical keycode |
|--------|-----|------------------|
| `rotate_left` | Q | 81 |
| `rotate_right` | E | 69 |

Use the same InputEventKey format as existing actions, `device = -1` (all devices), no modifiers.

### 2. Camera rig rotation (camera_rig.gd)

Extend the existing script:

```gdscript
@export var rotation_step_degrees: float = 90.0
@export var rotation_duration: float = 0.25

var _target_yaw: float = 0.0
var _tween: Tween = null

func _ready() -> void:
    _target_yaw = rotation_degrees.y

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("rotate_left"):
        _rotate_by(rotation_step_degrees)
    elif Input.is_action_just_pressed("rotate_right"):
        _rotate_by(-rotation_step_degrees)

func _rotate_by(degrees: float) -> void:
    if _tween and _tween.is_running():
        _tween.kill()
        rotation_degrees.y = _target_yaw  # snap to clean angle before adding step
    _target_yaw += degrees
    _tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    _tween.tween_property(self, "rotation_degrees:y", _target_yaw, rotation_duration)
    _tween.tween_callback(_sync_yaw)

func _sync_yaw() -> void:
    # Re-anchor _target_yaw to Godot's normalized rotation_degrees.y after tween completes.
    # Prevents accumulation divergence on subsequent rotations.
    _target_yaw = rotation_degrees.y

func get_yaw_radians() -> float:
    return deg_to_rad(_target_yaw)
```

Key points:
- `_target_yaw` accumulates unbounded (no `wrapf`) — the tween always travels exactly `rotation_step_degrees`.
- Kill + snap before incrementing: if a tween is running, snap `rotation_degrees.y` to the previous clean angle first, then add the new step. This prevents the tween from covering leftover distance + new step.
- `_sync_yaw` callback re-anchors `_target_yaw` to Godot's normalized `rotation_degrees.y` after each tween completes, preventing long-term drift.
- Do NOT use `wrapf` on `_target_yaw` — wrapping causes the tween to travel 270° instead of 90° when crossing the ±180° boundary.
- `get_yaw_radians()` exposes the logical yaw for player movement (not the animating value, so movement stays consistent during the tween).

### 3. Camera-relative movement (player.gd)

Replace world-aligned direction with camera-rotated direction:

```gdscript
@export var camera_rig: Node3D  # Assign in inspector or via main.gd

func _physics_process(delta: float) -> void:
    # ... gravity, jump unchanged ...

    var input_dir := Vector2.ZERO
    if Input.is_action_pressed("move_forward"):
        input_dir.y -= 1
    if Input.is_action_pressed("move_back"):
        input_dir.y += 1
    if Input.is_action_pressed("move_left"):
        input_dir.x -= 1
    if Input.is_action_pressed("move_right"):
        input_dir.x += 1

    var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

    # Rotate direction by camera yaw
    if camera_rig and camera_rig.has_method("get_yaw_radians"):
        var yaw := camera_rig.get_yaw_radians()
        direction = direction.rotated(Vector3.UP, yaw)

    # Apply velocity...
```

The rotation uses `Vector3.rotated(Vector3.UP, yaw)` — a single-axis rotation around Y.

### 4. Wiring (main.gd or level setup)

After loading the level and player, assign the camera reference:

```gdscript
player.camera_rig = camera_rig
```

Or assign via inspector if player is instanced in the level scene and camera_rig is accessible.

---

## Implementation checklist

1. Add `rotate_left` and `rotate_right` input actions to `project.godot`.
2. Update `camera_rig.gd` with rotation logic and `get_yaw_radians()`.
3. Update `player.gd` with `@export var camera_rig: Node3D` and camera-relative direction math.
4. Wire camera_rig to player in `main.gd` (or inspector).
5. Run godot-verify.
6. F5: press Q/E, camera snaps 90 degrees with tween; WASD moves player in screen-relative directions.

---

## Out of scope

| Item | Reason |
|------|--------|
| 45-degree steps | More directions than needed; increases shimmer risk. Add later if gameplay requires. |
| Texel-snapping mitigation | Known consequence: discrete steps help but do not eliminate shimmer at non-axis-aligned yaws. Mitigation (shader-based pixel snapping) is a separate slice. |
| Camera-relative facing (player model rotates to face movement direction) | No player model yet; capsule has no facing. |
| Rotation indicator UI | Polish, not POC. |
| Gamepad input for rotation | Shoulder buttons would map naturally; add when gamepad support is scoped. |

---

## Skill notes

- **godot-camera-rig**: This pattern extends the rig from that skill. Pitch stays at -30 degrees; only yaw rotates.
- **godot-verify**: Mandatory after changes to camera_rig.gd, player.gd, and project.godot.
- **CLAUDE.md convention**: Input actions must match the existing format in project.godot (same InputEventKey structure).

---

## Texel-snapping consequence (acknowledged risk)

Rotating the orthographic camera to non-axis-aligned yaws (45, 135, 225, 315 degrees) can cause sub-pixel shimmer because world geometry no longer aligns to screen pixels. The baseline yaw (45 degrees) already has this property.

Mitigations (all deferred):
- Shader-based texel snapping (snap world UVs to texel grid).
- Restricting rotation to 0/90/180/270 degrees only (axis-aligned, shimmer-free, but changes the visual style).
- Post-process pixelation that re-samples at exact integer coordinates.

For POC, the shimmer is acceptable. Note it in the "Later" list.

---

## Later

- Texel-snapping / shimmer mitigation shader.
- 45-degree step option (8 directions).
- Rotation indicator UI (compass or arrow).
- Gamepad shoulder-button rotation.
- Camera-relative player facing (rotate model toward movement direction).
- **Hold-to-spin mode**: tap Q/E = 90° snap tween; hold past a threshold = continuous smooth rotation at a configurable degrees/sec. Both modes coexist; the design doc for this slice is not yet written.

---

## Open questions

None blocking implementation. The pattern is complete.
