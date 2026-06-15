# tools/build_firing_yard.gd — headless GridMap + MeshLibrary builder for the Firing Yard arena.
## Run: $GODOT --headless --path . --script tools/build_firing_yard.gd
## Output: resources/firing_yard_tiles.meshlib.tres + levels/firing_yard.tscn (cells baked in).
## One build path — never hand-type Transform3D walls. Runs once; produces a saved .tscn.
@tool
extends SceneTree

# --- Cell and level constants ---
const CELL_SIZE := Vector3(2.0, 4.0, 2.0)
const GRID_W := 24
const GRID_H := 16

# Grid structure codes (from levels/drawn/current.json spec)
const CODE_FLOOR := 0
const CODE_WALL := 1
# Codes 4+ are item cells (B1b scope — skip for B1a)

# MeshLibrary item ids
const ITEM_WALL := 0

# Wall colour: dark-grey sci-fi concrete #404050
const WALL_COLOR := Color(0.251, 0.251, 0.314, 1.0)
# Floor colour: near-black #141420
const FLOOR_COLOR := Color(0.078, 0.078, 0.125, 1.0)

# Sun: cool blue-white #8888ff, energy 1.2, from upper-north
# Rotation: tilted from upper-north → pitch -45 deg (down), yaw 180 deg (faces south = from north)
const SUN_COLOR := Color(0.533, 0.533, 1.0, 1.0)
const SUN_ENERGY := 1.2
const SUN_ROT_DEG := Vector3(-45.0, 180.0, 0.0)

# Ambient dark blue #101020
const AMBIENT_COLOR := Color(0.063, 0.063, 0.125, 1.0)
const AMBIENT_ENERGY := 1.0

# Spawn: cell (col=12, row=15) → Vector3(12*2, 1.0, 15*2) = Vector3(24, 1.0, 30)
# Player faces north (-Z): rotation_degrees.y = 180
const SPAWN_POS := Vector3(24.0, 1.0, 30.0)
const SPAWN_ROT_Y := 180.0

# Parsed grid data
var _cells: Array = []


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

	# GridMap — structure walls only (B1a: code 1 cells)
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
		# All other codes (0 floor, 4 item) are skipped — B1a builds wall cells only.


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
	# Dark solid sky — use a very dark ProceduralSkyMaterial to avoid any horizon glow.
	# background_mode=Sky with a near-black sky gives the closed indoor-outdoor tech yard look.
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.02, 0.05, 1.0)
	sky_mat.sky_horizon_color = Color(0.02, 0.02, 0.05, 1.0)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02, 1.0)
	sky_mat.ground_horizon_color = Color(0.01, 0.01, 0.02, 1.0)
	sky_mat.sun_angle_max = 0.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Override ambient with the dark-blue constant so it doesn't inherit sky brightness.
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
