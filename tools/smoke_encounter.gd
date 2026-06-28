# tools/smoke_encounter.gd — headless smoke: 2-room encounter fixture.
# Asserts: spawn counts, room_cleared arity, door disabled after clear, hint_changed fires.
# Run: $GODOT --headless --path . --script tools/smoke_encounter.gd
extends SceneTree

const _PASS: String = "SMOKE_ENCOUNTER: PASS"
const _FAIL_PREFIX: String = "SMOKE_ENCOUNTER: FAIL"

var _fails: Array[String] = []
var _room_cleared_ids: Array[StringName] = []
var _hint_texts: Array[String] = []
var _room1_door: StaticBody3D
var _room2_door: StaticBody3D
var _rc: RoomController


func _init() -> void:
	_build_fixture()
	await process_frame
	await process_frame
	# Arm room 0: simulate player entering trigger.
	_rc._arm_encounter(0)
	await process_frame
	_assert_eq("room0 spawn count", _rc._room_enemies[0].size(), 2)
	_assert_eq("room0 door visible after lock", _room1_door.visible, true)
	_assert_eq("hint fires on arm", _hint_texts.size(), 1)
	_assert_eq("hint text correct", _hint_texts[0], "Test hint room 1")

	# Kill all room-0 enemies.
	var r0_enemies: Array = _rc._room_enemies[0].duplicate()
	for e: Enemy in r0_enemies as Array[Enemy]:
		e.died.emit(e)
	await process_frame
	_assert_eq("room0 cleared id", _room_cleared_ids.size(), 1)
	_assert_eq("room0 cleared id value", _room_cleared_ids[0], &"room_0")
	_assert_eq("room0 enemies after clear", _rc._room_enemies[0].size(), 0)
	# Door collider disabled after clear.
	var door_disabled: bool = false
	for child: Node in _room1_door.get_children():
		if child is CollisionShape3D:
			door_disabled = (child as CollisionShape3D).disabled
	_assert_eq("room0 door collider disabled", door_disabled, true)

	# Arm room 1.
	_rc._arm_encounter(1)
	await process_frame
	_assert_eq("room1 spawn count", _rc._room_enemies[1].size(), 1)
	_assert_eq("room1 door visible after lock", _room2_door.visible, true)

	# Assert all spawn_marker_paths resolve in _marker_registry (no "not found" gaps).
	var missing_ids: Array[StringName] = []
	for enc: RoomEncounter in _rc.encounters:
		for spawn: RoomSpawn in enc.spawns:
			if not _rc._marker_registry.has(spawn.spawn_marker_id):
				missing_ids.append(spawn.spawn_marker_id)
	_assert_eq("no unresolved spawn_marker_ids", missing_ids.size(), 0)

	_report()
	quit(0 if _fails.is_empty() else 1)


func _build_fixture() -> void:
	var scene_root := Node3D.new()
	scene_root.name = "EncounterFixture"
	root.add_child(scene_root)

	# Enemy scene: stub node that acts as Enemy.
	# RoomController instantiates enemy_scene; we need a real Enemy-compatible PackedScene.
	# Use the real enemy scene if available; skip spawn if not (then assert spawn = 0 and warn).
	var enemy_packed := load("res://entities/enemy/enemy.tscn") as PackedScene
	if enemy_packed == null:
		push_warning("smoke_encounter: enemy.tscn not found — spawn counts will be 0")

	# Build two trivial doors (StaticBody3D + CollisionShape3D + MeshInstance3D).
	_room1_door = _make_door(scene_root, "Door1")
	_room2_door = _make_door(scene_root, "Door2")

	# Build 3 markers: two for room 0, one for room 1.
	_make_marker(scene_root, "SpawnR0A", Vector3(2.0, 0.0, 0.0))
	_make_marker(scene_root, "SpawnR0B", Vector3(3.0, 0.0, 0.0))
	_make_marker(scene_root, "SpawnR1A", Vector3(10.0, 0.0, 0.0))

	# Build encounters.
	var spawn0a := RoomSpawn.new()
	spawn0a.spawn_marker_id = &"SpawnR0A"
	var spawn0b := RoomSpawn.new()
	spawn0b.spawn_marker_id = &"SpawnR0B"

	var enc0 := RoomEncounter.new()
	enc0.id = &"room_0"
	enc0.spawns = [spawn0a, spawn0b]
	enc0.hint_text = "Test hint room 1"
	enc0.clear_advances = true

	var spawn1a := RoomSpawn.new()
	spawn1a.spawn_marker_id = &"SpawnR1A"

	var enc1 := RoomEncounter.new()
	enc1.id = &"room_1"
	enc1.spawns = [spawn1a]
	enc1.hint_text = ""
	enc1.clear_advances = true

	# Build two Area3D triggers (minimal — no shape needed for headless _arm_encounter call).
	var trig0 := Area3D.new()
	trig0.name = "Trigger0"
	scene_root.add_child(trig0)
	var trig1 := Area3D.new()
	trig1.name = "Trigger1"
	scene_root.add_child(trig1)

	# Build RoomController.
	_rc = RoomController.new()
	_rc.name = "RoomController"
	_rc.encounters = [enc0, enc1]
	_rc.enemy_scene = enemy_packed
	_rc.touch_damage = 10
	# Assign NodePaths relative to scene_root (rc is child of scene_root).
	_rc.room_trigger_paths = [
		NodePath("../Trigger0"),
		NodePath("../Trigger1"),
	]
	_rc.door_paths = [
		NodePath("../Door1"),
		NodePath("../Door2"),
	]
	_rc.spawn_marker_paths = [
		NodePath("../SpawnR0A"),
		NodePath("../SpawnR0B"),
		NodePath("../SpawnR1A"),
	]
	scene_root.add_child(_rc)

	# Connect signals for assertion.
	_rc.room_cleared.connect(func(id: StringName) -> void: _room_cleared_ids.append(id))
	_rc.hint_changed.connect(func(text: String) -> void: _hint_texts.append(text))


func _make_door(parent: Node, node_name: String) -> StaticBody3D:
	var door := StaticBody3D.new()
	door.name = node_name
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	door.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	door.add_child(mesh)
	parent.add_child(door)
	return door


func _make_marker(parent: Node, node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	parent.add_child(m)
	return m


func _assert_eq(label: String, got: Variant, expected: Variant) -> void:
	if got != expected:
		_fails.append("%s: expected %s got %s" % [label, expected, got])


func _report() -> void:
	if _fails.is_empty():
		print(_PASS)
	else:
		for f: String in _fails:
			print("%s — %s" % [_FAIL_PREFIX, f])
