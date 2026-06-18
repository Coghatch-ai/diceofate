# scripts/build_firing_yard.gd — headless builder for levels/firing_yard.tscn.
@tool
extends SceneTree

const CELL_X: float = 2.0
const CELL_Z: float = 2.0
const WALL_H: float = 4.0
const GRID_W: int = 24
const GRID_H: int = 16
const FLOOR_THICK: float = 0.2
const FLOOR_Y: float = -0.1
const FALL_Y_TOP: float = -6.0
const FALL_THICK: float = 2.0
const FALL_CENTER_Y: float = FALL_Y_TOP - FALL_THICK / 2.0
const FALL_W: float = 56.0
const FALL_D: float = 40.0
const SPAWN_POS: Vector3 = Vector3(24.0, 1.0, 30.0)
const SPAWN_ROT_Y: float = PI

const WALL_COLOR: Color = Color(0.251, 0.251, 0.314, 1.0)
const FLOOR_COLOR: Color = Color(0.078, 0.078, 0.125, 1.0)
const COVER_COLOR: Color = Color(0.376, 0.376, 0.439, 1.0)

const LEVEL_SCRIPT: String = "res://levels/firing_yard.gd"
const TARGET_SCENE: String = "res://entities/target/target.tscn"
const PLAYER_SCENE: String = "res://entities/player/player.tscn"
const OUT_PATH: String = "res://levels/firing_yard.tscn"
const GRID_JSON: String = "res://levels/drawn/current.json"


func _init() -> void:
	_build()
	quit()


func _build() -> void:
	var file: FileAccess = FileAccess.open(GRID_JSON, FileAccess.READ)
	if file == null:
		push_error("build_firing_yard: cannot open " + GRID_JSON)
		return
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		push_error("build_firing_yard: grid JSON is not a Dictionary")
		return
	# SEAM: JSON.parse_string returns Variant; unsafe_cast required for strict mode.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary

	var fake_cells: Array[Vector2i] = _collect_fake_cells(grid)
	print("build_firing_yard: found ", fake_cells.size(), " id-3 (fake-wall) cells")
	if fake_cells.size() != 24:
		push_error("build_firing_yard: expected 24 fake-wall cells, got " + str(fake_cells.size()))

	var scene_root: Node3D = Node3D.new()
	scene_root.name = "FiringYard"
	scene_root.set_script(load(LEVEL_SCRIPT))

	# Geometry phase: gridmap, floor slabs, fake walls.
	var gm: GridMap = FiringYardGeometry.build_gridmap(grid, CELL_X, CELL_Z, WALL_H, WALL_COLOR)
	scene_root.add_child(gm)
	gm.owner = scene_root

	var cell_size: Vector2 = Vector2(CELL_X, CELL_Z)
	var floor_params: Vector3 = Vector3(FLOOR_Y, FLOOR_THICK, CELL_Z)
	FiringYardGeometry.add_floor_slabs(
		scene_root, fake_cells, cell_size, GRID_H, floor_params, FLOOR_COLOR
	)
	FiringYardGeometry.add_fake_walls(scene_root, fake_cells, cell_size, WALL_H, WALL_COLOR)

	# Props/actors/lighting phase.
	FiringYardProps.add_platforms(scene_root, COVER_COLOR)
	FiringYardProps.add_targets(scene_root, TARGET_SCENE)
	FiringYardProps.add_lighting(scene_root)
	FiringYardProps.add_player(scene_root, PLAYER_SCENE, SPAWN_POS, SPAWN_ROT_Y)
	FiringYardProps.add_navmesh(scene_root)
	FiringYardProps.add_enemies(scene_root)
	FiringYardProps.add_npcs(scene_root, FiringYardProps.NPC_SCENE)

	# Hazards phase.
	FiringYardHazards.add_hazard_floor(scene_root)
	FiringYardHazards.add_crusher(scene_root)
	FiringYardHazards.add_fall_zone(scene_root, FALL_W, FALL_D, FALL_CENTER_Y)

	var packed: PackedScene = PackedScene.new()
	if packed.pack(scene_root) != OK:
		push_error("build_firing_yard: PackedScene.pack() failed")
		return
	if ResourceSaver.save(packed, OUT_PATH) != OK:
		push_error("build_firing_yard: ResourceSaver.save() failed")
		return
	print("build_firing_yard: wrote ", OUT_PATH)
	scene_root.queue_free()


func _collect_fake_cells(grid: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid.has("items") or not grid["items"] is Array:
		return result
	@warning_ignore("unsafe_cast")
	var raw_items: Array = grid["items"] as Array
	for raw_item: Variant in raw_items:
		if not raw_item is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var d: Dictionary = raw_item as Dictionary
		if not d.has("id") or not d.has("x") or not d.has("y"):
			continue
		@warning_ignore("unsafe_cast")
		if int(d["id"] as float) != 3:
			continue
		@warning_ignore("unsafe_cast")
		result.append(Vector2i(int(d["x"] as float), int(d["y"] as float)))
	return result
