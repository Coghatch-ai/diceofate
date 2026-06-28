# tools/lib/weapon/weapon_data.gd — feel/firing tunables for a single weapon variant.
class_name WeaponData
extends Resource

@export_group("Fire Rate")
## Seconds between shots (Timer cooldown wait_time).
@export_range(0.01, 5.0, 0.01) var fire_rate: float = 0.2

@export_group("Spread")
## Cone half-angle (degrees) for hip-fire spread.
@export_range(0.0, 45.0, 0.1) var spread_hip: float = 2.5
## Cone half-angle (degrees) for ADS spread.
@export_range(0.0, 45.0, 0.1) var spread_ads: float = 0.3
## Spread multiplier when crouched (stacks with ADS; 1.0 = no effect).
@export_range(0.0, 2.0, 0.05) var crouch_spread_mult: float = 0.5

@export_group("Recoil")
## Pitch impulse (radians) added to player recoil per shot.
@export_range(0.0, 1.0, 0.001) var recoil_pitch: float = 0.08
## Max yaw jitter (radians) per shot.
@export_range(0.0, 1.0, 0.001) var recoil_yaw: float = 0.03
