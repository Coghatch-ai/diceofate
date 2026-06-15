# tools/build_firing_yard.gd — headless GridMap + MeshLibrary builder for the Firing Yard arena.
## Run: $GODOT --headless --path . --script tools/build_firing_yard.gd
## Output: resources/firing_yard_tiles.meshlib.tres + levels/firing_yard.tscn (cells baked in).
## One build path — never hand-type Transform3D walls. Runs once; produces a saved .tscn.
## B1b: adds high platform (id 5), mid platform (id 4), and placeholder prop groups (ids 1,2,3,6).
@tool
extends SceneTree

# --- Cell and level constants ---
const CELL_SIZE := Vector3(2.0, 4.0, 2.0)
const GRID_W := 24
const GRID_H := 16

# Grid structure codes (from levels/drawn/current.json spec)
const CODE_FLOOR := 0
const CODE_WALL := 1

# MeshLibrary item ids
const ITEM_WALL := 0

# Wall colour: dark-grey sci-fi concrete #404050
const WALL_COLOR := Color(0.251, 0.251, 0.314, 1.0)
# Floor colour: near-black #141420
const FLOOR_COLOR := Color(0.078, 0.078, 0.125, 1.0)

# Platform colours
const HIGH_PLATFORM_COLOR := Color(0.376, 0.376, 0.439, 1.0)  # #606070
const MID_PLATFORM_COLOR := Color(0.376, 0.376, 0.439, 1.0)  # #606070

# Placeholder prop colours (no collision)
const HAZARD_COLOR := Color(0.878, 0.376, 0.125, 1.0)  # #e06020 orange
const WALL_CLING_COLOR := Color(0.125, 0.502, 0.565, 1.0)  # #208090 cyan
const DECO_COLOR := Color(0.306, 0.314, 0.063, 1.0)  # #4e5010 olive

# Sun: sunrise start state (warm orange, low pitch from east, moderate energy).
# The FiringYard script (levels/firing_yard.gd) animates these at runtime.
const SUN_COLOR := Color(1.0, 0.6, 0.2, 1.0)  # warm orange sunrise
const SUN_ENERGY := 0.6
const SUN_ROT_DEG := Vector3(-10.0, 180.0, 0.0)  # low sunrise pitch, facing south

# Ambient: sunrise start state. Script drives this at runtime.
const AMBIENT_COLOR := Color(0.4, 0.25, 0.15, 1.0)  # dim warm sunrise
const AMBIENT_ENERGY := 0.5

# Spawn: cell (col=12, row=15) → Vector3(12*2, 1.0, 15*2) = Vector3(24, 1.0, 30)
# Player faces north (-Z): rotation_degrees.y = 180
const SPAWN_POS := Vector3(24.0, 1.0, 30.0)
const SPAWN_ROT_Y := 180.0

# Parsed grid items by id
var _cells: Array = []
var _items: Array = []


func _init() -> void:
	_build()
	quit()


func _build() -> void:
	if not _load_grid():
		push_error("build_firing_yard: grid load failed — aborting")
		return
	var meshlib: MeshLibrary = _build_meshlib()
	if meshlib == null:
		push_error("build_firing_yard: meshlib build failed — aborting")
		return
	var save_err: Error = ResourceSaver.save(
		meshlib, "res://resources/firing_yard_tiles.meshlib.tres"
	)
	if save_err != OK:
		push_error("build_firing_yard: meshlib save failed: %d" % save_err)
		return
	print("build_firing_yard: meshlib saved → resources/firing_yard_tiles.meshlib.tres")
	_build_and_save_level(meshlib)


# --- Grid loading ---


func _load_grid() -> bool:
	var file: FileAccess = FileAccess.open("res://levels/drawn/current.json", FileAccess.READ)
	if file == null:
		push_error("build_firing_yard: cannot open levels/drawn/current.json")
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("build_firing_yard: grid JSON is not a Dictionary")
		return false
	# SEAM: JSON.parse_string returns Variant; strict config (unsafe_cast=2) requires explicit casts.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary
	@warning_ignore("unsafe_cast")
	_cells = grid["cells"] as Array
	@warning_ignore("unsafe_cast")
	_items = grid["items"] as Array
	return true


# --- MeshLibrary build ---


