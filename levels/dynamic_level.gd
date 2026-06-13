# levels/dynamic_level.gd — reads levels/drawn/current.json and spawns wall cubes at runtime.
extends Node3D

const MAP_PATH: String = "res://levels/drawn/current.json"


func _ready() -> void:
	var file: FileAccess = FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("DynamicLevel: cannot open %s" % MAP_PATH)
		return
	var raw: String = file.get_as_text()
	file.close()

	# SEAM: JSON.parse_string() returns Variant; cast to Dictionary after null-check.
	@warning_ignore("unsafe_cast")
	var data: Dictionary = JSON.parse_string(raw) as Dictionary
	if data == null:
		push_error("DynamicLevel: failed to parse JSON at %s" % MAP_PATH)
		return

	# SEAM: Dictionary.get() returns Variant; each value is cast to its expected type.
	@warning_ignore("unsafe_cast")
	var width: int = data.get("width", 0) as int
	@warning_ignore("unsafe_cast")
	var height: int = data.get("height", 0) as int
	@warning_ignore("unsafe_cast")
	var cell_size: float = data.get("cell_size", 1.0) as float
	@warning_ignore("unsafe_cast")
	var cells: Array = data.get("cells", []) as Array

	if width <= 0 or height <= 0 or cells.is_empty():
		push_error(
			"DynamicLevel: invalid map data w=%d h=%d cells=%d" % [width, height, cells.size()]
		)
		return

	_build_floor(width, height, cell_size)
	_build_walls(cells, width, height, cell_size)


func _build_floor(width: int, height: int, cell_size: float) -> void:
	var half_x: float = width * cell_size * 0.5
	var half_z: float = height * cell_size * 0.5
	var floor_size: Vector3 = Vector3(width * cell_size, 0.2, height * cell_size)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = floor_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.55, 0.4, 1.0)
	box_mesh.surface_set_material(0, mat)
	mesh_inst.mesh = box_mesh

	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(half_x, -0.1, half_z)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = floor_size
	shape_node.shape = box_shape

	body.add_child(mesh_inst)
	body.add_child(shape_node)
	add_child(body)


func _build_walls(cells: Array, width: int, height: int, cell_size: float) -> void:
	var wall_size: Vector3 = Vector3(cell_size, cell_size, cell_size)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.65, 1.0)

	for y: int in range(height):
		for x: int in range(width):
			var idx: int = y * width + x
			if idx >= cells.size():
				continue
			# SEAM: Array element from JSON is Variant; cast to int to read cell flag.
			@warning_ignore("unsafe_cast")
			var cell_val: int = cells[idx] as int
			if cell_val != 1:
				continue
			_spawn_wall(x, y, cell_size, wall_size, mat)


func _spawn_wall(
	x: int, y: int, cell_size: float, wall_size: Vector3, mat: StandardMaterial3D
) -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = wall_size
	box_mesh.surface_set_material(0, mat)
	mesh_inst.mesh = box_mesh

	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(
		x * cell_size + cell_size * 0.5, cell_size * 0.5, y * cell_size + cell_size * 0.5
	)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = wall_size
	shape_node.shape = box_shape

	body.add_child(mesh_inst)
	body.add_child(shape_node)
	add_child(body)
