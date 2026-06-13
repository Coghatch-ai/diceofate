# levels/guided_level.gd — reusable grid-guided level builder; reads a drawn grid JSON at runtime.
class_name GuidedLevel
extends Node3D

const CELL_SIZE: float = 2.0
const WALL_HEIGHT: float = 3.0
const WALL_THICKNESS: float = 0.2
const FLOOR_DEPTH: float = 0.2

const CODE_FLOOR: int = 0
const CODE_WALL: int = 1
const CODE_DOOR: int = 2
const CODE_WINDOW: int = 3
const CODE_WARDROBE: int = 4
const CODE_BED: int = 5
const CODE_ELECTRONIC: int = 6
const CODE_NIGHTSTAND: int = 7

const COLOR_FLOOR: Color = Color(0.75, 0.65, 0.45, 1.0)
const COLOR_WALL_BEDROOM: Color = Color(0.85, 0.78, 0.65, 1.0)
const COLOR_WALL_HALL: Color = Color(0.65, 0.65, 0.70, 1.0)
const COLOR_WARDROBE: Color = Color(0.35, 0.22, 0.12, 1.0)
const COLOR_BED: Color = Color(0.90, 0.85, 0.78, 1.0)
const COLOR_ELECTRONIC: Color = Color(0.15, 0.15, 0.18, 1.0)
const COLOR_NIGHTSTAND: Color = Color(0.55, 0.38, 0.22, 1.0)

# Hall zone rows (0-indexed): rows 9–10 in the brief (hall area)
const HALL_ROW_MIN: int = 9
const HALL_ROW_MAX: int = 10

@export var grid_path: String = ""

var _width: int = 0
var _height: int = 0
var _cells: Array = []


func _ready() -> void:
	if grid_path.is_empty():
		push_error("GuidedLevel: grid_path is not set")
		return
	var data: Dictionary = _load_grid(grid_path)
	if data.is_empty():
		return
	# SEAM: Dictionary.get() returns Variant; each value cast to its expected type below.
	@warning_ignore("unsafe_cast")
	_width = data.get("width", 0) as int
	@warning_ignore("unsafe_cast")
	_height = data.get("height", 0) as int
	@warning_ignore("unsafe_cast")
	_cells = data.get("cells", []) as Array

	if _width <= 0 or _height <= 0 or _cells.is_empty():
		push_error(
			"GuidedLevel: invalid grid w=%d h=%d cells=%d" % [_width, _height, _cells.size()]
		)
		return

	_build_floor()
	_build_walls()
	_build_doors()
	_build_windows()
	_build_items()
	_build_environment()
	call_deferred("_spawn_player")


