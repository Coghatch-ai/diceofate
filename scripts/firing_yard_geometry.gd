# scripts/firing_yard_geometry.gd — geometry phase: gridmap, floor slabs, fake walls.
class_name FiringYardGeometry


static func build_gridmap(
	grid: Dictionary, cell_x: float, cell_z: float, wall_h: float, wall_color: Color
) -> GridMap:
	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = wall_color
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(cell_x, wall_h, cell_z)
	wall_mesh.material = wall_mat
	var wall_shape: BoxShape3D = BoxShape3D.new()
	wall_shape.size = Vector3(cell_x, wall_h, cell_z)

	var mesh_lib: MeshLibrary = MeshLibrary.new()
	mesh_lib.create_item(0)
	mesh_lib.set_item_name(0, "wall")
	mesh_lib.set_item_mesh(0, wall_mesh)
	mesh_lib.set_item_shapes(0, [wall_shape, Transform3D.IDENTITY])

	var gm: GridMap = GridMap.new()
	gm.name = "FiringYardMap"
	gm.mesh_library = mesh_lib
	gm.cell_size = Vector3(cell_x, wall_h, cell_z)
	gm.cell_center_x = false
	gm.cell_center_y = false
	gm.cell_center_z = false

	@warning_ignore("unsafe_cast")
	var raw_cells: Array = grid["cells"] as Array
	@warning_ignore("unsafe_cast")
	var width: int = int(grid["width"] as float)
	for idx: int in range(raw_cells.size()):
		@warning_ignore("unsafe_cast")
		var code: int = int(raw_cells[idx] as float)
		if code == 1:
			@warning_ignore("integer_division")
			var row: int = idx / width
			gm.set_cell_item(Vector3i(idx % width, 0, row), 0)

	return gm


static func add_floor_slabs(
	scene_root: Node3D,
	fake_cells: Array[Vector2i],
	cell_size: Vector2,
	grid_h: int,
	floor_params: Vector3,
	floor_color: Color
) -> void:
	var hole_set: Dictionary = {}
	for cell: Vector2i in fake_cells:
		hole_set[cell] = true
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = floor_color
	var slab_idx: int = 0
	for row: int in range(grid_h):
		var span_start: int = -1
		for col: int in range(24 + 1):
			if not hole_set.has(Vector2i(col, row)) and col < 24:
				if span_start < 0:
					span_start = col
			else:
				if span_start >= 0:
					FiringYardNodes.emit_floor_slab(
						scene_root,
						floor_mat,
						span_start,
						row,
						col - span_start,
						slab_idx,
						cell_size,
						floor_params
					)
					slab_idx += 1
					span_start = -1
	print("build_firing_yard: emitted ", slab_idx, " floor slabs")


static func add_fake_walls(
	scene_root: Node3D,
	fake_cells: Array[Vector2i],
	cell_size: Vector2,
	wall_h: float,
	wall_color: Color
) -> void:
	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = wall_color
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(cell_size.x, wall_h, cell_size.y)
	bm.material = wall_mat
	for idx: int in range(fake_cells.size()):
		var cell: Vector2i = fake_cells[idx]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "FakeWall" + str(idx)
		mi.position = Vector3(
			float(cell.x) * cell_size.x + cell_size.x * 0.5,
			wall_h * 0.5,
			float(cell.y) * cell_size.y + cell_size.y * 0.5
		)
		mi.mesh = bm
		scene_root.add_child(mi)
		mi.owner = scene_root
	print("build_firing_yard: placed ", fake_cells.size(), " fake-wall meshes")
