# tools/apartment_props.gd — placement helper functions for shared apartment props.

## Cell and level constants (mirrors from builder)
const CELL_SIZE := Vector3(1.5, 3.0, 1.5)


## Accumulate the merged AABB of all MeshInstance3D descendants in node's subtree.
## xform is the cumulative Transform3D from the prop holder's local space to node's local space.
## Returns AABB with size == Vector3.ZERO when no mesh is found (caller checks .has_surface).
static func _mesh_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var found := false
	if node is MeshInstance3D:
		# SEAM: node is confirmed MeshInstance3D by is-check; cast required by strict config.
		@warning_ignore("unsafe_cast")
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var local_aabb: AABB = mi.mesh.get_aabb()
			# Transform AABB corners into holder-local space and re-expand.
			var world_aabb := AABB()
			var corners: Array[Vector3] = [
				local_aabb.position,
				local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
				local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
				local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
				local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
				local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
				local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
				local_aabb.end,
			]
			var first_corner: Vector3 = xform * corners[0]
			world_aabb = AABB(first_corner, Vector3.ZERO)
			for idx: int in range(1, corners.size()):
				world_aabb = world_aabb.expand(xform * corners[idx])
			result = world_aabb
			found = true
	for child: Object in node.get_children():
		if not child is Node:
			continue
		# SEAM: child confirmed Node by is-check; cast required by strict config.
		@warning_ignore("unsafe_cast")
		var child_node := child as Node
		# SEAM: child_node may or may not be Node3D; check before accessing transform.
		@warning_ignore("unsafe_cast")
		var child_3d := child_node as Node3D
		var child_xform: Transform3D
		if child_3d != null:
			child_xform = xform * child_3d.transform
		else:
			child_xform = xform
		var child_aabb: AABB = _mesh_aabb(child_node, child_xform)
		if child_aabb.size != Vector3.ZERO:
			if not found:
				result = child_aabb
				found = true
			else:
				result = result.merge(child_aabb)
	return result


## Short helper: instance one .glb prop at (world_x, 0, world_z) with Y rotation rot_y_deg.
## Holder is a StaticBody3D with a CollisionShape3D (BoxShape3D) sized from the model AABB.
## Near-uniform scale (1,1,1) — props authored at real-world proportions; no per-axis stretch.
static func _ip(
	parent: Node3D,
	node_name: String,
	model_name: String,
	world_x: float,
	world_z: float,
	rot_y_deg: float
) -> void:
	var glb_path: String = "res://assets/models/%s.glb" % model_name
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		push_error("build_shared_apartment: cannot load '%s'" % glb_path)
		return
	var holder: StaticBody3D = StaticBody3D.new()
	holder.name = node_name
	holder.position = Vector3(world_x, 0.0, world_z)
	holder.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	parent.add_child(holder)
	holder.owner = parent

	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		push_error("build_shared_apartment: instantiate failed for '%s'" % glb_path)
		holder.queue_free()
		return
	holder.add_child(model)
	model.owner = parent

	# Compute merged AABB of all MeshInstance3D descendants in holder-local space.
	# model sits at the holder local origin with its own transform.
	var aabb: AABB = _mesh_aabb(model, model.transform)

	# Build a unique BoxShape3D per prop (sharing one resource would change all props together).
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = "PropCollision"
	var box_shape: BoxShape3D = BoxShape3D.new()
	if aabb.size != Vector3.ZERO:
		box_shape.size = aabb.size
		# Offset CollisionShape3D to the AABB centre (aabb.position is the min corner).
		col_shape.position = aabb.position + aabb.size * 0.5
	else:
		# Fallback: unit box at origin (model had no mesh or AABB was degenerate).
		push_warning(
			"build_shared_apartment: no AABB for '%s'; using unit collision box" % model_name
		)
		box_shape.size = Vector3(1.0, 1.0, 1.0)
	col_shape.shape = box_shape
	holder.add_child(col_shape)
	col_shape.owner = parent


## Props: child StaticBody3D instances (with CollisionShape3D). Y-min=0 → floor_y_offset=0.
## pos formula: (col+0.5)*CELL_SIZE.x / (row+0.5)*CELL_SIZE.z; multi-cell → group centre.
static func add_bedroom_b_props(parent: Node3D) -> void:
	_ip(parent, "BedA", "single_bed", 18.5 * CELL_SIZE.x, 3.5 * CELL_SIZE.z, 0.0)
	_ip(parent, "BedB", "single_bed", 19.5 * CELL_SIZE.x, 3.5 * CELL_SIZE.z, 0.0)
	_ip(parent, "Wardrobes", "wardrobe", 22.5 * CELL_SIZE.x, 3.0 * CELL_SIZE.z, 0.0)
	_ip(parent, "Desk", "desk", 21.5 * CELL_SIZE.x, 1.5 * CELL_SIZE.z, 0.0)
	_ip(parent, "Chair", "chair", 20.5 * CELL_SIZE.x, 1.5 * CELL_SIZE.z, 90.0)
	_ip(parent, "Nightstand", "nightstand", 20.5 * CELL_SIZE.x, 4.5 * CELL_SIZE.z, 0.0)
	print("build_shared_apartment: Bedroom B props placed (zone 10)")


