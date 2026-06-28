# scripts/build_iron_floor.gd — greybox wall rebuild for levels/iron_floor.tscn.
# Loads the existing scene, strips all Wall_*/Corner_*/Door_R11/Door_R12 nodes,
# and replaces walls with solid BoxMesh greybox blocks (one per cell==1).
# No edge-detection, no kit GLBs — BoxMesh is symmetric, mesh+collision cannot drift.
# Preserves ALL gameplay nodes (Player, Boss, SpawnMarkers, RoomController, etc.).
#
# Grid: levels/drawn/iron_floor.json (24×16, cell_size=2m, wall_height=6m)
# Wall: 2×6×2 BoxMesh, mid-grey #4a4a4a, centered at (col*2+1, 3, row*2+1)
# Door cells (code=2): passable — two thin side pillar bodies only, no blocking box.
#
# Run: $GODOT --headless --path . --script scripts/build_iron_floor.gd
# Output: levels/iron_floor.tscn (baked — the ONLY wall builder; never hand-edit walls).
extends SceneTree

const TSCN_PATH := "res://levels/iron_floor.tscn"
const GRID_PATH := "res://levels/drawn/iron_floor.json"

const CELL_SIZE: float = 2.0
const WALL_HEIGHT: float = 6.0
const GRID_W: int = 24
const GRID_H: int = 16

const CODE_FLOOR: int = 0
const CODE_WALL: int = 1
const CODE_DOOR: int = 2

const WALL_COLOR := Color(0.290, 0.290, 0.290, 1.0)


func _init() -> void:
	_rebuild()
	quit()


func _rebuild() -> void:
	var cells: Array = _load_grid()
	if cells.is_empty():
		return
	var existing_ps := load(TSCN_PATH) as PackedScene
	if existing_ps == null:
		push_error("build_iron_floor: cannot load %s" % TSCN_PATH)
		return
	var scene_root: Node3D = existing_ps.instantiate() as Node3D
	_strip_walls(scene_root)
	var wall_mat := _make_wall_material()
	_place_greybox_walls(scene_root, cells, wall_mat)
	_place_door_nodes(scene_root, cells)
	_save_scene(scene_root)
	_remove_boss_overrides()


func _load_grid() -> Array:
	var file := FileAccess.open(GRID_PATH, FileAccess.READ)
	if file == null:
		push_error("build_iron_floor: cannot open %s" % GRID_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("build_iron_floor: JSON parse failed")
		return []
	@warning_ignore("unsafe_cast")
	return (parsed as Dictionary)["cells"] as Array


func _make_wall_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WALL_COLOR
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat


func _strip_walls(scene_root: Node3D) -> void:
	var to_remove: Array[Node] = []
	for child: Node in scene_root.get_children():
		var n := child.name
		if n.begins_with("Wall_") or n.begins_with("Corner_") or n == "Door_R11" or n == "Door_R12":
			to_remove.append(child)
	for node: Node in to_remove:
		scene_root.remove_child(node)
		node.queue_free()
	print("build_iron_floor: stripped %d old wall/door nodes" % to_remove.size())


func _place_greybox_walls(scene_root: Node3D, cells: Array, wall_mat: StandardMaterial3D) -> void:
	var wall_count: int = 0
	for i: int in range(cells.size()):
		@warning_ignore("unsafe_cast")
		var code: int = int(cells[i] as float)
		if code != CODE_WALL:
			continue
		var col: int = i % GRID_W
		@warning_ignore("integer_division")
		var row: int = i / GRID_W
		_add_wall_cell(scene_root, col, row, wall_mat)
		wall_count += 1
	print("build_iron_floor: placed %d greybox wall cells" % wall_count)


func _add_wall_cell(scene_root: Node3D, col: int, row: int, wall_mat: StandardMaterial3D) -> void:
	var cx: float = col * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = row * CELL_SIZE + CELL_SIZE * 0.5
	var cy: float = WALL_HEIGHT * 0.5

	var body := StaticBody3D.new()
	body.name = "Wall_%d_%d" % [col, row]
	body.position = Vector3(cx, cy, cz)
	scene_root.add_child(body)
	body.owner = scene_root

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "WallMesh"
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	mesh_inst.mesh = box
	mesh_inst.material_override = wall_mat
	body.add_child(mesh_inst)
	mesh_inst.owner = scene_root

	var col_node := CollisionShape3D.new()
	col_node.name = "WallCol"
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, WALL_HEIGHT, CELL_SIZE)
	col_node.shape = shape
	body.add_child(col_node)
	col_node.owner = scene_root


