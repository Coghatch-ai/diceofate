# entities/player/player.gd — first-person movement, mouse-look, jump, and weapon firing.
class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002

# SEAM: ProjectSettings.get_setting() returns Variant; the physics gravity setting is always float.
@warning_ignore("unsafe_cast")
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@onready var _head: Node3D = $Head
@onready var _weapon: Weapon = $Head/Weapon


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

	# 4. Fire on left-click (held); cooldown timer caps cadence, not input.
	if Input.is_action_pressed("shoot"):
		_weapon.try_fire()

	# 5. Engine resolves collisions and updates position.
	move_and_slide()