func _build_meshlib() -> MeshLibrary:
	var lib: MeshLibrary = MeshLibrary.new()
	lib.create_item(ITEM_WALL)
	lib.set_item_name(ITEM_WALL, "wall")
	# Solid block filling the full cell: Vector3(2, 4, 2)
	var box: BoxMesh = BoxMesh.new()
	box.size = CELL_SIZE
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = WALL_COLOR
	mat.roughness = 1.0
	mat.metallic = 0.0
	box.material = mat
	lib.set_item_mesh(ITEM_WALL, box)
	# Collision: BoxShape3D sized to the full cell, welded via set_item_shapes.
	# set_item_shapes takes a flat Array: [Shape3D, Transform3D, ...].
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = CELL_SIZE
	# SEAM: set_item_shapes needs mixed Array [Shape3D, Transform3D]; no typed Array is possible.
	var shapes: Array = [shape, Transform3D.IDENTITY]
	lib.set_item_shapes(ITEM_WALL, shapes)
	return lib


# --- Level scene build ---


func _build_and_save_level(meshlib: MeshLibrary) -> void:
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "FiringYard"
	# Attach the day/night cycle driver script to the level root.
	var yard_script: Script = load("res://levels/firing_yard.gd") as Script
	if yard_script == null:
		push_error("build_firing_yard: cannot load levels/firing_yard.gd")
		return
	scene_root.set_script(yard_script)

	# GridMap — structure walls only (code 1 cells)
	var grid_map: GridMap = GridMap.new()
	grid_map.name = "FiringYardMap"
	grid_map.mesh_library = meshlib
	grid_map.cell_size = CELL_SIZE
	grid_map.cell_center_x = false
	grid_map.cell_center_y = false
	grid_map.cell_center_z = false
	_populate_grid_map(grid_map)
	scene_root.add_child(grid_map)
	grid_map.owner = scene_root

	# Floor slab — one StaticBody3D covering 48 x 32 m footprint
	_add_floor(scene_root)

	# B1b: platforms with ramps (collidable)
	_add_high_platform(scene_root)
	_add_mid_platform(scene_root)

	# B1b: placeholder prop groups (no collision, purely visual)
	# NOTE: id-3 FakeWallPlaceholder (grey floor slab) intentionally omitted — removed in B2.
	_add_hazard_props(scene_root)
	_add_wall_cling_props(scene_root)
	_add_deco_props(scene_root)

	# B2: baked target instances
	_add_targets(scene_root)

	# Lighting: sci-fi blue-white directional + dark-blue WorldEnvironment
	_add_lighting(scene_root)

	# Player spawn at cell (12, 15), facing north
	_add_player(scene_root)

	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(scene_root)
	if pack_err != OK:
		push_error("build_firing_yard: pack failed: %d" % pack_err)
		return
	var save_err: Error = ResourceSaver.save(packed, "res://levels/firing_yard.tscn")
	if save_err != OK:
		push_error("build_firing_yard: scene save failed: %d" % save_err)
		return
	print("build_firing_yard: saved → levels/firing_yard.tscn")
	print("build_firing_yard: wall cells placed: ", grid_map.get_used_cells().size())


func _populate_grid_map(grid_map: GridMap) -> void:
	for i: int in range(_cells.size()):
		# SEAM: Array element is Variant (JSON integer stored as float)
		@warning_ignore("unsafe_cast")
		var code: int = int(_cells[i] as float)
		var col: int = i % GRID_W
		@warning_ignore("integer_division")
		var row: int = i / GRID_W
		if code == CODE_WALL:
			grid_map.set_cell_item(Vector3i(col, 0, row), ITEM_WALL)
		# All other codes (0 floor, 4 item) are skipped — walls only in GridMap.