## Zone 20 — Bedroom A (slice 3): 2 beds + 2 nightstands; headboards at -Z.
static func add_bedroom_a_props(parent: Node3D) -> void:
	_ip(parent, "BedA_A", "single_bed", (12.5) * CELL_SIZE.x, (2.5) * CELL_SIZE.z, 0.0)
	_ip(parent, "BedB_A", "single_bed", (15.5) * CELL_SIZE.x, (2.5) * CELL_SIZE.z, 0.0)
	_ip(parent, "NightstandA1", "nightstand", (13.5) * CELL_SIZE.x, (1.5) * CELL_SIZE.z, 0.0)
	_ip(parent, "NightstandA2", "nightstand", (14.5) * CELL_SIZE.x, (3.5) * CELL_SIZE.z, 0.0)
	print("build_shared_apartment: Bedroom A props placed (zone 20)")


## Zone 50 — Kitchen (slice 4): counter (2-cell Z-span) + 2 single-cell stoves.
## Counter long axis along Z (authored 3 m); stove is a single-cell appliance.
static func add_kitchen_props(parent: Node3D) -> void:
	# Counter: cells col=3 rows 3-4; centre at (3.5, 4.0) in cell-coords.
	_ip(parent, "Counter", "counter", 3.5 * CELL_SIZE.x, 4.0 * CELL_SIZE.z, 0.0)
	# Two stoves at col=5 rows 3 and 4 (one per cell).
	_ip(parent, "Stove1", "stove", 5.5 * CELL_SIZE.x, 3.5 * CELL_SIZE.z, 0.0)
	_ip(parent, "Stove2", "stove", 5.5 * CELL_SIZE.x, 4.5 * CELL_SIZE.z, 0.0)
	print("build_shared_apartment: Kitchen props placed (zone 50)")


## Zone 40 — Lounge (slice 4): 2 plants (corners), TV (2-cell Z-span), couch facing TV.
## TV screen faces +X; couch authored facing +X, rotated 180° so it faces -X (toward TV).
static func add_lounge_props(parent: Node3D) -> void:
	_ip(parent, "PlantA", "plant", 7.5 * CELL_SIZE.x, 1.5 * CELL_SIZE.z, 0.0)
	_ip(parent, "PlantB", "plant", 10.5 * CELL_SIZE.x, 1.5 * CELL_SIZE.z, 0.0)
	# TV: cells col=7 rows 3-4; centre (7.5, 4.0). Screen faces +X (default).
	_ip(parent, "TV", "tv", 7.5 * CELL_SIZE.x, 4.0 * CELL_SIZE.z, 0.0)
	# Couch: cells col=10 rows 3-4; centre (10.5, 4.0). Rotated 180° → faces -X (toward TV).
	_ip(parent, "Couch", "couch", 10.5 * CELL_SIZE.x, 4.0 * CELL_SIZE.z, 180.0)
	print("build_shared_apartment: Lounge props placed (zone 40)")


## Zone 30 — Bathroom (slice 5): toilet, bathtub (3-cell Z-span centre), sink vanity.
## All models have native Y-min = 0.0 → floor_y_offset = 0.0; near-uniform scale (1,1,1).
## Toilet (col=20, row=6): tank authored at -Z → backs the north wall at 0° rotation.
## Bathtub (group cols 22 rows 6-8 → centre col=22 row=7): long axis along Z (authored),
##   against the east wall; leaves floor either side — correct, no stretching.
## Sink vanity (col=21, row=8): wide axis along X (authored); backs the south wall at 0°.
static func add_bathroom_props(parent: Node3D) -> void:
	# Toilet at cell (col=20, row=6): x=20.5*1.5=30.75, z=6.5*1.5=9.75
	_ip(parent, "Toilet", "toilet", 20.5 * CELL_SIZE.x, 6.5 * CELL_SIZE.z, 0.0)
	# Bathtub at group centre (col=22, row=7): x=22.5*1.5=33.75, z=7.5*1.5=11.25
	_ip(parent, "Bathtub", "bathtub", 22.5 * CELL_SIZE.x, 7.5 * CELL_SIZE.z, 0.0)
	# Sink vanity at cell (col=21, row=8): x=21.5*1.5=32.25, z=8.5*1.5=12.75
	_ip(parent, "SinkVanity", "sink_vanity", 21.5 * CELL_SIZE.x, 8.5 * CELL_SIZE.z, 0.0)
	print("build_shared_apartment: Bathroom props placed (zone 30)")
