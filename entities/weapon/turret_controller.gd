# entities/weapon/turret_controller.gd — shoulder turret: acquire, rotate-to-aim, fire-when-aligned.
# Additive auto-weapon: never touches WeaponController or the player rifle.
class_name TurretController
extends Node

## Emitted each time the turret fires (0-arg; listeners add juice if desired).
signal turret_fired
## Emitted when a valid target is acquired (carries the target node for VFX/HUD hooks).
signal target_acquired(target: Node3D)

## Acquisition config resource (turret_acquisition.tres).
@export var acquisition_cfg: TargetAcquisitionConfig
## The Gun node that fires (shoulder_turret.tscn root, injected by player.gd _ready()).
@export var gun: Gun
## The Marker3D muzzle used as the acquisition origin.
@export var turret_muzzle: Marker3D
## The Node3D pivot that rotates to face the target.
@export var turret_pivot: Node3D
## Rotation speed in degrees per second toward the target.
@export_range(10.0, 720.0, 5.0) var turn_rate_deg_s: float = 180.0
## Fire when pivot forward is within this many degrees of the direction to target.
@export_range(1.0, 45.0, 0.5) var alignment_tolerance_deg: float = 6.0
## Minimum seconds between shots (independent of turn rate).
@export_range(0.1, 10.0, 0.1) var fire_cooldown: float = 0.8
## Re-acquisition interval in seconds (0 = re-acquire every frame).
@export_range(0.0, 10.0, 0.1) var reacquire_interval: float = 0.5

var _current_target: Node3D = null
var _fire_timer: float = 0.0
var _reacquire_timer: float = 0.0


func _ready() -> void:
	# Start with cooldown partially elapsed so turret doesn't fire on the very first frame.
	_fire_timer = fire_cooldown * 0.5


func _physics_process(delta: float) -> void:
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_reacquire_timer = maxf(0.0, _reacquire_timer - delta)

	# Re-acquire on interval (or immediately if no target).
	if _reacquire_timer <= 0.0 or not is_instance_valid(_current_target):
		_reacquire()
		_reacquire_timer = reacquire_interval

	if not is_instance_valid(_current_target):
		return
	if turret_pivot == null:
		return

	# Smooth rotation toward target each physics frame.
	var dir: Vector3 = _current_target.global_position - turret_pivot.global_position
	if dir.length_squared() < 0.0001:
		return

	dir = dir.normalized()
	var up: Vector3 = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD

	var target_basis: Basis = Basis.looking_at(dir, up)
	var current_quat: Quaternion = turret_pivot.global_transform.basis.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()

	# Slerp by turn_rate_deg_s per second — clamp to avoid overshoot.
	var max_angle_rad: float = deg_to_rad(turn_rate_deg_s) * delta
	var angle_between: float = current_quat.angle_to(target_quat)
	var t: float = 1.0
	if angle_between > 0.0001:
		t = minf(1.0, max_angle_rad / angle_between)
	turret_pivot.global_transform.basis = Basis(current_quat.slerp(target_quat, t))

	# Fire only when aligned AND cooldown elapsed.
	if _fire_timer > 0.0:
		return

	var pivot_forward: Vector3 = -turret_pivot.global_transform.basis.z
	var angle_to_target: float = rad_to_deg(pivot_forward.angle_to(dir))
	if angle_to_target <= alignment_tolerance_deg:
		_do_fire()


func _reacquire() -> void:
	if acquisition_cfg == null or turret_muzzle == null:
		_current_target = null
		return
	var t: Node3D = TargetAcquisitionConfig.acquire(turret_muzzle, acquisition_cfg)
	if t != _current_target and t != null:
		target_acquired.emit(t)
	_current_target = t


func _do_fire() -> void:
	if gun == null:
		return
	var did_fire: bool = gun.try_fire()
	if did_fire:
		_fire_timer = fire_cooldown
		turret_fired.emit()


## Run one acquire→fire cycle synchronously (called by smoke to assert seam).
func _run_cycle() -> void:
	_reacquire()
	if not is_instance_valid(_current_target):
		return
	if turret_pivot == null:
		_do_fire()
		return
	# Snap pivot to target for smoke test (no delta available).
	var dir: Vector3 = (_current_target.global_position - turret_pivot.global_position).normalized()
	var up: Vector3 = Vector3.UP
	if abs(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	turret_pivot.global_transform.basis = Basis.looking_at(dir, up)
	_do_fire()
