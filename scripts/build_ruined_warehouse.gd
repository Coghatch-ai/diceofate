# scripts/build_ruined_warehouse.gd — headless builder for levels/ruined_warehouse.tscn.
# Run: $GODOT --headless --path . --script scripts/build_ruined_warehouse.gd
@tool
extends SceneTree

const CELL_X: float = 2.0
const CELL_Z: float = 2.0
const WALL_H: float = 3.5
const GRID_W: int = 24
const GRID_H: int = 16
const FLOOR_COLOR: Color = Color(0.078, 0.078, 0.125, 1.0)
const WALL_COLOR: Color = Color(0.251, 0.251, 0.314, 1.0)
const WALL_CORRIDOR_COLOR: Color = Color(0.18, 0.18, 0.22, 1.0)
const WALL_POCKET_COLOR: Color = Color(0.20, 0.20, 0.28, 1.0)
const BARRIER_COLOR: Color = Color(0.35, 0.30, 0.25, 1.0)

const BARRIER_H: float = 0.8
const PICKUP_AMMO_SCENE: String = "res://entities/pickup/pickup_ammo.tscn"

# Corridor zone: x 0–8, y 0–4 (inclusive). Walls here get item 1 (wall_corridor).
const CORRIDOR_X_MAX: int = 8
const CORRIDOR_Y_MAX: int = 4

# Flanking-pocket zone: x 18–23, y 2–3 OR y 11–12. Walls here get item 2 (wall_pocket).
const POCKET_X_MIN: int = 18
const POCKET_Y_BAND1_MIN: int = 2
const POCKET_Y_BAND1_MAX: int = 3
const POCKET_Y_BAND2_MIN: int = 11
const POCKET_Y_BAND2_MAX: int = 12

# Raised platform over id=4 footprint: cells x19–20 y11–12.
# World: x = 38–42, z = 22–26, top surface at y = 1.0.
const PLATFORM_X: float = 38.0
const PLATFORM_Z: float = 22.0
const PLATFORM_W: float = 4.0
const PLATFORM_D: float = 4.0
const PLATFORM_Y: float = 1.0
const PLATFORM_THICK: float = 0.2
# Ramp: west edge of platform, 1 m deep, full platform depth wide.
const RAMP_DEPTH: float = 1.0

# Player spawn: grid cell (6,1) → world (12,1,2), facing +Z (south).
const SPAWN_POS: Vector3 = Vector3(12.0, 1.0, 2.0)
const SPAWN_ROT_Y: float = PI

const PLAYER_SCENE: String = "res://entities/player/player.tscn"
const LEVEL_SCRIPT: String = "res://levels/ruined_warehouse.gd"
const GRID_JSON: String = "res://levels/drawn/ruined_warehouse.json"
const OUT_PATH: String = "res://levels/ruined_warehouse.tscn"
const NAVMESH_PATH: String = "res://levels/ruined_warehouse_navmesh.tres"


func _init() -> void:
	_build()
	quit()


