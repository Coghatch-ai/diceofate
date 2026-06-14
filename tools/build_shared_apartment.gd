# tools/build_shared_apartment.gd — headless GridMap + MeshLibrary builder for the shared apartment.
## Run: $GODOT --headless --path . --script tools/build_shared_apartment.gd
## Then: $GODOT --headless --path . --import
## Output: resources/apartment_tiles.meshlib.tres + levels/shared_apartment.tscn (cells baked in).
## One build path — never hand-type Transform3D walls. Runs once; produces a saved .tscn.
@tool
extends SceneTree

# Props helper module
const ApartmentProps := preload("res://tools/apartment_props.gd")

# --- Cell and level constants ---
const CELL_SIZE := Vector3(1.5, 3.0, 1.5)
const GRID_W := 24
const GRID_H := 16

# Grid structure codes
const CODE_FLOOR := 0
const CODE_WALL := 1
const CODE_DOOR := 2
const CODE_WINDOW := 3
const CODE_ITEM := 4

# Zone ids (from rooms list in current.json)
const ZONE_BEDROOM_B := 10
const ZONE_BEDROOM_A := 20
const ZONE_BATHROOM := 30
const ZONE_KITCHEN := 50
const ZONE_LOUNGE := 40
const ZONE_CORRIDOR := 60

# Zone wall colours — hex recorded per design doc
# zone 50 kitchen  warm-grey    #8A7B70
# zone 40 lounge   cool-blue    #6A7D8C
# zone 20 bedroomA muted-green  #7A8F7A
# zone 10 bedroomB muted-purple #8A7A8F
# zone 60 corridor neutral-grey #7A7A7A
# zone 30 bathroom pale-cyan    #7A9090
const ZONE_COLORS: Dictionary = {
	10: Color(0.541, 0.478, 0.561, 1.0),
	20: Color(0.478, 0.561, 0.478, 1.0),
	30: Color(0.478, 0.565, 0.565, 1.0),
	40: Color(0.416, 0.490, 0.549, 1.0),
	50: Color(0.541, 0.482, 0.439, 1.0),
	60: Color(0.478, 0.478, 0.478, 1.0),
}

# Floor colour — flat warm off-white
const FLOOR_COLOR := Color(0.78, 0.75, 0.70, 1.0)
# Window sill colour — neutral stone
const SILL_COLOR := Color(0.65, 0.62, 0.58, 1.0)
# Window glass colour — pale blue, semi-transparent
const GLASS_COLOR := Color(0.60, 0.75, 0.90, 0.30)

# MeshLibrary item ids — fixed order; must match what _item_for returns
const ITEM_WALL_KITCHEN := 0
const ITEM_WALL_LOUNGE := 1
const ITEM_WALL_BEDROOM_A := 2
const ITEM_WALL_BEDROOM_B := 3
const ITEM_WALL_CORRIDOR := 4
const ITEM_WALL_BATHROOM := 5
const ITEM_WINDOW := 6

# Player spawn: corridor cell (10, 7) → world Vector3(15.75, 0.1, 11.25) (cell_center_x/y/z=false)
# col 10 → x = 10*1.5 + 0.75 = 15.75, row 7 → z = 7*1.5 + 0.75 = 11.25
const SPAWN_POS := Vector3(15.75, 0.1, 11.25)

# Sun settings (godot-pixel-lighting)
const SUN_ROT_DEG := Vector3(-45.0, -30.0, 0.0)
const SUN_COLOR := Color(1.0, 0.95, 0.9, 1.0)
const SUN_ENERGY := 1.0

# Parsed grid data
var _cells: Array = []
var _rooms_map: Dictionary = {}


func _init() -> void:
	_build()
	quit()


func _build() -> void:
	if not _load_grid():
		push_error("build_shared_apartment: grid load failed — aborting")
		return
	var meshlib: MeshLibrary = _build_meshlib()
	if meshlib == null:
		push_error("build_shared_apartment: meshlib build failed — aborting")
		return
	var save_err: Error = ResourceSaver.save(
		meshlib, "res://resources/apartment_tiles.meshlib.tres"
	)
	if save_err != OK:
		push_error("build_shared_apartment: meshlib save failed: %d" % save_err)
		return
	print("build_shared_apartment: meshlib saved → resources/apartment_tiles.meshlib.tres")
	_build_and_save_level(meshlib)


# --- Grid loading ---


