# levels/iron_floor.gd — Iron Floor level: boss door, boss wiring, fall-damage respawn.
# Boss placed in scene; Door_R12 opens when R10 clears. Boss death → complete_run().
# FallZone below floor → player repositioned to PlayerSpawn + takes fall_damage.
extends Node

const _R10_ID: StringName = &"iron_r10"

## Damage applied on a fall (25% of default 100 HP — meaningful penalty, not a one-shot).
@export_range(1, 100, 1) var fall_damage: int = 25

@onready var _room_controller: RoomController = $RoomController
@onready var _boss_door: StaticBody3D = $Door_R12
@onready var _boss: Boss = $Boss
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _fall_zone: Area3D = $FallZone
@onready var _player_spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	NavUtils.ensure_baked(_nav_region)
	_room_controller.encounter_cleared.connect(_on_encounter_cleared)
	if is_instance_valid(_boss):
		_boss.died.connect(_on_boss_died)
	_fall_zone.body_entered.connect(_on_fall_zone_entered)


func _on_encounter_cleared(room_id: StringName) -> void:
	if room_id != _R10_ID:
		return
	_open_boss_door()


func _open_boss_door() -> void:
	if _boss_door == null:
		return
	for child: Node in _boss_door.get_children():
		if child is MeshInstance3D:
			# SEAM: child is MeshInstance3D by guard above.
			@warning_ignore("unsafe_cast")
			(child as MeshInstance3D).visible = false
	for child: Node in _boss_door.get_children():
		if child is CollisionShape3D:
			# SEAM: set_deferred on CollisionShape3D.disabled — safe during physics step.
			@warning_ignore("unsafe_cast")
			(child as CollisionShape3D).set_deferred(&"disabled", true)
	_boss_door.visible = false


func _on_boss_died(_boss_node: Boss) -> void:
	var sv: int = 0
	if is_instance_valid(_boss_node):
		sv = _boss_node.score_value
	_room_controller.complete_run(sv)


## Teleport any body that falls below the arena back to the player spawn point, then apply
## fall_damage via the player's apply_damage seam. Reposition first so the damage feedback
## (screen flash, etc.) plays at the respawn location, not mid-fall.
## Only CharacterBody3D in the "player" group is expected; others ignored.
func _on_fall_zone_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	# SEAM: duck-typed — any CharacterBody3D in group "player" with velocity property.
	@warning_ignore("unsafe_property_access")
	body.velocity = Vector3.ZERO
	body.global_position = _player_spawn.global_position
	# SEAM: duck-typed — player exposes apply_damage(amount, type) (player.gd); default type PHYSICAL.
	@warning_ignore("unsafe_method_access")
	body.apply_damage(fall_damage)
