# tools/build_shared_apartment.gd — headless scene builder for shared_apartment.tscn.
## Run: $GODOT --headless --path . --script tools/build_shared_apartment.gd
## Reads levels/drawn/current.json, creates the GridMap scene, and saves it.
## This is a one-shot author-time tool; re-run if the grid JSON changes.
@tool
extends SceneTree

const ITEM_WALL_KITCHEN: int = 0
const ITEM_WALL_TWIN: int = 1
const ITEM_WALL_MASTER: int = 2
const ITEM_WALL_HALL: int = 3
const ITEM_WALL_BATH: int = 4
const ITEM_WALL_DEFAULT: int = 5
const ITEM_WINDOW_SILL: int = 6

const ROOM_TILE: Dictionary = {
	10: 0,
	20: 1,
	30: 2,
	40: 4,
	50: 3,
	60: 3,
}

const CODE_FLOOR: int = 0
const CODE_WALL: int = 1
const CODE_DOOR: int = 2
const CODE_WINDOW: int = 3
const CODE_ITEM: int = 4


func _init() -> void:
	_build()
	quit()


func _build() -> void:
	var library: MeshLibrary = _make_mesh_library()

	# Root node
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "SharedApartment"

	# --- GridMap ---
	var gmap: GridMap = GridMap.new()
	gmap.name = "ApartmentMap"
	gmap.mesh_library = library
	gmap.cell_size = Vector3(1.5, 3.0, 1.5)
	gmap.cell_center_x = true
	gmap.cell_center_y = true
	gmap.cell_center_z = true
	scene_root.add_child(gmap)
	gmap.owner = scene_root
	_populate_gridmap(gmap)

	# --- Floor slab ---
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	scene_root.add_child(floor_body)
	floor_body.owner = scene_root

	var floor_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	floor_mesh_inst.name = "MeshInstance3D"
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(36.0, 0.2, 24.0)
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.78, 0.66, 0.48, 1.0)
	floor_mesh.material = floor_mat
	floor_mesh_inst.mesh = floor_mesh
	floor_body.add_child(floor_mesh_inst)
	floor_mesh_inst.owner = scene_root

	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	floor_shape.name = "CollisionShape3D"
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(36.0, 0.2, 24.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_shape.owner = scene_root

	# Floor slab center at (18, -0.1, 12) — grid extent is 24 cols × 16 rows × 1.5 m/cell.
	floor_body.position = Vector3(18.0, -0.1, 12.0)

	# --- Lighting: warm sun at ~45 deg azimuth / 30 deg elevation, energy 0.8 ---
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.light_color = Color(1.0, 0.95, 0.9, 1.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 50.0
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	scene_root.add_child(sun)
	sun.owner = scene_root

	# --- WorldEnvironment: ProceduralSky + Filmic tonemap ---
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky_res: Sky = Sky.new()
	sky_res.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# tonemap_mode = 3 = TONE_MAPPER_FILMIC (per blockout_01.tscn reference).
	env.tonemap_mode = 3 as Environment.ToneMapper
	env.tonemap_exposure = 1.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	scene_root.add_child(world_env)
	world_env.owner = scene_root

	# --- Player: spawn at corridor cell (10,7) → world (15.75, 1, 11.25) ---
	var player_scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	var player: Node3D = player_scene.instantiate() as Node3D
	player.name = "Player"
	player.position = Vector3(15.75, 1.0, 11.25)
	scene_root.add_child(player)
	player.owner = scene_root

	# --- Master bedroom props (Slice 2) ---
	_place_props(scene_root)

	# Save scene
	var packed: PackedScene = PackedScene.new()
	var pack_err: int = packed.pack(scene_root)
	if pack_err != OK:
		push_error("build_shared_apartment: pack failed: " + str(pack_err))
		return
	var save_err: int = ResourceSaver.save(packed, "res://levels/shared_apartment.tscn")
	if save_err != OK:
		push_error("build_shared_apartment: save failed: " + str(save_err))
		return
	print(
		"build_shared_apartment: saved levels/shared_apartment.tscn with ",
		gmap.get_used_cells().size(),
		" cells + 5 master-bedroom props.",
	)


func _populate_gridmap(gmap: GridMap) -> void:
	var file: FileAccess = FileAccess.open("res://levels/drawn/current.json", FileAccess.READ)
	if file == null:
		push_error("build_shared_apartment: cannot open current.json")
		return
	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("build_shared_apartment: JSON parse failed")
		return

	# SEAM: JSON.parse_string returns untyped Variant; cast checked above.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary
	# SEAM: JSON array entries are untyped Variants from JSON.parse_string.
	@warning_ignore("unsafe_cast")
	var cells_raw: Array = grid["cells"] as Array
	@warning_ignore("unsafe_cast")
	var rooms_raw: Array = grid["rooms"] as Array
	@warning_ignore("unsafe_cast")
	var w: int = int(grid["width"] as float)

	var room_lookup: Dictionary = {}
	for entry: Variant in rooms_raw:
		# SEAM: JSON object entries are untyped Variants.
		@warning_ignore("unsafe_cast")
		var r: Dictionary = entry as Dictionary
		@warning_ignore("unsafe_cast")
		var rx: int = int(r["x"] as float)
		@warning_ignore("unsafe_cast")
		var ry: int = int(r["y"] as float)
		@warning_ignore("unsafe_cast")
		var rid: int = int(r["id"] as float)
		room_lookup[rx * 10000 + ry] = rid

	for i: int in range(cells_raw.size()):
		@warning_ignore("unsafe_cast")
		var code: int = int(cells_raw[i] as float)
		if code == CODE_FLOOR or code == CODE_DOOR or code == CODE_ITEM:
			continue
		var col: int = i % w
		# @warning_ignore below: integer division is intentional (row index from flat array).
		@warning_ignore("integer_division")
		var row: int = i / w
		var item_id: int = _item_for(code, col, row, room_lookup)
		if item_id >= 0:
			gmap.set_cell_item(Vector3i(col, 0, row), item_id)


func _item_for(code: int, col: int, row: int, room_lookup: Dictionary) -> int:
	if code == CODE_WINDOW:
		return ITEM_WINDOW_SILL
	if code == CODE_WALL:
		var key: int = col * 10000 + row
		if room_lookup.has(key):
			@warning_ignore("unsafe_cast")
			var room_id: int = int(room_lookup[key] as float)
			if ROOM_TILE.has(room_id):
				@warning_ignore("unsafe_cast")
				return int(ROOM_TILE[room_id] as float)
		return ITEM_WALL_DEFAULT
	return -1


func _make_mesh_library() -> MeshLibrary:
	return load("res://resources/apartment_tiles.meshlib.tres") as MeshLibrary


## Slice 2 — master bedroom greybox props.
## Cell→world: col*1.5+0.75 on X, row*1.5+0.75 on Z (cell_center_* = true, cell_size=1.5).
## Box centre Y = height/2 (floor surface ≈ y 0).
func _place_props(scene_root: Node3D) -> void:
	# BedMaster — 6-cell group (18,2)(19,2)(18,3)(19,3)(18,4)(19,4)
	# Mid col = 18.5 → X = 18.5*1.5+0.75 = 28.5; mid row = 3 → Z = 3*1.5+0.75 = 5.25
	_make_prop(
		scene_root,
		"BedMaster",
		Vector3(28.5, 0.25, 5.25),
		Vector3(3.0, 0.5, 4.5),
		Color(0.55, 0.40, 0.28),
	)

	# Wardrobe — cells (22,2)(22,3)
	# Col 22 → X = 22*1.5+0.75 = 33.75; mid row 2.5 → Z = 2.5*1.5+0.75 = 4.5
	_make_prop(
		scene_root,
		"Wardrobe",
		Vector3(33.75, 1.0, 4.5),
		Vector3(1.5, 2.0, 3.0),
		Color(0.50, 0.36, 0.25),
	)

	# NightstandMaster — cell (20,4)
	# X = 20*1.5+0.75 = 30.75; Z = 4*1.5+0.75 = 6.75
	_make_prop(
		scene_root,
		"NightstandMaster",
		Vector3(30.75, 0.3, 6.75),
		Vector3(0.7, 0.6, 0.7),
		Color(0.58, 0.43, 0.30),
	)

	# ChairMaster — cell (20,1)
	# X = 30.75; Z = 1*1.5+0.75 = 2.25
	_make_prop(
		scene_root,
		"ChairMaster",
		Vector3(30.75, 0.45, 2.25),
		Vector3(0.6, 0.9, 0.6),
		Color(0.45, 0.45, 0.50),
	)

	# DeskMaster — cell (21,1)
	# X = 21*1.5+0.75 = 32.25; Z = 2.25
	_make_prop(
		scene_root,
		"DeskMaster",
		Vector3(32.25, 0.375, 2.25),
		Vector3(1.2, 0.75, 0.7),
		Color(0.52, 0.38, 0.27),
	)


## Creates a greybox prop: MeshInstance3D with a BoxMesh and baked StandardMaterial3D albedo.
## Added as a direct child of scene_root; owner set for scene serialisation.
func _make_prop(
	scene_root: Node3D,
	prop_name: String,
	world_pos: Vector3,
	box_size: Vector3,
	albedo: Color,
) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo

	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	box.material = mat

	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = prop_name
	inst.mesh = box
	inst.position = world_pos

	scene_root.add_child(inst)
	inst.owner = scene_root