func _load_grid(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GuidedLevel: cannot open grid at %s" % path)
		return {}
	var raw: String = file.get_as_text()
	file.close()
	# SEAM: JSON.parse_string() returns Variant; cast after null-check.
	@warning_ignore("unsafe_cast")
	var data: Dictionary = JSON.parse_string(raw) as Dictionary
	if data == null:
		push_error("GuidedLevel: failed to parse JSON at %s" % path)
		return {}
	return data


func _cell(col: int, row: int) -> int:
	if col < 0 or col >= _width or row < 0 or row >= _height:
		return -1
	var idx: int = row * _width + col
	if idx >= _cells.size():
		return -1
	# SEAM: Array element from JSON is Variant; cast to int for cell code.
	@warning_ignore("unsafe_cast")
	return _cells[idx] as int


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _add_static_box(
	pos: Vector3, size: Vector3, mat: StandardMaterial3D, rot_y_deg: float
) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	if rot_y_deg != 0.0:
		body.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.surface_set_material(0, mat)
	mesh_inst.mesh = box_mesh

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape

	body.add_child(mesh_inst)
	body.add_child(col_shape)
	add_child(body)


func _add_mesh_only(pos: Vector3, size: Vector3, mat: StandardMaterial3D, rot_y_deg: float) -> void:
	var node := Node3D.new()
	node.position = pos
	if rot_y_deg != 0.0:
		node.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.surface_set_material(0, mat)
	mesh_inst.mesh = box_mesh
	node.add_child(mesh_inst)
	add_child(node)


func _build_floor() -> void:
	var floor_w: float = float(_width) * CELL_SIZE
	var floor_h: float = float(_height) * CELL_SIZE
	var size := Vector3(floor_w, FLOOR_DEPTH, floor_h)
	var pos := Vector3(floor_w * 0.5, -FLOOR_DEPTH * 0.5, floor_h * 0.5)
	_add_static_box(pos, size, _make_mat(COLOR_FLOOR), 0.0)


func _is_wall_code(code: int) -> bool:
	return code == CODE_WALL


func _wall_color_for_row(row: int) -> Color:
	if row >= HALL_ROW_MIN and row <= HALL_ROW_MAX:
		return COLOR_WALL_HALL
	return COLOR_WALL_BEDROOM


func _build_walls() -> void:
	# Greedy merge: scan rows for horizontal runs, then columns for remaining vertical runs.
	# visited tracks cells already consumed into a merged wall segment.
	var visited: Array[bool] = []
	visited.resize(_width * _height)
	visited.fill(false)

	# Horizontal runs first
	for row: int in range(_height):
		var col: int = 0
		while col < _width:
			if visited[row * _width + col] or not _is_wall_code(_cell(col, row)):
				col += 1
				continue
			# Extend run rightward
			var run_end: int = col
			while run_end + 1 < _width and _is_wall_code(_cell(run_end + 1, row)):
				run_end += 1
			var run_len: int = run_end - col + 1
			for c: int in range(col, run_end + 1):
				visited[row * _width + c] = true
			_spawn_wall_run_h(col, row, run_len)
			col = run_end + 1

	# Vertical runs for any cells not yet consumed
	for col: int in range(_width):
		var row: int = 0
		while row < _height:
			if visited[row * _width + col] or not _is_wall_code(_cell(col, row)):
				row += 1
				continue
			var run_end: int = row
			while run_end + 1 < _height and _is_wall_code(_cell(col, run_end + 1)):
				run_end += 1
			var run_len: int = run_end - row + 1
			for r: int in range(row, run_end + 1):
				visited[r * _width + col] = true
			_spawn_wall_run_v(col, row, run_len)
			row = run_end + 1


func _spawn_wall_run_h(col: int, row: int, run_len: int) -> void:
	var w: float = float(run_len) * CELL_SIZE
	var size := Vector3(w, WALL_HEIGHT, WALL_THICKNESS)
	var cx: float = (float(col) + float(run_len) * 0.5) * CELL_SIZE
	var cz: float = (float(row) + 0.5) * CELL_SIZE
	var pos := Vector3(cx, WALL_HEIGHT * 0.5, cz)
	var color: Color = _wall_color_for_row(row)
	_add_static_box(pos, size, _make_mat(color), 0.0)


func _spawn_wall_run_v(col: int, row: int, run_len: int) -> void:
	var d: float = float(run_len) * CELL_SIZE
	var size := Vector3(WALL_THICKNESS, WALL_HEIGHT, d)
	var cx: float = (float(col) + 0.5) * CELL_SIZE
	var cz: float = (float(row) + float(run_len) * 0.5) * CELL_SIZE
	var pos := Vector3(cx, WALL_HEIGHT * 0.5, cz)
	var color: Color = _wall_color_for_row(row)
	_add_static_box(pos, size, _make_mat(color), 0.0)


func _build_doors() -> void:
	var door_frame_mat: StandardMaterial3D = _make_mat(Color(0.55, 0.48, 0.38, 1.0))
	for row: int in range(_height):
		for col: int in range(_width):
			if _cell(col, row) != CODE_DOOR:
				continue
			var cx: float = (float(col) + 0.5) * CELL_SIZE
			var cz: float = (float(row) + 0.5) * CELL_SIZE
			# Door frame: two vertical posts + lintel; no collision block in gap.
			# Left post
			_add_mesh_only(
				Vector3(cx - CELL_SIZE * 0.45, WALL_HEIGHT * 0.5, cz),
				Vector3(0.1, WALL_HEIGHT, WALL_THICKNESS * 1.5),
				door_frame_mat,
				5.0
			)
			# Right post
			_add_mesh_only(
				Vector3(cx + CELL_SIZE * 0.45, WALL_HEIGHT * 0.5, cz),
				Vector3(0.1, WALL_HEIGHT, WALL_THICKNESS * 1.5),
				door_frame_mat,
				5.0
			)
			# Lintel
			_add_mesh_only(
				Vector3(cx, WALL_HEIGHT - 0.1, cz),
				Vector3(CELL_SIZE, 0.15, WALL_THICKNESS * 1.5),
				door_frame_mat,
				5.0
			)


func _build_windows() -> void:
	var sill_mat: StandardMaterial3D = _make_mat(Color(0.90, 0.87, 0.78, 1.0))
	var window_wall_mat: StandardMaterial3D = _make_mat(COLOR_WALL_BEDROOM)
	for row: int in range(_height):
		for col: int in range(_width):
			if _cell(col, row) != CODE_WINDOW:
				continue
			var cx: float = (float(col) + 0.5) * CELL_SIZE
			var cz: float = (float(row) + 0.5) * CELL_SIZE
			# Half-height wall sill (blocks movement, visually open above)
			var sill_h: float = 1.5
			_add_static_box(
				Vector3(cx, sill_h * 0.5, cz),
				Vector3(CELL_SIZE, sill_h, WALL_THICKNESS),
				window_wall_mat,
				0.0
			)
			# Sill ledge with slight angle
			_add_mesh_only(
				Vector3(cx, sill_h + 0.05, cz), Vector3(CELL_SIZE, 0.08, 0.35), sill_mat, 5.0
			)


func _build_items() -> void:
	for row: int in range(_height):
		for col: int in range(_width):
			var code: int = _cell(col, row)
			if code < CODE_WARDROBE or code > CODE_NIGHTSTAND:
				continue
			var cx: float = (float(col) + 0.5) * CELL_SIZE
			var cz: float = (float(row) + 0.5) * CELL_SIZE
			match code:
				CODE_WARDROBE:
					_add_static_box(
						Vector3(cx, 1.0, cz),
						Vector3(0.8, 2.0, 0.5),
						_make_mat(COLOR_WARDROBE),
						15.0
					)
				CODE_BED:
					_add_static_box(
						Vector3(cx, 0.25, cz), Vector3(1.8, 0.5, 1.0), _make_mat(COLOR_BED), 0.0
					)
				CODE_ELECTRONIC:
					_add_static_box(
						Vector3(cx, 0.6, cz),
						Vector3(0.8, 1.2, 0.1),
						_make_mat(COLOR_ELECTRONIC),
						0.0
					)
				CODE_NIGHTSTAND:
					_add_static_box(
						Vector3(cx, 0.3, cz),
						Vector3(0.5, 0.6, 0.4),
						_make_mat(COLOR_NIGHTSTAND),
						5.0
					)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _spawn_player() -> void:
	var player_scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	if player_scene == null:
		push_error("GuidedLevel: could not load player.tscn")
		return
	var player: Node3D = player_scene.instantiate() as Node3D
	if player == null:
		push_error("GuidedLevel: player instantiation failed")
		return
	# Spawn at col 12, row 9 (central lower-hall cell), 2 m/cell
	player.position = Vector3(12.5 * CELL_SIZE, 1.0, 9.5 * CELL_SIZE)
	add_child(player)
