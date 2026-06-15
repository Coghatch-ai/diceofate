---
name: godot-first-person-controller
description: First-person CharacterBody3D player in Godot 4.6 — yaw the body / pitch a child Head holding a perspective eye-camera, raw mouse-look, camera-relative WASD, gravity from ProjectSettings, jump on is_on_floor. Use when building an FPS player entity, when a first-person genre needs its controller, when the view must look out through the player's eyes, or when mouse-look pitch/yaw or camera-relative movement misbehaves. NOT for top-down / isometric — that uses the orthographic follow rig (godot-orthographic-follow-camera). This is the FPS sibling of that skill; pick one per genre.
---

# Godot First-Person Controller (perspective eye-camera)

A `CharacterBody3D` is the player body; a child `Head (Node3D)` holds the `Camera3D`. Mouse X yaws the **body**, mouse Y pitches the **head** (clamped to ±90° so you can't somersault the view), and movement is taken relative to the body's facing. Splitting yaw onto the body and pitch onto the head is what keeps walking direction tied to where you look horizontally while letting you look up/down freely.

This is a **perspective** camera, and that is correct here: the 3D-pixel-art look in this project comes from the SubViewport **downscale** (skill `godot-3d-pixelation`), not from the projection. Orthographic would feel wrong in first person. The eye-camera lives **inside the SubViewport** like every other camera in the project (skill `godot-main-scene`), so it renders at the low internal resolution and gets the pixel look for free.

## Requirements

- `godot-composition` — the player is a CharacterBody3D base with component children; movement logic stays on the body, look-target on the Head child (signals up / calls down).
- `godot-3d-pixelation` — the eye-camera is the SubViewport's current Camera3D; the pixel look is the downscale.
- `godot-code-rules` — load before writing the `.gd`; strict typed GDScript, file header, explicit return types, gate `tools/validate.sh`.

## Project conventions

- Scene: `res://entities/player/player.tscn`, root `Player` (CharacterBody3D) → child `Head` (Node3D) → child `Camera3D`. Add a `CollisionShape3D` (capsule) on the root.
- Script: `res://entities/player/player.gd` on the root.
- Head local Y ≈ eye height (e.g. `1.6`); Camera3D stays at the Head origin with rotation `(0,0,0)` — pitch lives on the Head, never on the Camera3D.
- Camera3D **Projection = Perspective** (the default). Do NOT set Orthogonal here — that is the top-down rig's contract, not this one.
- The Camera3D is the current camera **inside the SubViewport** (skill `godot-3d-pixelation` / `godot-main-scene`). Exactly one current Camera3D per viewport.
- Input actions (already in the project map): `move_left`, `move_right`, `move_forward`, `move_back`, `jump`. Mouse-look is raw `InputEventMouseMotion` — no action. `ui_cancel` (Esc) releases the mouse.
- `shoot` is an **A3** action — out of scope here; do not wire it.

## Steps

1. Build the scene: `Player` (CharacterBody3D) → `CollisionShape3D` (CapsuleShape3D) + `Head` (Node3D, position Y = eye height) → `Camera3D` (child of Head, transform identity, Perspective).
2. Instance `player.tscn` inside the SubViewport (under the level / Main's host per `godot-main-scene`); make its Camera3D the current one for that viewport.
3. Attach `player.gd`:

```gdscript
# entities/player/player.gd — first-person movement, mouse-look, and jump.
class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Yaw on the body, pitch on the head (clamped so the view can't flip over).
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_head.rotate_x(-motion.relative.y * mouse_sensitivity)
		_head.rotation.x = clampf(_head.rotation.x, -PI / 2.0, PI / 2.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# 1. Gravity while airborne.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# 2. Jump only when grounded.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 3. Movement relative to where the body faces (yaw).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	# 4. Engine resolves collisions and updates position.
	move_and_slide()
```

4. Run the gate: `tools/validate.sh`. Then run `godot-verify` on the entry-point scene (this changes what F5 renders).

> Movement-loop order is fixed: read input → apply gravity → modify velocity → `move_and_slide()` → read post-move state. All of it lives in `_physics_process`, never `_process`, or movement becomes frame-rate dependent and jittery.

> **Later (parked, not in this POC):** coyote-time and jump-buffer feel-tuning (jump grace after leaving a ledge, buffered jump before landing), variable jump height (cut `velocity.y` on early release), dash and wall-jump recipes. Available in the GodotPrompter `player-controller` skill (§3, §5) if a later phase wants game feel.

## Verification checklist

- [ ] On F5 the window shows a first-person view out through the player's eyes (perspective), pixelated by the SubViewport downscale — not a top-down or floating view.
- [ ] Moving the mouse left/right turns the whole view (body yaw); up/down tilts it and **stops** at straight-up / straight-down (no somersault).
- [ ] WASD (move_forward/back/left/right) walks relative to where you're looking horizontally; strafing is perpendicular to facing.
- [ ] Jump (Space) only fires while on the floor; the player falls back down under gravity and lands.
- [ ] Esc releases the mouse (cursor reappears); the view stops following the mouse.
- [ ] Camera3D's own rotation stays `(0,0,0)`; pitch is visible on the Head node, yaw on the Player root.

## Error → Fix

| Symptom | Fix |
|---|---|
| Mouse-look inverted | Wrong sign on the delta — keep `-motion.relative.x` for yaw and `-motion.relative.y` for pitch |
| View can flip upside-down | Missing pitch clamp — `_head.rotation.x = clampf(_head.rotation.x, -PI/2.0, PI/2.0)` |
| Movement ignores where you look | Direction not taken from the basis — `transform.basis * Vector3(input_dir.x, 0, input_dir.y)` (rotates with body yaw) |
| Jittery / frame-rate-dependent movement | Movement code is in `_process` — move it all into `_physics_process(delta)` |
| Player sticks to / climbs walls | Set `floor_block_on_wall = false` (and tune `floor_max_angle`) on the CharacterBody3D |
| `UNSAFE_CALL_ARGUMENT` on the gravity line | `ProjectSettings.get_setting(...)` is a Variant — wrap it: `float(ProjectSettings.get_setting("physics/3d/default_gravity"))` |
| Window black / nothing renders | The eye-camera must be the current Camera3D **inside the SubViewport**; another active camera elsewhere steals the view (one current camera per viewport) |
| View looks flat / "too 3D" or distorted | Leave it Perspective — the pixel look is the SubViewport downscale (`godot-3d-pixelation`); do not switch to Orthogonal (that's the top-down rig) |
| Mouse never captured | `Input.mouse_mode = MOUSE_MODE_CAPTURED` must be in `_ready`; release on `ui_cancel` |

---

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