func _build() -> void:
	var file: FileAccess = FileAccess.open(GRID_JSON, FileAccess.READ)
	if file == null:
		push_error("build_ruined_warehouse: cannot open " + GRID_JSON)
		return
	var raw_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		push_error("build_ruined_warehouse: grid JSON is not a Dictionary")
		return
	# SEAM: JSON.parse_string returns Variant; unsafe_cast required for strict mode.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary

	var scene_root: Node3D = Node3D.new()
	scene_root.name = "RuinedWarehouse"
	scene_root.set_script(load(LEVEL_SCRIPT))

	# GridMap: all code-1 (wall) cells, corridor zone uses item 1.
	var gm: GridMap = _build_gridmap(grid)
	scene_root.add_child(gm)
	gm.owner = scene_root

	# Floor slab: perforated — leaves 2×2 holes under fake-floor cells (E4).
	BuildRWSliceE4.add_perforated_floor(scene_root, GRID_W, GRID_H, CELL_X, CELL_Z)

	# Fake-floor visual tiles (no collision) at id=7 cells (E4).
	BuildRWSliceE4.add_fake_floor_tiles(scene_root, CELL_X, CELL_Z)

	# FallZone trigger below arena (E4); wired in ruined_warehouse.gd _ready().
	BuildRWSliceE4.add_fall_zone(scene_root)

	# Lighting: DirectionalLight3D Sun + WorldEnvironment.
	_add_lighting(scene_root)

	# Player spawn at corridor cell (6,1).
	_add_player(scene_root)

	# Slice C: cover barriers (id=2) + scattered ammo pickups (id=6).
	_add_barriers(scene_root, grid)
	_add_ammo_pickups(scene_root, grid)

	# Slice D: raised platform + ramp over id=4 footprint.
	_add_raised_platform(scene_root)
	_add_ramp(scene_root)

	# Slice E: rubble sills at id=3 breach-gate cells (no collision).
	BuildRWSliceE.add_rubble_sills(scene_root, grid, CELL_X, CELL_Z)

	# Slice E: patrol waypoints + WaveManager with SpawnMarkers at id=3 cells.
	BuildRWSliceE.add_patrol_waypoints(scene_root)
	BuildRWSliceE.add_wave_manager(scene_root, grid, CELL_X, CELL_Z, SPAWN_POS, SPAWN_ROT_Y)

	# Slice F: health cache (id=5, top-right pocket) + ammo cache (id=4, raised platform).
	BuildRWSliceE.add_health_pickups(scene_root, grid, CELL_X, CELL_Z)
	BuildRWSliceE.add_ammo_cache_pickups(scene_root, grid, CELL_X, CELL_Z)

	# NavMesh: NavigationRegion3D with pre-baked navmesh (agents need this to path).
	_add_navmesh(scene_root)

	var packed: PackedScene = PackedScene.new()
	if packed.pack(scene_root) != OK:
		push_error("build_ruined_warehouse: PackedScene.pack() failed")
		return
	if ResourceSaver.save(packed, OUT_PATH) != OK:
		push_error("build_ruined_warehouse: ResourceSaver.save() failed")
		return
	print("build_ruined_warehouse: wrote ", OUT_PATH)
	scene_root.queue_free()


func _build_gridmap(grid: Dictionary) -> GridMap:
	var wall_mat: StandardMaterial3D = StandardMaterial3D.new()
	wall_mat.albedo_color = WALL_COLOR
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(CELL_X, WALL_H, CELL_Z)
	wall_mesh.material = wall_mat
	var wall_shape: BoxShape3D = BoxShape3D.new()
	wall_shape.size = Vector3(CELL_X, WALL_H, CELL_Z)

	var corridor_mat: StandardMaterial3D = StandardMaterial3D.new()
	corridor_mat.albedo_color = WALL_CORRIDOR_COLOR
	var corridor_mesh: BoxMesh = BoxMesh.new()
	corridor_mesh.size = Vector3(CELL_X, WALL_H, CELL_Z)
	corridor_mesh.material = corridor_mat

	var pocket_mat: StandardMaterial3D = StandardMaterial3D.new()
	pocket_mat.albedo_color = WALL_POCKET_COLOR
	var pocket_mesh: BoxMesh = BoxMesh.new()
	pocket_mesh.size = Vector3(CELL_X, WALL_H, CELL_Z)
	pocket_mesh.material = pocket_mat

	var mesh_lib: MeshLibrary = MeshLibrary.new()
	mesh_lib.create_item(0)
	mesh_lib.set_item_name(0, "wall")
	mesh_lib.set_item_mesh(0, wall_mesh)
	mesh_lib.set_item_shapes(0, [wall_shape, Transform3D.IDENTITY])
	mesh_lib.create_item(1)
	mesh_lib.set_item_name(1, "wall_corridor")
	mesh_lib.set_item_mesh(1, corridor_mesh)
	# Corridor walls share the same collision shape dimensions.
	mesh_lib.set_item_shapes(1, [wall_shape, Transform3D.IDENTITY])
	mesh_lib.create_item(2)
	mesh_lib.set_item_name(2, "wall_pocket")
	mesh_lib.set_item_mesh(2, pocket_mesh)
	# Pocket walls share the same collision shape dimensions.
	mesh_lib.set_item_shapes(2, [wall_shape, Transform3D.IDENTITY])

	var gm: GridMap = GridMap.new()
	gm.name = "RuinedWarehouseMap"
	gm.mesh_library = mesh_lib
	gm.cell_size = Vector3(CELL_X, WALL_H, CELL_Z)
	gm.cell_center_x = false
	gm.cell_center_y = false
	gm.cell_center_z = false

	# SEAM: JSON.parse_string returns Variant; unsafe_cast required for strict mode.
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
			var col: int = idx % width
			var in_pocket: bool = (
				col >= POCKET_X_MIN
				and (
					(row >= POCKET_Y_BAND1_MIN and row <= POCKET_Y_BAND1_MAX)
					or (row >= POCKET_Y_BAND2_MIN and row <= POCKET_Y_BAND2_MAX)
				)
			)
			var in_corridor: bool = col <= CORRIDOR_X_MAX and row <= CORRIDOR_Y_MAX
			var item: int
			if in_pocket:
				item = 2
			elif in_corridor:
				item = 1
			else:
				item = 0
			gm.set_cell_item(Vector3i(col, 0, row), item)

	return gm


