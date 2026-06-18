# scripts/build_rw_slice_e4.gd — E4 fake-floor trap helpers for build_ruined_warehouse.gd.
# Provides: fake tile meshes (no collision), perforated floor slab, FallZone trigger.
class_name BuildRWSliceE4
extends RefCounted

# Fake-floor tile visual tell: FLOOR_COLOR lightened ~10% and slightly desaturated.
const FAKE_FLOOR_COLOR: Color = Color(0.122, 0.118, 0.172, 1.0)
const FLOOR_COLOR: Color = Color(0.078, 0.078, 0.125, 1.0)
const FLOOR_THICK: float = 0.2
const FLOOR_Y: float = -0.1

# FallZone: wide flat trigger below arena. Top at y = -6, spans 56×40 m (grid + margin).
const FALL_ZONE_TOP_Y: float = -6.0
const FALL_ZONE_THICK: float = 1.0
const FALL_ZONE_W: float = 56.0
const FALL_ZONE_D: float = 40.0
# Centre the zone over the 48×32 m grid (grid centre x=24, z=16).
const FALL_ZONE_CX: float = 24.0
const FALL_ZONE_CZ: float = 16.0

# Fake-floor cell definitions: (col, row) — matches ruined_warehouse.json id=7 entries.
const FAKE_CELLS: Array[Vector2i] = [
	Vector2i(9, 8),
	Vector2i(16, 7),
	Vector2i(13, 5),
]


## Add one visual-only MeshInstance3D per id=7 fake-floor cell.
## No StaticBody3D — player passes through. Faint tell via slightly lighter albedo.
static func add_fake_floor_tiles(scene_root: Node3D, cell_x: float, cell_z: float) -> void:
	var fake_mat: StandardMaterial3D = StandardMaterial3D.new()
	fake_mat.albedo_color = FAKE_FLOOR_COLOR

	for i: int in range(FAKE_CELLS.size()):
		var cell: Vector2i = FAKE_CELLS[i]
		var wx: float = float(cell.x) * cell_x + cell_x * 0.5
		var wz: float = float(cell.y) * cell_z + cell_z * 0.5

		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "FakeFloor%d" % i
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(cell_x, FLOOR_THICK, cell_z)
		bm.material = fake_mat
		mi.mesh = bm
		mi.position = Vector3(wx, FLOOR_Y, wz)
		scene_root.add_child(mi)
		mi.owner = scene_root


## Build perforated floor: one StaticBody3D per solid Z-row strip, split around fake cells.
## Replaces the single full-slab _add_floor_slab in the main builder.
static func add_perforated_floor(
	scene_root: Node3D, grid_w: int, grid_h: int, cell_x: float, cell_z: float
) -> void:
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR

	# Build set of fake-cell columns per row for quick lookup.
	var fake_cols_by_row: Dictionary = {}
	for fc: Vector2i in FAKE_CELLS:
		if not fake_cols_by_row.has(fc.y):
			fake_cols_by_row[fc.y] = [] as Array[int]
		# SEAM: Dictionary value is Variant; cast to append.
		@warning_ignore("unsafe_cast")
		var arr: Array = fake_cols_by_row[fc.y] as Array
		arr.push_back(fc.x)

	# For each Z-row, build continuous X-strips that skip fake columns.
	for row: int in range(grid_h):
		# Collect fake columns for this row (sorted).
		var skip_cols: Array[int] = []
		if fake_cols_by_row.has(row):
			@warning_ignore("unsafe_cast")
			var raw: Array = fake_cols_by_row[row] as Array
			for v: Variant in raw:
				@warning_ignore("unsafe_cast")
				skip_cols.append(int(v as float))
			skip_cols.sort()

		# Build X segments: [start_col, end_col) pairs skipping fake columns.
		var segments: Array[Vector2i] = []
		var seg_start: int = 0
		for sc: int in skip_cols:
			if sc > seg_start:
				segments.append(Vector2i(seg_start, sc))
			seg_start = sc + 1
		if seg_start < grid_w:
			segments.append(Vector2i(seg_start, grid_w))

		# One StaticBody3D slab per segment.
		for seg: Vector2i in segments:
			var col_start: int = seg.x
			var col_end: int = seg.y
			var seg_w: float = float(col_end - col_start) * cell_x
			var seg_cx: float = float(col_start) * cell_x + seg_w * 0.5
			var seg_cz: float = float(row) * cell_z + cell_z * 0.5
			var sz: Vector3 = Vector3(seg_w, FLOOR_THICK, cell_z)
			var pos: Vector3 = Vector3(seg_cx, FLOOR_Y, seg_cz)

			var body: StaticBody3D = StaticBody3D.new()
			body.name = "FloorSlab_r%d_c%d" % [row, col_start]
			scene_root.add_child(body)
			body.owner = scene_root

			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "FloorMesh"
			var bm: BoxMesh = BoxMesh.new()
			bm.size = sz
			bm.material = floor_mat
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


## Add FallZone Area3D below the arena. Wired in ruined_warehouse.gd _ready().
static func add_fall_zone(scene_root: Node3D) -> void:
	var area: Area3D = Area3D.new()
	area.name = "FallZone"
	area.monitoring = true
	# Layer 0 = world/default; player is also on layer 0 by default.
	area.collision_mask = 1
	scene_root.add_child(area)
	area.owner = scene_root

	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "FallZoneShape"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(FALL_ZONE_W, FALL_ZONE_THICK, FALL_ZONE_D)
	cs.shape = bs
	cs.position = Vector3(FALL_ZONE_CX, FALL_ZONE_TOP_Y - FALL_ZONE_THICK * 0.5, FALL_ZONE_CZ)
	area.add_child(cs)
	cs.owner = scene_root
