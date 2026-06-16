# entities/player/player.gd — first-person movement, mouse-look, jump, weapon firing, camera kick.
class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var kick_angle: float = 0.04
@export var kick_duration: float = 0.08

# SEAM: ProjectSettings.get_setting() returns Variant; the physics gravity setting is always float.
@warning_ignore("unsafe_cast")
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _was_on_floor: bool = false
var _crosshair: Crosshair

@onready var _head: Node3D = $Head
@onready var _weapon: Weapon = $Head/Weapon
@onready var _jump_sfx: AudioStreamPlayer = $JumpSfx
@onready var _land_sfx: AudioStreamPlayer = $LandSfx


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_weapon.fired.connect(_on_weapon_fired)
	_weapon.hit_confirmed.connect(_on_hit_confirmed)


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_crosshair = crosshair


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
	var on_floor_now: bool = is_on_floor()

	# 1. Gravity while airborne.
	if not on_floor_now:
		velocity.y -= _gravity * delta

	# 2. Jump only when grounded.
	if Input.is_action_just_pressed("jump") and on_floor_now:
		velocity.y = jump_velocity
		_jump_sfx.play()

	# 3. Land detection: floor transition airborne → grounded.
	if on_floor_now and not _was_on_floor:
		_land_sfx.play()

	_was_on_floor = on_floor_now

	# 4. Movement relative to where the body faces (yaw).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	# 5. Fire on left-click (held); cooldown timer caps cadence, not input.
	if Input.is_action_pressed("shoot"):
		_weapon.try_fire()

	# 6. Engine resolves collisions and updates position.
	move_and_slide()


func _on_weapon_fired() -> void:
	_do_camera_kick()
	if _crosshair != null:
		_crosshair.fire_pop()


func _on_hit_confirmed() -> void:
	if _crosshair != null:
		_crosshair.hit_pop()


func _do_camera_kick() -> void:
	var base_x: float = _head.rotation.x
	var tw := create_tween()
	# Kick up (negative X = look up in Godot pitch convention).
	tw.tween_property(_head, "rotation:x", base_x - kick_angle, kick_duration * 0.3)
	tw.tween_property(_head, "rotation:x", base_x, kick_duration)