func _load_grid() -> bool:
	var file: FileAccess = FileAccess.open("res://levels/drawn/current.json", FileAccess.READ)
	if file == null:
		push_error("build_shared_apartment: cannot open levels/drawn/current.json")
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("build_shared_apartment: grid JSON is not a Dictionary")
		return false
	# SEAM: JSON.parse_string returns Variant; strict config (unsafe_cast=2) requires explicit casts.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary
	@warning_ignore("unsafe_cast")
	_cells = grid["cells"] as Array
	# Build room zone map: key = col + row * GRID_W → zone id
	@warning_ignore("unsafe_cast")
	var rooms_raw: Array = grid["rooms"] as Array
	for entry: Variant in rooms_raw:
		# SEAM: each entry is a Variant Dictionary from the JSON array.
		@warning_ignore("unsafe_cast")
		var entry_dict: Dictionary = entry as Dictionary
		@warning_ignore("unsafe_cast")
		var rx: int = int(entry_dict["x"] as float)
		@warning_ignore("unsafe_cast")
		var ry: int = int(entry_dict["y"] as float)
		@warning_ignore("unsafe_cast")
		var rid: int = int(entry_dict["id"] as float)
		_rooms_map[rx + ry * GRID_W] = rid
	return true


# --- MeshLibrary build ---


func _build_meshlib() -> MeshLibrary:
	var lib: MeshLibrary = MeshLibrary.new()
	# Add wall items for each zone
	_add_wall_item(lib, ITEM_WALL_KITCHEN, "wall_kitchen", ZONE_KITCHEN)
	_add_wall_item(lib, ITEM_WALL_LOUNGE, "wall_lounge", ZONE_LOUNGE)
	_add_wall_item(lib, ITEM_WALL_BEDROOM_A, "wall_bedroomA", ZONE_BEDROOM_A)
	_add_wall_item(lib, ITEM_WALL_BEDROOM_B, "wall_bedroomB", ZONE_BEDROOM_B)
	_add_wall_item(lib, ITEM_WALL_CORRIDOR, "wall_corridor", ZONE_CORRIDOR)
	_add_wall_item(lib, ITEM_WALL_BATHROOM, "wall_bathroom", ZONE_BATHROOM)
	# Add window item (layered: sill + glass pane)
	_add_window_item(lib, ITEM_WINDOW, "window")
	return lib


func _add_wall_item(lib: MeshLibrary, item_id: int, item_name: String, zone: int) -> void:
	lib.create_item(item_id)
	lib.set_item_name(item_id, item_name)
	# Solid block filling the full cell: Vector3(1.5, 3, 1.5)
	var box: BoxMesh = BoxMesh.new()
	box.size = CELL_SIZE
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	# SEAM: ZONE_COLORS is a Dictionary keyed by int; get() returns Variant.
	@warning_ignore("unsafe_cast")
	mat.albedo_color = ZONE_COLORS.get(zone, Color(0.5, 0.5, 0.5, 1.0)) as Color
	mat.roughness = 1.0
	mat.metallic = 0.0
	box.material = mat
	lib.set_item_mesh(item_id, box)
	# Collision: BoxShape3D sized to the full cell.
	# set_item_shapes takes a flat Array: [Shape3D, Transform3D, Shape3D, Transform3D, ...].
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = CELL_SIZE
	# SEAM: set_item_shapes needs mixed Array [Shape3D, Transform3D]; no typed Array is possible.
	var shapes: Array = [shape, Transform3D.IDENTITY]
	lib.set_item_shapes(item_id, shapes)


