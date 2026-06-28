# entities/grenade/grenade_data.gd — data resource for grenade tuning params.
class_name GrenadeData
extends Resource

@export_group("Throw")
@export_range(5.0, 40.0, 0.5) var throw_force: float = 18.0
## Upward arc component added to throw impulse.
@export_range(0.0, 15.0, 0.5) var arc_force: float = 6.0

@export_group("Fuse")
@export_range(0.5, 5.0, 0.1) var fuse_time: float = 1.5

@export_group("Blast")
@export_range(1.0, 20.0, 0.5) var blast_radius: float = 5.0
@export_range(1, 200, 1) var damage: int = 60

@export_group("Cooldown")
@export_range(0.1, 5.0, 0.1) var cooldown: float = 1.0