func _add_player(scene_root: Node3D) -> void:
	var packed: PackedScene = load(PLAYER_SCENE) as PackedScene
	var player: Node3D = packed.instantiate() as Node3D
	player.name = "Player"
	player.position = SPAWN_POS
	player.rotation.y = SPAWN_ROT_Y
	scene_root.add_child(player)
	player.owner = scene_root
	# Do NOT set owner recursively on the player instance: child nodes are owned by
	# player.tscn's scene root internally. Recursively re-owning them to the level root
	# bakes them as level-owned overrides, which breaks find_child(owned=true) from main.gd.


func _add_barriers(scene_root: Node3D, grid: Dictionary) -> void:
	# Collect all id=2 cells, group into contiguous runs by same row.
	var cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(grid, 2, CELL_X, CELL_Z)
	var row_cells: Dictionary = {}
	for cell: GridJsonIter.GridCell in cells:
		if not row_cells.has(cell.cy):
			row_cells[cell.cy] = [] as Array[int]
		# SEAM: row_cells[cell.cy] is Variant; push requires cast.
		@warning_ignore("unsafe_cast")
		var arr: Array = row_cells[cell.cy] as Array
		arr.push_back(cell.cx)

	var barrier_mat: StandardMaterial3D = StandardMaterial3D.new()
	barrier_mat.albedo_color = BARRIER_COLOR

	# One barrier instance per contiguous run on each row.
	for row: Variant in row_cells.keys():
		@warning_ignore("unsafe_cast")
		var cols_var: Array = row_cells[row] as Array
		var cols: Array[int] = []
		for v: Variant in cols_var:
			@warning_ignore("unsafe_cast")
			cols.append(int(v as float))
		cols.sort()

		# Split cols into contiguous runs.
		var runs: Array[Array] = []
		var cur_run: Array[int] = [cols[0]]
		for i: int in range(1, cols.size()):
			if cols[i] == cur_run[-1] + 1:
				cur_run.append(cols[i])
			else:
				runs.append(cur_run)
				cur_run = [cols[i]]
		runs.append(cur_run)

		@warning_ignore("unsafe_cast")
		var row_int: int = int(row as float)
		for run: Array in runs:
			@warning_ignore("unsafe_cast")
			var first_col: int = int(run[0] as float)
			@warning_ignore("unsafe_cast")
			var last_col: int = int(run[run.size() - 1] as float)
			var run_width: float = float(last_col - first_col + 1) * CELL_X
			var cx_world: float = (float(first_col) + float(last_col + 1)) * 0.5 * CELL_X
			var cz_world: float = float(row_int) * CELL_Z + CELL_Z * 0.5
			var pos: Vector3 = Vector3(cx_world, BARRIER_H * 0.5, cz_world)

			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Barrier_r%d_c%d" % [row_int, first_col]
			scene_root.add_child(body)
			body.owner = scene_root

			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "BarrierMesh"
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(run_width, BARRIER_H, CELL_Z)
			bm.material = barrier_mat
			mi.mesh = bm
			mi.position = pos
			body.add_child(mi)
			mi.owner = scene_root

			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.name = "BarrierCollision"
			var bs: BoxShape3D = BoxShape3D.new()
			bs.size = Vector3(run_width, BARRIER_H, CELL_Z)
			cs.shape = bs
			cs.position = pos
			body.add_child(cs)
			cs.owner = scene_root