func _add_window_item(lib: MeshLibrary, item_id: int, item_name: String) -> void:
	lib.create_item(item_id)
	lib.set_item_name(item_id, item_name)
	# Layered: sill (opaque, ~1.0 m tall) + glass pane (transparent, ~2.0 m tall above sill)
	# Sill height = 1.0 m, cell height = 3.0 m → sill sits at Y=0 to Y=1.0
	# Y-shift for sill centre: -(cell_h - sill_h)/2 so sill bottom aligns to y=0 (not floating).
	var sill_h := 1.0
	var glass_h := 2.0
	# Sill mesh positioned at Y offset -1.0 (cell centre is at Y=1.5, sill top at 1.0)
	var sill_box: BoxMesh = BoxMesh.new()
	sill_box.size = Vector3(CELL_SIZE.x, sill_h, CELL_SIZE.z)
	var sill_mat: StandardMaterial3D = StandardMaterial3D.new()
	sill_mat.albedo_color = SILL_COLOR
	sill_mat.roughness = 1.0
	sill_box.material = sill_mat
	# Glass pane: transparent, above the sill
	var glass_box: BoxMesh = BoxMesh.new()
	glass_box.size = Vector3(CELL_SIZE.x, glass_h, 0.08)
	var glass_mat: StandardMaterial3D = StandardMaterial3D.new()
	glass_mat.albedo_color = GLASS_COLOR
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.0
	glass_box.material = glass_mat
	# Build a merged ArrayMesh from both boxes using surface import
	# MeshLibrary accepts a single Mesh per item; use a combined ArrayMesh
	var combined: ArrayMesh = ArrayMesh.new()
	# Add sill surfaces (one surface)
	_append_box_to_mesh(
		combined, sill_box, Vector3(0.0, -(CELL_SIZE.y - sill_h) * 0.5, 0.0), sill_mat
	)
	# Add glass pane surfaces; glass centred at sill_top + glass_h/2
	# sill top = -(cell_h/2) + sill_h = -1.5 + 1.0 = -0.5 (in cell-local space where cell centre = 0)
	# glass centre = -0.5 + glass_h/2 = -0.5 + 1.0 = 0.5
	_append_box_to_mesh(combined, glass_box, Vector3(0.0, 0.5, 0.0), glass_mat)
	lib.set_item_mesh(item_id, combined)
	# Collision: sill shape only (glass is visual).
	# set_item_shapes takes flat Array [Shape3D, Transform3D, ...]; sill offset matches sill mesh Y.
	var sill_shape: BoxShape3D = BoxShape3D.new()
	sill_shape.size = Vector3(CELL_SIZE.x, sill_h, CELL_SIZE.z)
	var sill_xform := Transform3D(Basis.IDENTITY, Vector3(0.0, -(CELL_SIZE.y - sill_h) * 0.5, 0.0))
	# SEAM: set_item_shapes needs mixed Array [Shape3D, Transform3D]; no typed Array is possible.
	var shapes: Array = [sill_shape, sill_xform]
	lib.set_item_shapes(item_id, shapes)


## Append the surfaces of a BoxMesh (with material) into a combined ArrayMesh at a given offset.
func _append_box_to_mesh(
	target: ArrayMesh, box: BoxMesh, offset: Vector3, mat: StandardMaterial3D
) -> void:
	# Get mesh arrays from the BoxMesh
	var mesh_arrays: Array = box.get_mesh_arrays()
	# Offset all vertices (ARRAY_VERTEX slot is PackedVector3Array; cast required by strict config).
	if mesh_arrays.size() > Mesh.ARRAY_VERTEX:
		# SEAM: mesh_arrays is Array (untyped element); ARRAY_VERTEX slot is always PackedVector3Array.
		@warning_ignore("unsafe_cast")
		var verts: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for i: int in range(verts.size()):
			verts[i] = verts[i] + offset
		mesh_arrays[Mesh.ARRAY_VERTEX] = verts
	var surface_idx: int = target.get_surface_count()
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	target.surface_set_material(surface_idx, mat)


# --- Level scene build ---


func _build_and_save_level(meshlib: MeshLibrary) -> void:
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "SharedApartment"

	# GridMap
	var grid_map: GridMap = GridMap.new()
	grid_map.name = "ApartmentMap"
	grid_map.mesh_library = meshlib
	grid_map.cell_size = CELL_SIZE
	grid_map.cell_center_x = false
	grid_map.cell_center_y = false
	grid_map.cell_center_z = false
	_populate_grid_map(grid_map)
	scene_root.add_child(grid_map)
	grid_map.owner = scene_root

	# Floor slab — one StaticBody3D with BoxMesh + BoxShape3D covering full grid extent
	_add_floor(scene_root)

	# Lighting (godot-pixel-lighting: DirectionalLight3D + WorldEnvironment)
	_add_lighting(scene_root)

	# Player spawn at corridor cell (10, 7)
	_add_player(scene_root)

	ApartmentProps.add_bedroom_b_props(scene_root)  # Zone 10 — Bedroom B (slice 2)
	ApartmentProps.add_bedroom_a_props(scene_root)  # Zone 20 — Bedroom A (slice 3)
	ApartmentProps.add_kitchen_props(scene_root)  # Zone 50 — Kitchen (slice 4)
	ApartmentProps.add_lounge_props(scene_root)  # Zone 40 — Lounge  (slice 4)
	ApartmentProps.add_bathroom_props(scene_root)  # Zone 30 — Bathroom (slice 5)

	# Pack and save
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(scene_root)
	if pack_err != OK:
		push_error("build_shared_apartment: pack failed: %d" % pack_err)
		return
	var save_err: Error = ResourceSaver.save(packed, "res://levels/shared_apartment.tscn")
	if save_err != OK:
		push_error("build_shared_apartment: scene save failed: %d" % save_err)
		return
	print("build_shared_apartment: saved → levels/shared_apartment.tscn")
	print("build_shared_apartment: grid cells placed: ", grid_map.get_used_cells().size())


