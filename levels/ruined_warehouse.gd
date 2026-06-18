# levels/ruined_warehouse.gd — Ruined Warehouse level root; handles fall-through respawn.
class_name RuinedWarehouse
extends Node3D

## Player spawn cell (6,1) → world pos, facing south (+Z).
const SPAWN_POS: Vector3 = Vector3(12.0, 1.0, 2.0)
const SPAWN_ROT_Y: float = PI

@onready var _fall_zone: Area3D = $FallZone


func _ready() -> void:
	_fall_zone.body_entered.connect(_on_FallZone_body_entered)


# Teleport player body back to spawn — no life cost (design: snap only).
func _reset_player(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	body.global_position = SPAWN_POS
	body.rotation.y = SPAWN_ROT_Y
	# SEAM: duck-typed reset — velocity is on CharacterBody3D, not Node3D base.
	@warning_ignore("unsafe_property_access")
	body.velocity = Vector3.ZERO


func _on_FallZone_body_entered(body: Node3D) -> void:
	print("[trap] fell through -> reset")
	_reset_player(body)
