# levels/blast_court.gd — Blast Court arena: hazard trap handler, player spawn.
class_name BlastCourt
extends Node3D

## Player spawn position (grid(8,8) → cell-center world coords).
const SPAWN_POS: Vector3 = Vector3(25.5, 1.0, 25.5)
## Player spawn rotation Y — facing +Z into arena depth.
const SPAWN_ROT_Y: float = PI

## Per-body cooldown between trap hits (seconds).
const TRAP_COOLDOWN: float = 0.5

## WaveManager sibling — injected by main.gd after level load (slice 3).
@export var wave_manager: WaveManager
## HP damage dealt to the player on each trap hit.
@export_range(1, 100, 1) var trap_damage: int = 10

# Tracks last-hit time per body (RID → float). Prevents per-frame HP drain.
var _trap_last_hit: Dictionary = {}

@onready var _trap_north: Area3D = $TrapNorthArea
@onready var _trap_south: Area3D = $TrapSouthArea


func _ready() -> void:
	_trap_north.body_entered.connect(_on_trap_body_entered)
	_trap_south.body_entered.connect(_on_trap_body_entered)


func _on_trap_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("apply_damage"):
		return
	var id: int = body.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = _trap_last_hit.get(id, -TRAP_COOLDOWN)
	if now - last < TRAP_COOLDOWN:
		return
	_trap_last_hit[id] = now
	# SEAM: duck-typed apply_damage — any body with apply_damage(int) accepted.
	@warning_ignore("unsafe_method_access")
	body.apply_damage(trap_damage)