func _place_door_nodes(scene_root: Node3D, cells: Array) -> void:
	# Find door cells — grid has exactly 2 (codes 2), at x=19 rows 10 and 11.
	# Add them back as passable StaticBody3D with only side pillar collision.
	var door_index: int = 0
	for i: int in range(cells.size()):
		@warning_ignore("unsafe_cast")
		var code: int = int(cells[i] as float)
		if code != CODE_DOOR:
			continue
		door_index += 1
		var col: int = i % GRID_W
		@warning_ignore("integer_division")
		var row: int = i / GRID_W
		var cx: float = col * CELL_SIZE + CELL_SIZE * 0.5
		var cz: float = row * CELL_SIZE + CELL_SIZE * 0.5
		_add_door_node(scene_root, door_index, cx, cz)
	print("build_iron_floor: placed %d door nodes" % door_index)


func _add_door_node(scene_root: Node3D, door_index: int, cx: float, cz: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Door_R1" + str(door_index)
	body.position = Vector3(cx, 0.0, cz)
	scene_root.add_child(body)
	body.owner = scene_root

	# Two thin pillar colliders flanking the opening — NOT a solid blocking box.
	for side: int in range(2):
		var px: float = CELL_SIZE * 0.5 - 0.15 if side == 0 else -(CELL_SIZE * 0.5 - 0.15)
		var col_node := CollisionShape3D.new()
		col_node.name = "DoorCol"
		var ps := BoxShape3D.new()
		ps.size = Vector3(0.2, WALL_HEIGHT, 0.2)
		col_node.shape = ps
		col_node.position = Vector3(px, WALL_HEIGHT * 0.5, 0.0)
		body.add_child(col_node)
		col_node.owner = scene_root


func _save_scene(scene_root: Node3D) -> void:
	var packed := PackedScene.new()
	if packed.pack(scene_root) != OK:
		push_error("build_iron_floor: pack failed")
		return
	if ResourceSaver.save(packed, TSCN_PATH) != OK:
		push_error("build_iron_floor: save failed")
		return
	print("build_iron_floor: saved %s" % TSCN_PATH)


# Post-process: remove redundant boss script/connection overrides that pack() serialises
# from boss.tscn into iron_floor.tscn, causing duplicate "already connected" signals.
func _remove_boss_overrides() -> void:
	var abs_path := ProjectSettings.globalize_path(TSCN_PATH)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_error("build_iron_floor: cannot re-open tscn for boss fix")
		return
	var text := file.get_as_text()
	file.close()
	var lines := text.split("\n")
	var in_boss_node := false
	var out_lines: Array[String] = []
	for line: String in lines:
		if line.begins_with('[node name="Boss"'):
			in_boss_node = true
			out_lines.append(line)
			continue
		if (
			in_boss_node
			and line.begins_with("[node ")
			and not line.begins_with('[node name="Boss"')
		):
			in_boss_node = false
		if in_boss_node and line.begins_with("script = "):
			continue
		if line.begins_with("[connection signal=") and 'from="Boss"' in line:
			continue
		out_lines.append(line)
	var w := FileAccess.open(abs_path, FileAccess.WRITE)
	if w == null:
		push_error("build_iron_floor: cannot write boss fix")
		return
	w.store_string("\n".join(out_lines))
	w.close()
	print("build_iron_floor: removed boss script/connection overrides")
