# entities/weapon/sprint_sway.gd — procedural sprint view-model pose + sine sway layer.
# Sits between the view-model Node3D (tween target) and the mesh/muzzle children so
# tweens write the parent's transform and sprint sway writes this node's local transform.
class_name SprintSway
extends Node3D

## Local position offset applied at full sprint weight (lower + swing to the side).
@export var sprint_pose_pos: Vector3 = Vector3(0.18, -0.15, 0.05)
## Local rotation offset (degrees) at full sprint weight. Roll (-Z) dominant.
@export var sprint_pose_rot: Vector3 = Vector3(-12.0, 8.0, -18.0)
## Peak roll sway amplitude (degrees) — dominant arm-swing term.
@export var sway_roll_deg: float = 8.0
## Lateral sway amplitude (degrees) — subtle side drift.
@export var sway_lateral_deg: float = 2.5
## Vertical sway amplitude (degrees) — bounce at 2x roll frequency.
@export var sway_vert_deg: float = 3.5
## Forward (Z) sway amplitude (meters) — small fore-aft rhythm.
@export var sway_fwd_m: float = 0.008
## Base sway frequency (Hz) — roll runs at this; vertical at 2x.
@export var sway_freq: float = 1.6
## Lerp rate entering sprint pose (weight 0→1).
@export var enter_lerp: float = 8.0
## Lerp rate exiting sprint pose normally (weight 1→0).
@export var exit_lerp: float = 12.0
## Lerp rate on interrupt (fire / ADS / reload / swap — snap back fast).
@export var interrupt_lerp: float = 20.0

var _sprint_weight: float = 0.0
var _phase: float = 0.0
var _was_sprinting: bool = false


## Called every physics frame by weapon.gd. Weapon supplies composite gate booleans.
func update_sprint(
	is_sprinting: bool,
	velocity_factor: float,
	is_aiming: bool,
	is_firing: bool,
	is_reloading: bool,
	is_swapping: bool,
	delta: float
) -> void:
	# Composite gate: all weapon-busy states suppress the pose.
	var gate_open: bool = (
		is_sprinting and not is_aiming and not is_firing and not is_reloading and not is_swapping
	)

	# Detect sprint enter → reset phase for a clean sway start.
	if gate_open and not _was_sprinting:
		_phase = 0.0
	_was_sprinting = gate_open

	# Asymmetric lerp: interrupt rate when a busy flag is raised during sprint.
	var interrupted: bool = is_sprinting and (is_aiming or is_firing or is_reloading or is_swapping)
	var rate: float
	if gate_open:
		rate = enter_lerp
	elif interrupted:
		rate = interrupt_lerp
	else:
		rate = exit_lerp

	_sprint_weight = lerpf(_sprint_weight, 1.0 if gate_open else 0.0, rate * delta)

	# Phase always advances so sway doesn't stutter when re-entering.
	_phase += delta * sway_freq

	var amp: float = _sprint_weight * velocity_factor

	# Sine sway terms (all in degrees for rotation, meters for position).
	var roll: float = sin(_phase * TAU) * sway_roll_deg * amp
	# Vertical at 2x frequency (two bounces per arm-swing cycle).
	var vert: float = sin(_phase * TAU * 2.0) * sway_vert_deg * amp
	# Lateral at base frequency, quarter-phase offset from roll.
	var lateral: float = sin(_phase * TAU + PI * 0.5) * sway_lateral_deg * amp
	# Forward at base frequency.
	var fwd: float = sin(_phase * TAU) * sway_fwd_m * amp

	# Compose: base sprint pose scaled by weight + sway on top.
	var w: float = _sprint_weight
	position = sprint_pose_pos * w + Vector3(lateral * 0.001, vert * 0.001, fwd)
	rotation_degrees = sprint_pose_rot * w + Vector3(vert, lateral, roll)
