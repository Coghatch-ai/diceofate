# tools/lib/enemy/boss_data.gd — typed Resource carrying all boss tunables (data-driven).
class_name BossData
extends Resource
## Boss configuration: health, mechanic cadence, charge/volley/slam params.
## All numbers live here; boss.gd reads them. New balance pass = edit the .tres only.

@export_group("Identity")
@export var display_name: String = "The Warden"
@export var tint_color: Color = Color(0.6, 0.1, 0.1, 1.0)

@export_group("Health")
@export_range(10, 500, 1) var max_health: int = 80
@export_range(1, 100, 1) var score_value: int = 50
## Uniform scale applied to mesh node and collision shape at spawn. 1.0 = default size.
## 2.5–3.0 makes the boss visually and physically huge.
@export_range(0.5, 5.0, 0.1) var body_scale: float = 1.0

@export_group("Resistances")
## DamageType.Kind (int) → float multiplier. 0.0 = immune. Mirrors EnemyArchetype convention.
## Example: {4: 0.0} = POISON immune.
@export var resistances: Dictionary = {}

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 4.5
## Speed boss moves toward/around the player during idle and recover phases.
## Keeps the boss always-moving; 0 = stand still (old behaviour).
@export_range(0.0, 15.0, 0.1) var idle_move_speed: float = 2.5
## Speed of slow drift toward player during telegraph (visual tell; never zero).
@export_range(0.0, 8.0, 0.1) var telegraph_drift_speed: float = 1.0
@export_range(1.0, 40.0, 0.5) var detect_range: float = 25.0
@export_range(1.0, 60.0, 0.5) var escape_range: float = 40.0

@export_group("Mechanic Cadence")
## Seconds the boss idles (moves toward player) between mechanics (post-recover).
@export_range(0.1, 5.0, 0.1) var idle_duration: float = 0.6
## Seconds spent telegraphing (drifts + faces player) before executing.
@export_range(0.1, 3.0, 0.1) var telegraph_duration: float = 0.6
## Seconds in recovery (keeps moving) after each mechanic before next idle.
@export_range(0.1, 3.0, 0.1) var recover_duration: float = 0.5

@export_group("Charge")
## Speed during the dash phase (m/s).
@export_range(5.0, 40.0, 0.5) var charge_speed: float = 18.0
## Max seconds the dash lasts before auto-stopping.
@export_range(0.2, 2.0, 0.05) var charge_duration: float = 0.5
## Contact damage dealt when body touches the player during a charge.
@export_range(1, 100, 1) var charge_damage: int = 30
## Push force (m/s) applied to the player on charge contact via apply_knockback speed_override.
## -1 = use the player's own knockback_speed export (no boss override).
@export_range(-1.0, 60.0, 0.5) var knockback_impulse: float = 14.0

@export_group("Volley")
## Number of projectiles in the burst spread.
@export_range(1, 12, 1) var volley_count: int = 5
## Horizontal spread cone half-angle in degrees.
@export_range(0.0, 60.0, 1.0) var volley_spread_deg: float = 20.0
## Delay between consecutive shots in the volley (seconds).
@export_range(0.05, 1.0, 0.05) var volley_shot_interval: float = 0.15
## Projectile scene to spawn. Must be a Projectile (Area3D).
@export var volley_projectile_scene: PackedScene

@export_group("Slam")
## AoE radius of the ground slam in metres.
@export_range(1.0, 20.0, 0.5) var slam_radius: float = 6.0
## Damage dealt to the player if within slam_radius at detonation.
@export_range(1, 150, 1) var slam_damage: int = 40
## Inner slam wind-up duration (seconds) — additional tell after the generic telegraph.
## The player sees the scale pulse + floor warning ring grow before AoE hits.
@export_range(0.1, 2.0, 0.05) var slam_inner_telegraph: float = 0.5
## Scale pulse applied to the boss mesh during the inner wind-up (squish X/Z, compress Y).
## Controls the squish/stretch ratio of the boss body as a visual wind-up cue.
@export var slam_telegraph_scale: Vector3 = Vector3(1.3, 0.7, 1.3)
## Optional shockwave VFX scene (ShockwaveRing) spawned at detonation impact.
## Null = no ring effect. The growing floor warning ring is built in code (no scene needed).
@export var slam_vfx_scene: PackedScene

@export_group("HP Phase")
## When boss HP drops to or below this fraction (0–1), next idle switches to
## more frequent volley. 0 = no phase shift.
@export_range(0.0, 1.0, 0.05) var phase2_hp_fraction: float = 0.4
## In phase 2: idle_duration is multiplied by this (e.g. 0.5 = twice as fast).
@export_range(0.1, 1.0, 0.05) var phase2_cadence_mult: float = 0.6

@export_group("Color Phases")
## Ordered vulnerability schedule. Each phase: one damage type hurts (all others 0.0 = immune).
## Empty = no color-phase system (plain HP boss). boss_prism.tres fills this with 3 phases.
@export var color_phases: Array[BossColorPhase] = []
## Seconds between automatic color-phase display advances (timer-driven visual cycle).
## 0.0 = disabled (phase advances only on HP chunk completion). > 0 enables cyclic immunity
## swap every N seconds, independent of damage. boss_slime.tres uses 4.0.
@export_range(0.0, 30.0, 0.5) var color_cycle_interval: float = 0.0

@export_group("Attacks")
## Ordered list of BossAttack component scenes (each root extends BossAttack).
## Boss drives them round-robin: telegraph → start/tick → recover → repeat.
## Empty = legacy hardcoded Charge/Slam behaviour (no-op fallback in boss.gd).
@export var attacks: Array[PackedScene] = []

@export_group("Explosion")
## AoE radius of the final explosion (metres). 0 = no explosion.
@export_range(0.0, 30.0, 0.5) var explode_radius: float = 0.0
## Damage dealt to player within explode_radius at detonation.
@export_range(0, 200, 1) var explode_damage: int = 60
## Knockback speed applied to player within explode_radius (m/s). 0 = no knockback.
@export_range(0.0, 60.0, 0.5) var explode_knockback: float = 20.0
## Optional shockwave ring VFX scene (oneshot). Null = no shockwave ring.
@export var explode_vfx_scene: PackedScene
## Optional death burst VFX scene (oneshot). Null = no burst.
@export var explode_burst_scene: PackedScene
