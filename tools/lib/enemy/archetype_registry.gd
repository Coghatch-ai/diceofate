# tools/lib/enemy/archetype_registry.gd — ArchetypeRegistry: id-keyed catalog over archetypes/.
class_name ArchetypeRegistry
extends ResourceRegistry

## Thin subclass — FOLDER + typed accessor only. All scan/lookup logic in ResourceRegistry.

const FOLDER: String = "res://archetypes/"


## Typed wrapper over ResourceRegistry.get_by_id().
## GDScript has no generics; base returns Resource, we cast here.
func get_archetype(id: StringName) -> EnemyArchetype:
	# SEAM: base get_by_id returns Resource; cast to family type here.
	@warning_ignore("unsafe_cast")
	return get_by_id(id) as EnemyArchetype
