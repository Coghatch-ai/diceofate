# tools/smoke_resource_registry.gd — headless smoke: ArchetypeRegistry scan + lookup asserts.
extends SceneTree


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var reg: ArchetypeRegistry = (
		load("res://archetypes/archetype_registry.tres") as ArchetypeRegistry
	)
	assert(reg != null, "SMOKE FAIL: could not load archetype_registry.tres")

	# Known id resolves to EnemyArchetype with expected field.
	var grunt: EnemyArchetype = reg.get_archetype(&"grunt")
	assert(grunt != null, "SMOKE FAIL: get_archetype('grunt') returned null")
	assert(grunt.id == &"grunt", "SMOKE FAIL: grunt.id mismatch")
	assert(grunt.max_health > 0, "SMOKE FAIL: grunt.max_health not positive")

	# has_id for present + absent ids.
	assert(reg.has_id(&"tank"), "SMOKE FAIL: has_id('tank') false")
	assert(not reg.has_id(&"nonexistent_xyz"), "SMOKE FAIL: has_id('nonexistent_xyz') true")

	# ids() returns 6 EnemyArchetype entries; archetype_registry.tres has no id — skipped.
	var all_ids: Array[StringName] = reg.ids()
	assert(all_ids.size() == 6, "SMOKE FAIL: expected 6 archetypes, got %d" % all_ids.size())

	print("SMOKE OK: ArchetypeRegistry — %d archetypes loaded" % all_ids.size())
