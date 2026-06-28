# tools/lib/enemy/boss_color_phase.gd — one color phase in the boss VulnerabilitySchedule.
# Holds damage type vulnerability, HP chunk, body scale, and visual hints for slice 2.
class_name BossColorPhase
extends Resource

@export_group("Combat")
## Damage type the boss is VULNERABLE to during this phase (all others → 0.0 = immune).
@export var damage_type: DamageType.Kind = DamageType.Kind.FIRE
## HP pool consumed before advancing to the next phase.
@export_range(1, 500, 1) var phase_hp: int = 10

@export_group("Body")
## Mesh + collision scale while this phase is active. Ramps up per phase for visual growth.
@export_range(0.5, 8.0, 0.1) var body_scale: float = 2.0

@export_group("Visuals (slice 2)")
## Base albedo tint applied to the boss material on phase entry (slice 2 reads this).
@export var albedo: Color = Color(1.0, 0.25, 0.05, 1.0)
## Emission tint for the phase (slice 2 reads this).
@export var emission: Color = Color(1.0, 0.15, 0.0, 1.0)
