# scripts/firing_yard_nodes.gd — shared node-construction utilities for firing_yard builder.
class_name FiringYardNodes


static func vis_mesh(scene_root: Node3D, n: String, sz: Vector3, pos: Vector3, col: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	scene_root.add_child(mi)
	mi.owner = scene_root


static func emit_floor_slab(
	scene_root: Node3D,
	mat: StandardMaterial3D,
	col_start: int,
	row: int,
	span_cols: int,
	idx: int,
	cell_size: Vector2,
	floor_params: Vector3
) -> void:
	# floor_params: (y, thickness, z_cell_size)
	var sw: float = float(span_cols) * cell_size.x
	var cx: float = float(col_start) * cell_size.x + sw * 0.5
	var cz: float = float(row) * cell_size.y + cell_size.y * 0.5
	var pos: Vector3 = Vector3(cx, floor_params.x, cz)
	var sz: Vector3 = Vector3(sw, floor_params.y, cell_size.y)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "FloorSlab" + str(idx)
	scene_root.add_child(body)
	body.owner = scene_root
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "FloorMesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	body.add_child(mi)
	mi.owner = scene_root
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "FloorCollision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
	cs.owner = scene_root


static func build_box_body(
	scene_root: Node3D, n: String, sz: Vector3, pos: Vector3, mat: StandardMaterial3D
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	scene_root.add_child(body)
	body.owner = scene_root
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n + "Mesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	body.add_child(mi)
	mi.owner = scene_root
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = n + "Collision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
	cs.owner = scene_root
	return body


static func build_ramp_body(
	scene_root: Node3D, n: String, sz: Vector3, pos: Vector3, deg_x: float, mat: StandardMaterial3D
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = n
	scene_root.add_child(body)
	body.owner = scene_root
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n + "Mesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = Vector3(deg_x, 0.0, 0.0)
	body.add_child(mi)
	mi.owner = scene_root
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = n + "Collision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	cs.rotation_degrees = Vector3(deg_x, 0.0, 0.0)
	body.add_child(cs)
	cs.owner = scene_root
	return body


static func build_trigger(scene_root: Node3D, n: String, sz: Vector3, pos: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = n
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 2
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = n + "Shape"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	area.add_child(cs)
	scene_root.add_child(area)
	area.owner = scene_root
	cs.owner = scene_root
	return area