func _add_floor(parent: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "FloorSlab"

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box: BoxMesh = BoxMesh.new()
	# Full grid footprint: 24*2 = 48 m wide, 16*2 = 32 m deep, 0.2 m thick slab
	box.size = Vector3(float(GRID_W) * CELL_SIZE.x, 0.2, float(GRID_H) * CELL_SIZE.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = FLOOR_COLOR
	mat.roughness = 1.0
	box.material = mat
	floor_mesh.mesh = box
	# Centre the slab under the grid; grid origin at (0,0,0), extent to (48,0,32).
	# Slab centre X=24, Z=16; top at Y=0 → centre at Y=-0.1.
	floor_mesh.position = Vector3(
		float(GRID_W) * CELL_SIZE.x * 0.5, -0.1, float(GRID_H) * CELL_SIZE.z * 0.5
	)
	floor_body.add_child(floor_mesh)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = "FloorCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(float(GRID_W) * CELL_SIZE.x, 0.2, float(GRID_H) * CELL_SIZE.z)
	col_shape.shape = shape
	col_shape.position = floor_mesh.position
	floor_body.add_child(col_shape)

	parent.add_child(floor_body)
	floor_body.owner = parent
	floor_mesh.owner = parent
	col_shape.owner = parent


func _add_high_platform(parent: Node3D) -> void:
	# id 5: cols 19-20, rows 2-3 → world X: 38-42, Z: 4-8 → 4x4 m footprint, top at +2 m.
	# Platform: height=2 m, centre Y=1.0, centre X=40, centre Z=6.
	var platform: StaticBody3D = StaticBody3D.new()
	platform.name = "HighPlatform"

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "HighPlatformMesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(4.0, 2.0, 4.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = HIGH_PLATFORM_COLOR
	mat.roughness = 1.0
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(40.0, 1.0, 6.0)
	platform.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "HighPlatformCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 2.0, 4.0)
	col.shape = shape
	col.position = Vector3(40.0, 1.0, 6.0)
	platform.add_child(col)

	parent.add_child(platform)
	platform.owner = parent
	mesh_inst.owner = parent
	col.owner = parent

	# Ramp: floor Z=8..10 → +2 m deck. Width=4 m, angle=-45 deg, centre=(40,1,9).
	_add_ramp(
		parent,
		"HighPlatformRamp",
		Vector3(40.0, 1.0, 9.0),
		Vector3(4.0, 0.3, 2.828),
		-45.0,
		HIGH_PLATFORM_COLOR
	)


func _add_mid_platform(parent: Node3D) -> void:
	# id 4: cols 19-20, rows 11-12 → world X: 38-42, Z: 22-26 → 4x4 m footprint, top at +1 m.
	# Platform: height=1 m, centre Y=0.5, centre X=40, centre Z=24.
	var platform: StaticBody3D = StaticBody3D.new()
	platform.name = "MidPlatform"

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "MidPlatformMesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(4.0, 1.0, 4.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = MID_PLATFORM_COLOR
	mat.roughness = 1.0
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = Vector3(40.0, 0.5, 24.0)
	platform.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "MidPlatformCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4.0, 1.0, 4.0)
	col.shape = shape
	col.position = Vector3(40.0, 0.5, 24.0)
	platform.add_child(col)

	parent.add_child(platform)
	platform.owner = parent
	mesh_inst.owner = parent
	col.owner = parent

	# Ramp: floor Z=26..28 → +1 m deck. Width=4 m, angle=-26.565 deg, centre=(40,0.5,27).
	_add_ramp(
		parent,
		"MidPlatformRamp",
		Vector3(40.0, 0.5, 27.0),
		Vector3(4.0, 0.3, 2.236),
		-26.565,
		MID_PLATFORM_COLOR
	)


func _add_ramp(
	parent: Node3D,
	ramp_name: String,
	centre: Vector3,
	box_size: Vector3,
	angle_x_deg: float,
	color: Color
) -> void:
	var ramp_body: StaticBody3D = StaticBody3D.new()
	ramp_body.name = ramp_name

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = ramp_name + "Mesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = centre
	mesh_inst.rotation_degrees = Vector3(angle_x_deg, 0.0, 0.0)
	ramp_body.add_child(mesh_inst)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = ramp_name + "Collision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	col_shape.shape = shape
	col_shape.position = centre
	col_shape.rotation_degrees = Vector3(angle_x_deg, 0.0, 0.0)
	ramp_body.add_child(col_shape)

	parent.add_child(ramp_body)
	ramp_body.owner = parent
	mesh_inst.owner = parent
	col_shape.owner = parent


func _make_visual_box(
	box_name: String, centre: Vector3, box_size: Vector3, color: Color
) -> MeshInstance3D:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = box_name
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = centre
	return mesh_inst


func _add_hazard_props(parent: Node3D) -> void:
	# id 1: cols 5-8, rows 1-2 — 8×4 m span at Y=0.25.
	var mesh_inst: MeshInstance3D = _make_visual_box(
		"HazardPlaceholder", Vector3(14.0, 0.25, 4.0), Vector3(8.0, 0.5, 4.0), HAZARD_COLOR
	)
	parent.add_child(mesh_inst)
	mesh_inst.owner = parent


func _add_wall_cling_props(parent: Node3D) -> void:
	# id 2: group A row 1 cols 14-17 (32,1,3); group B row 13 cols 9-13 (23,1,27).
	var mesh_a: MeshInstance3D = _make_visual_box(
		"WallClingA", Vector3(32.0, 1.0, 3.0), Vector3(8.0, 2.0, 0.3), WALL_CLING_COLOR
	)
	parent.add_child(mesh_a)
	mesh_a.owner = parent

	var mesh_b: MeshInstance3D = _make_visual_box(
		"WallClingB", Vector3(23.0, 1.0, 27.0), Vector3(10.0, 2.0, 0.3), WALL_CLING_COLOR
	)
	parent.add_child(mesh_b)
	mesh_b.owner = parent


func _add_deco_props(parent: Node3D) -> void:
	# id 6: cells (2,6),(8,8),(6,10),(15,10),(2,13) — 0.8 m cube at each cell centre.
	var deco_cells: Array[Vector2i] = [
		Vector2i(2, 6),
		Vector2i(8, 8),
		Vector2i(6, 10),
		Vector2i(15, 10),
		Vector2i(2, 13),
	]
	for idx: int in range(deco_cells.size()):
		var cell: Vector2i = deco_cells[idx]
		var world_x: float = float(cell.x) * CELL_SIZE.x + CELL_SIZE.x * 0.5
		var world_z: float = float(cell.y) * CELL_SIZE.z + CELL_SIZE.z * 0.5
		var mesh_inst: MeshInstance3D = _make_visual_box(
			"DecoProp%d" % idx, Vector3(world_x, 0.4, world_z), Vector3(0.8, 0.8, 0.8), DECO_COLOR
		)
		parent.add_child(mesh_inst)
		mesh_inst.owner = parent


func _add_targets(parent: Node3D) -> void:
	# B2: 4 baked targets. A+B on floor; C on +1 m deck; D on +2 m deck (require aiming up).
	var target_scene: PackedScene = load("res://entities/target/target.tscn") as PackedScene
	if target_scene == null:
		push_error("build_firing_yard: cannot load target.tscn")
		return
	var positions: Array[Vector3] = [
		Vector3(24.0, 0.5, 20.0),
		Vector3(18.0, 0.5, 14.0),
		Vector3(40.0, 1.5, 24.0),
		Vector3(40.0, 2.5, 6.0),
	]
	var names: Array[String] = ["TargetA", "TargetB", "TargetC", "TargetD"]
	for idx: int in range(positions.size()):
		var target: Node3D = target_scene.instantiate() as Node3D
		if target == null:
			push_error("build_firing_yard: target instantiate failed at idx %d" % idx)
			continue
		target.name = names[idx]
		target.position = positions[idx]
		parent.add_child(target)
		target.owner = parent
		# Do NOT set owner on the instance's internal children — they belong to the packed
		# scene definition. Setting child.owner = parent causes PackedScene.pack() to serialize
		# them as explicit additions, which clashes with the children already present via the
		# instance on load (node-name clash error blocking the project).


func _add_lighting(parent: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 1.0
	sun.shadow_bias = 0.05
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = SUN_ROT_DEG
	parent.add_child(sun)
	sun.owner = parent

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	# Sky material baked at sunrise start state; the FiringYard script animates it at runtime.
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.35, 0.2, 1.0)  # warm orange dawn top
	sky_mat.sky_horizon_color = Color(0.9, 0.55, 0.2, 1.0)  # warm orange dawn horizon
	sky_mat.ground_bottom_color = Color(0.05, 0.03, 0.01, 1.0)
	sky_mat.ground_horizon_color = Color(0.9, 0.55, 0.2, 1.0)
	sky_mat.sun_angle_max = 0.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambient driven by color (script overrides each frame); sunrise start state baked in.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	world_env.environment = env
	parent.add_child(world_env)
	world_env.owner = parent


func _add_player(parent: Node3D) -> void:
	var player_scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	if player_scene == null:
		push_error("build_firing_yard: cannot load player.tscn")
		return
	var player: Node3D = player_scene.instantiate() as Node3D
	if player == null:
		push_error("build_firing_yard: player instantiate failed")
		return
	player.position = SPAWN_POS
	player.rotation_degrees = Vector3(0.0, SPAWN_ROT_Y, 0.0)
	parent.add_child(player)
	player.owner = parent
