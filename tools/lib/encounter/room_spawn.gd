# tools/lib/encounter/room_spawn.gd — one archetype-at-marker spawn pair for RoomEncounter.
class_name RoomSpawn
extends Resource

@export var archetype: EnemyArchetype
## Node name of the Marker3D in the level scene that identifies the spawn point.
@export var spawn_marker_id: StringName = &""