func _add_ammo_pickups(scene_root: Node3D, grid: Dictionary) -> void:
	var pickup_packed: PackedScene = load(PICKUP_AMMO_SCENE) as PackedScene

	var cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(grid, 6, CELL_X, CELL_Z)
	for pickup_idx: int in range(cells.size()):
		var cell: GridJsonIter.GridCell = cells[pickup_idx]
		# Slight random yaw ±15° using deterministic offset per index.
		var yaw_deg: float = float((pickup_idx * 73 + 17) % 31) - 15.0

		var pickup: Node3D = pickup_packed.instantiate() as Node3D
		pickup.name = "AmmoPickup%d" % pickup_idx
		pickup.position = Vector3(cell.wx, 0.0, cell.wz)
		pickup.rotation_degrees.y = yaw_deg
		scene_root.add_child(pickup)
		# Instance root only — do NOT recurse into packed-scene children.
		pickup.owner = scene_root


func _add_raised_platform(scene_root: Node3D) -> void:
	var sz: Vector3 = Vector3(PLATFORM_W, PLATFORM_THICK, PLATFORM_D)
	var cx: float = PLATFORM_X + PLATFORM_W * 0.5
	var cz: float = PLATFORM_Z + PLATFORM_D * 0.5
	var pos: Vector3 = Vector3(cx, PLATFORM_Y - PLATFORM_THICK * 0.5, cz)

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PlatformSlab"
	scene_root.add_child(body)
	body.owner = scene_root

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "PlatformMesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.material = floor_mat
	mi.mesh = bm
	mi.position = pos
	body.add_child(mi)
	mi.owner = scene_root

	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "PlatformCollision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
	cs.owner = scene_root


func _add_ramp(scene_root: Node3D) -> void:
	# Ramp: west face of platform, slopes floor (y=0) up to platform top (y=PLATFORM_Y).
	# Ramp geometry: a box rotated so its top face is inclined.
	# Ramp spans full platform depth (z: PLATFORM_Z to PLATFORM_Z+PLATFORM_D).
	# Ramp horizontal depth = RAMP_DEPTH (1 m), placed west of platform x = PLATFORM_X.
	# The ramp box centre-x = PLATFORM_X - RAMP_DEPTH*0.5, tilted about Z axis.
	var ramp_rise: float = PLATFORM_Y
	var ramp_run: float = RAMP_DEPTH
	# Box diagonal = sqrt(rise^2 + run^2); box thickness = PLATFORM_THICK.
	var diag: float = sqrt(ramp_rise * ramp_rise + ramp_run * ramp_run)
	var angle: float = atan2(ramp_rise, ramp_run)

	var sz: Vector3 = Vector3(diag, PLATFORM_THICK, PLATFORM_D)
	# Centre of ramp box: midpoint between floor contact and platform edge.
	var cx: float = PLATFORM_X - ramp_run * 0.5
	var cy: float = ramp_rise * 0.5
	var cz: float = PLATFORM_Z + PLATFORM_D * 0.5
	var pos: Vector3 = Vector3(cx, cy, cz)

	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PlatformRamp"
	scene_root.add_child(body)
	body.owner = scene_root

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RampMesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	bm.material = floor_mat
	mi.mesh = bm
	mi.position = pos
	# Tilt: rotate around Z axis so top face slopes up eastward (+X direction is up).
	mi.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(angle))
	body.add_child(mi)
	mi.owner = scene_root

	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "RampCollision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = pos
	cs.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(angle))
	body.add_child(cs)
	cs.owner = scene_root


func _add_navmesh(scene_root: Node3D) -> void:
	var nav_mesh: NavigationMesh = load(NAVMESH_PATH) as NavigationMesh
	if nav_mesh == null:
		push_error("build_ruined_warehouse: could not load navmesh from " + NAVMESH_PATH)
		return
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	nav_region.navigation_mesh = nav_mesh
	scene_root.add_child(nav_region)
	nav_region.owner = scene_root
	print("build_ruined_warehouse: NavigationRegion3D added with pre-baked navmesh")


func _add_lighting(scene_root: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.9, 1.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 50.0
	scene_root.add_child(sun)
	sun.owner = scene_root

	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	scene_root.add_child(we)
	we.owner = scene_root
