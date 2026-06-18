# scripts/build_rw_slice_e.gd — Slice E helpers for build_ruined_warehouse.gd.
# Extracted to keep the main builder under the 500-line lint cap.
class_name BuildRWSliceE
extends RefCounted

const RUBBLE_COLOR: Color = Color(0.30, 0.27, 0.22, 1.0)
const RUBBLE_H: float = 0.25

const PICKUP_HEALTH_SCENE: String = "res://entities/pickup/pickup_health.tscn"
const PICKUP_AMMO_SCENE: String = "res://entities/pickup/pickup_ammo.tscn"
# Raised platform top surface Y (matches PLATFORM_Y in main builder).
const PLATFORM_Y: float = 1.0

const WAVE_MANAGER_SCRIPT: String = "res://levels/wave_manager.gd"
const ENEMY_SCENE: String = "res://entities/enemy/enemy.tscn"
const ENEMY_RUNNER_SCENE: String = "res://entities/enemy/enemy_runner.tscn"
const ENEMY_TANK_SCENE: String = "res://entities/enemy/enemy_tank.tscn"
const ENEMY_MAGNETIC_SCENE: String = "res://entities/enemy/enemy_magnetic.tscn"
const ENEMY_SHOOTER_SCENE: String = "res://entities/enemy/enemy_shooter.tscn"


## Add visual-only rubble sills at every id=3 breach-gate cell. No collision.
static func add_rubble_sills(
	scene_root: Node3D, grid: Dictionary, cell_x: float, cell_z: float
) -> void:
	var rubble_mat: StandardMaterial3D = StandardMaterial3D.new()
	rubble_mat.albedo_color = RUBBLE_COLOR

	var cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(grid, 3, cell_x, cell_z)
	for rubble_idx: int in range(cells.size()):
		var cell: GridJsonIter.GridCell = cells[rubble_idx]
		# Deterministic yaw ±8° — scatter feel without randomness.
		var yaw_deg: float = float((rubble_idx * 37 + 5) % 17) - 8.0

		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "RubbleSill%d" % rubble_idx
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(cell_x * 0.9, RUBBLE_H, cell_z * 0.9)
		bm.material = rubble_mat
		mi.mesh = bm
		mi.position = Vector3(cell.wx, RUBBLE_H * 0.5, cell.wz)
		mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
		scene_root.add_child(mi)
		mi.owner = scene_root


## Add EnemyWP0..2 patrol waypoints on the kill floor.
static func add_patrol_waypoints(scene_root: Node3D) -> void:
	var wps: Array[Vector3] = [
		Vector3(12.0, 0.0, 16.0),
		Vector3(24.0, 0.0, 20.0),
		Vector3(36.0, 0.0, 10.0),
	]
	for i: int in range(wps.size()):
		var wp: Marker3D = Marker3D.new()
		wp.name = "EnemyWP%d" % i
		wp.position = wps[i]
		scene_root.add_child(wp)
		wp.owner = scene_root


## Add WaveManager node with SpawnMarkers at id=3 cells, wired to patrol waypoints.
static func add_wave_manager(
	scene_root: Node3D,
	grid: Dictionary,
	cell_x: float,
	cell_z: float,
	spawn_pos: Vector3,
	spawn_rot_y: float
) -> void:
	# Collect id=3 breach-gate cells as SpawnMarker positions.
	var gate_cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(
		grid, 3, cell_x, cell_z
	)

	var wm: Node = Node.new()
	wm.name = "WaveManager"
	wm.set_script(load(WAVE_MANAGER_SCRIPT))
	scene_root.add_child(wm)
	wm.owner = scene_root

	# Enemy scenes — same mix as firing_yard.
	# SEAM: WaveManager exports are Variant at construction; set via set() after add_child.
	wm.set("enemy_scene", load(ENEMY_SCENE) as PackedScene)
	wm.set("enemy_scene_b", load(ENEMY_RUNNER_SCENE) as PackedScene)
	wm.set("runner_ratio", 0.3)
	wm.set("enemy_scene_c", load(ENEMY_TANK_SCENE) as PackedScene)
	wm.set("tank_ratio", 0.2)
	wm.set("enemy_scene_d", load(ENEMY_MAGNETIC_SCENE) as PackedScene)
	wm.set("magnet_ratio", 0.1)
	wm.set("enemy_scene_e", load(ENEMY_SHOOTER_SCENE) as PackedScene)
	wm.set("shooter_ratio", 0.1)
	wm.set("start_count", 2)
	# Override spawn position to this level's corridor spawn (not firing_yard's).
	wm.set("spawn_pos", spawn_pos)
	wm.set("spawn_rot_y", spawn_rot_y)

	# Build SpawnMarker children + collect their NodePaths.
	var spawn_paths: Array[NodePath] = []
	for i: int in range(gate_cells.size()):
		var cell: GridJsonIter.GridCell = gate_cells[i]
		var sm: Marker3D = Marker3D.new()
		sm.name = "SpawnMarker%d" % i
		sm.position = Vector3(cell.wx, 0.0, cell.wz)
		wm.add_child(sm)
		sm.owner = scene_root
		spawn_paths.append(NodePath(sm.name))

	# Patrol waypoints are siblings of WaveManager — paths relative from WaveManager.
	var wp_paths: Array[NodePath] = []
	for i: int in range(3):
		wp_paths.append(NodePath("../EnemyWP%d" % i))

	wm.set("spawn_marker_paths", spawn_paths)
	wm.set("patrol_waypoint_paths", wp_paths)


## Add 4 health pickups at id=5 cells (x19–20, y2–3) — top-right pocket.
static func add_health_pickups(
	scene_root: Node3D, grid: Dictionary, cell_x: float, cell_z: float
) -> void:
	var packed: PackedScene = load(PICKUP_HEALTH_SCENE) as PackedScene

	var cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(grid, 5, cell_x, cell_z)
	for pickup_idx: int in range(cells.size()):
		var cell: GridJsonIter.GridCell = cells[pickup_idx]
		var yaw_deg: float = float((pickup_idx * 53 + 11) % 31) - 15.0

		var pickup: Node3D = packed.instantiate() as Node3D
		pickup.name = "HealthCache%d" % pickup_idx
		pickup.position = Vector3(cell.wx, 0.0, cell.wz)
		pickup.rotation_degrees.y = yaw_deg
		scene_root.add_child(pickup)
		pickup.owner = scene_root
		_set_owner_recursive(pickup, scene_root)


## Add 4 ammo pickups at id=4 cells (x19–20, y11–12) — on the +1 m raised platform.
static func add_ammo_cache_pickups(
	scene_root: Node3D, grid: Dictionary, cell_x: float, cell_z: float
) -> void:
	var packed: PackedScene = load(PICKUP_AMMO_SCENE) as PackedScene

	var cells: Array[GridJsonIter.GridCell] = GridJsonIter.iter_items_by_id(grid, 4, cell_x, cell_z)
	for pickup_idx: int in range(cells.size()):
		var cell: GridJsonIter.GridCell = cells[pickup_idx]
		var yaw_deg: float = float((pickup_idx * 67 + 23) % 31) - 15.0

		var pickup: Node3D = packed.instantiate() as Node3D
		pickup.name = "AmmoCache%d" % pickup_idx
		# Place on top of raised platform surface.
		pickup.position = Vector3(cell.wx, PLATFORM_Y, cell.wz)
		pickup.rotation_degrees.y = yaw_deg
		scene_root.add_child(pickup)
		pickup.owner = scene_root
		_set_owner_recursive(pickup, scene_root)


## Recursively set owner on all children (required for PackedScene serialisation).
static func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
