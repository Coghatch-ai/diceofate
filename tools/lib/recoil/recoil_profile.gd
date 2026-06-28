# tools/lib/recoil/recoil_profile.gd — data Resource: per-bullet recoil climb pattern.
# Attached to CastData.recoil_profile. Null = fall back to Gun scalar recoil_pitch/yaw.
class_name RecoilProfile
extends Resource

@export_group("Pitch")
## Climb shape over consecutive-shot index. X axis = 0..1 normalised by shots_to_plateau.
## Y axis = impulse scale multiplier. Null = flat 1.0 (current scalar behaviour).
@export var pitch_curve: Curve
## Base pitch impulse (radians) per shot, scaled by pitch_curve.
## Decouples shape from magnitude: change amplitude without redrawing the curve.
@export_range(0.0, 0.5, 0.001) var pitch_amplitude: float = 0.08

@export_group("Yaw")
## Horizontal sway shape per shot index. X axis = 0..1, Y = scale. Null = flat 1.0.
@export var yaw_curve: Curve
## Base yaw jitter (radians) per shot, scaled by yaw_curve.
@export_range(0.0, 0.3, 0.001) var yaw_amplitude: float = 0.03
## Fraction of yaw impulse that is randomised ±.
## 1.0 = fully random (current behaviour). 0.0 = deterministic pattern only.
@export_range(0.0, 1.0, 0.01) var yaw_random: float = 1.0

@export_group("Climb")
## Consecutive shots the curve spans before holding at its end value.
## Curve X is normalised by this: shot 0 → X=0, shot shots_to_plateau-1 → X=1.
@export_range(1, 30, 1) var shots_to_plateau: int = 6


## Sample pitch impulse for the given consecutive shot index.
## Returns radians of pitch kick to add to the recoil accumulator.
func sample_pitch(shot_index: int) -> float:
	var t: float = clampf(float(shot_index) / maxf(1.0, float(shots_to_plateau - 1)), 0.0, 1.0)
	var scale: float = pitch_curve.sample(t) if pitch_curve != null else 1.0
	return pitch_amplitude * scale


## Sample yaw impulse for the given consecutive shot index.
## Returns signed radians of yaw kick (positive or negative, depending on yaw_random).
func sample_yaw(shot_index: int) -> float:
	var t: float = clampf(float(shot_index) / maxf(1.0, float(shots_to_plateau - 1)), 0.0, 1.0)
	var scale: float = yaw_curve.sample(t) if yaw_curve != null else 1.0
	var base: float = yaw_amplitude * scale
	# Blend deterministic base with randomised fraction.
	var deterministic: float = base * (1.0 - yaw_random)
	var randomised: float = randf_range(-base, base) * yaw_random
	return deterministic + randomised