func _populate_grid_map(grid_map: GridMap) -> void:
	for i: int in range(_cells.size()):
		# SEAM: Array element is Variant (JSON integer stored as float)
		@warning_ignore("unsafe_cast")
		var code: int = int(_cells[i] as float)
		var col: int = i % GRID_W
		@warning_ignore("integer_division")
		var row: int = i / GRID_W
		var item_id: int = _item_for(code, col, row)
		if item_id >= 0:
			grid_map.set_cell_item(Vector3i(col, 0, row), item_id)


## Map a cell's structure code + position to a MeshLibrary item id. Returns -1 for empty (no cell).
func _item_for(code: int, col: int, row: int) -> int:
	match code:
		CODE_WALL:
			return _wall_item_for_zone(_nearest_zone(col, row))
		CODE_WINDOW:
			return ITEM_WINDOW
		CODE_FLOOR, CODE_DOOR, CODE_ITEM:
			return -1  # empty (floor handled by slab; door = passable gap; item = floor this slice)
		_:
			return -1


## Return the wall item id for a given zone id. Falls back to corridor grey.
func _wall_item_for_zone(zone: int) -> int:
	# Use a table to avoid exceeding max-returns (6). All unlisted zones fall back to corridor.
	const ZONE_TO_ITEM: Dictionary = {
		10: 3,  # ZONE_BEDROOM_B → ITEM_WALL_BEDROOM_B
		20: 2,  # ZONE_BEDROOM_A → ITEM_WALL_BEDROOM_A
		30: 5,  # ZONE_BATHROOM  → ITEM_WALL_BATHROOM
		40: 1,  # ZONE_LOUNGE    → ITEM_WALL_LOUNGE
		50: 0,  # ZONE_KITCHEN   → ITEM_WALL_KITCHEN
		60: 4,  # ZONE_CORRIDOR  → ITEM_WALL_CORRIDOR
	}
	# SEAM: Dictionary.get() returns Variant; fallback is ITEM_WALL_CORRIDOR.
	@warning_ignore("unsafe_cast")
	return ZONE_TO_ITEM.get(zone, ITEM_WALL_CORRIDOR) as int


## Scan N/E/S/W from a wall cell to find the nearest room zone. Returns ZONE_CORRIDOR if none found.
func _nearest_zone(col: int, row: int) -> int:
	# Check the four cardinal directions in priority order: N, E, S, W
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
	]
	for off: Vector2i in offsets:
		var nc: int = col + off.x
		var nr: int = row + off.y
		if nc < 0 or nc >= GRID_W or nr < 0 or nr >= GRID_H:
			continue
		var key: int = nc + nr * GRID_W
		if _rooms_map.has(key):
			# SEAM: Dictionary value is Variant; explicit cast required by strict config (unsafe_cast=2).
			@warning_ignore("unsafe_cast")
			return _rooms_map[key] as int
	return ZONE_CORRIDOR


func _add_floor(parent: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "FloorSlab"

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box: BoxMesh = BoxMesh.new()
	# Full grid extent: 24*1.5 = 36 m wide, 16*1.5 = 24 m deep, 0.2 m thick
	box.size = Vector3(float(GRID_W) * CELL_SIZE.x, 0.2, float(GRID_H) * CELL_SIZE.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = FLOOR_COLOR
	mat.roughness = 1.0
	box.material = mat
	floor_mesh.mesh = box
	# Centre the slab under the grid; grid origin is (0,0,0), extent is (36,0,24)
	# Slab centre X = 18, Z = 12; top of slab at Y=0 → centre at Y=-0.1
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

	# Add to parent first, then set owners — owner must be an ancestor in the tree.
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
	sun.directional_shadow_max_distance = 50.0
	sun.rotation_degrees = SUN_ROT_DEG
	parent.add_child(sun)
	sun.owner = parent

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	world_env.environment = env
	parent.add_child(world_env)
	world_env.owner = parent


func _add_player(parent: Node3D) -> void:
	var player_scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	if player_scene == null:
		push_error("build_shared_apartment: cannot load player.tscn")
		return
	var player: Node3D = player_scene.instantiate() as Node3D
	if player == null:
		push_error("build_shared_apartment: player instantiate failed")
		return
	player.position = SPAWN_POS
	parent.add_child(player)
	player.owner = parent
