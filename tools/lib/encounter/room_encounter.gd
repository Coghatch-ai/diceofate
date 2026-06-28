# tools/lib/encounter/room_encounter.gd — data for one scripted room encounter.
class_name RoomEncounter
extends Resource

@export_group("Identity")
@export var id: StringName = &""

@export_group("Spawns")
## Ordered list of archetype+marker pairs to spawn when this room arms.
@export var spawns: Array[RoomSpawn] = []

@export_group("Teaching")
## Transient HUD hint shown when the room arms. Empty = no hint.
@export var hint_text: String = ""

@export_group("Progression")
## When true: all spawned enemies dead → emit room_cleared(id) and open the door.
@export var clear_advances: bool = true
