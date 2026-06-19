# entities/weapon/sprint_sway.gd — procedural walk/sprint view-model pose + sine sway layer.
# Sits between the view-model Node3D (tween target) and the mesh/muzzle children so
# tweens write the parent's transform and sprint sway writes this node's local transform.
class_name SprintSway
extends Node3D

## Local position offset applied at full sprint weight (lower + swing to the side).
@export var sprint_pose_pos: Vector3 = Vector3(0.18, -0.15, 0.05)
## Local rotation offset (degrees) at full sprint weight. Roll (-Z) dominant.
@export var sprint_pose_rot: Vector3 = Vector3(-12.0, 8.0, -18.0)
## Peak roll sway amplitude (degrees) at full sprint — dominant arm-swing term.
@export var sway_roll_deg: float = 8.0
## Lateral sway amplitude (degrees) at full sprint — subtle side drift.
@export var sway_lateral_deg: float = 2.5
## Vertical sway amplitude (degrees) at full sprint — bounce at 2x roll frequency.
@export var sway_vert_deg: float = 3.5
## Forward (Z) sway amplitude (meters) at full sprint — small fore-aft rhythm.
@export var sway_fwd_m: float = 0.008
## Base sway frequency (Hz) — roll runs at this; vertical at 2x.
@export var sway_freq: float = 1.6
## Walk sway amplitude scale relative to sprint (0..1). Sway felt at walk speed.
@export var walk_sway_scale: float = 0.25
## Walk pose position scale relative to sprint_pose_pos (subtle lowering while walking).
@export var walk_pose_scale: float = 0.12
## Lerp rate entering sprint pose (weight 0→1).
@export var enter_lerp: float = 8.0
## Lerp rate exiting sprint pose normally (weight 1→0).
@export var exit_lerp: float = 12.0
## Lerp rate on interrupt (fire / ADS / reload / swap — snap back fast).
@export var interrupt_lerp: float = 20.0

var _sprint_weight: float = 0.0
var _walk_weight: float = 0.0
var _phase: float = 0.0
var _was_active: bool = false


## Called every physics frame by weapon.gd. is_moving = any ground movement (walk or sprint).
func update_sprint(
	is_sprinting: bool,
	is_moving: bool,
	velocity_factor: float,
	is_aiming: bool,
	is_firing: bool,
	is_reloading: bool,
	is_swapping: bool,
	delta: float
) -> void:
	# Busy flags suppress both sprint and walk sway.
	var busy: bool = is_aiming or is_firing or is_reloading or is_swapping
	var sprint_gate: bool = is_sprinting and not busy
	var walk_gate: bool = is_moving and not is_sprinting and not busy

	# Reset phase on enter from fully idle so sway starts at neutral.
	var is_active: bool = sprint_gate or walk_gate
	if is_active and not _was_active:
		_phase = 0.0
	_was_active = is_active

	# Asymmetric lerp rates.
	var interrupted: bool = is_sprinting and busy
	var sprint_rate: float
	if sprint_gate:
		sprint_rate = enter_lerp
	elif interrupted:
		sprint_rate = interrupt_lerp
	else:
		sprint_rate = exit_lerp

	var walk_rate: float = enter_lerp if walk_gate else exit_lerp

	_sprint_weight = lerpf(_sprint_weight, 1.0 if sprint_gate else 0.0, sprint_rate * delta)
	_walk_weight = lerpf(_walk_weight, 1.0 if walk_gate else 0.0, walk_rate * delta)

	# Phase always advances so sway doesn't stutter when re-entering.
	_phase += delta * sway_freq

	# Sprint amp driven by velocity_factor; walk amp uses walk_sway_scale.
	var sprint_amp: float = _sprint_weight * velocity_factor
	var walk_amp: float = _walk_weight * velocity_factor * walk_sway_scale

	# Combined amplitude — sprint dominates when both weights non-zero (impossible in gate logic,
	# but guarded by the gate so only one is active; max is safe either way).
	var amp: float = maxf(sprint_amp, walk_amp)

	# Sine sway terms (degrees for rotation, meters for position).
	var roll: float = sin(_phase * TAU) * sway_roll_deg * amp
	var vert: float = sin(_phase * TAU * 2.0) * sway_vert_deg * amp
	var lateral: float = sin(_phase * TAU + PI * 0.5) * sway_lateral_deg * amp
	var fwd: float = sin(_phase * TAU) * sway_fwd_m * amp

	# Pose offset: sprint full pose + walk subtle fraction.
	var pose_w: float = _sprint_weight + _walk_weight * walk_pose_scale
	position = sprint_pose_pos * pose_w + Vector3(lateral * 0.001, vert * 0.001, fwd)
	rotation_degrees = sprint_pose_rot * pose_w + Vector3(vert, lateral, roll)
