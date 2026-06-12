extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 2.5
@export var camera_rig: Node3D

var inventory: Array[String] = []
var _gravity: float

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Handle jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# Get input direction
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# Apply horizontal movement
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Rotate direction by camera yaw
	if camera_rig and camera_rig.has_method("get_yaw_radians"):
		var yaw: float = camera_rig.get_yaw_radians()
		direction = direction.rotated(Vector3.UP, yaw)

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

func add_item(item: String) -> void:
	inventory.append(item)
	print("Inventory: ", inventory)
