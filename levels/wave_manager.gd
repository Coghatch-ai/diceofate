# levels/wave_manager.gd — WaveManager: owns the live enemy set, escalating respawn, cap logic.
class_name WaveManager
extends Node

## Collision mask bit for the world/wall layer (layer 1 = bit 0).
const WALL_MASK: int = 1
## Player spawn position — mirrors FiringYard.SPAWN_POS (same arena, sibling nodes).
const SPAWN_POS: Vector3 = Vector3(24.0, 1.0, 30.0)
## Player spawn facing −Z = rotation_y of PI.
const SPAWN_ROT_Y: float = PI

## Close-ring spawn: minimum distance from player (metres).
const CLOSE_MIN: float = 6.0
## Close-ring spawn: maximum distance from player (metres).
const CLOSE_MAX: float = 12.0
## Fraction of non-seed spawns that use the close-ring method (~40%).
const CLOSE_FRACTION: float = 0.4
## Half-angle of the front cone (degrees). Angles outside this are eligible for close spawn.
const FRONT_CONE_DEG: float = 90.0
## Maximum distance a navmesh-snapped point may deviate from the candidate (metres).
const NAV_SNAP_TOLERANCE: float = 1.5
## Max retries when a close-ring candidate fails navmesh validation before falling back to FAR.
const CLOSE_RETRIES: int = 6
## Eye height used for LOS raycasts to avoid floor collider hits.
const EYE_HEIGHT: float = 1.0

## Packed scene used to instance enemies at runtime.
@export var enemy_scene: PackedScene
## NodePaths to SpawnMarker* Marker3D nodes in the level (resolved in _ready).
@export var spawn_marker_paths: Array[NodePath] = []
## NodePaths to patrol waypoints shared by all spawned enemies (resolved in _ready).
@export var patrol_waypoint_paths: Array[NodePath] = []
## How many enemies seed the run.
@export var start_count: int = 2
## Maximum simultaneous active enemies; above this deaths respawn 1-for-1.
@export var active_cap: int = 30

var _spawn_markers: Array[Marker3D] = []
var _patrol_waypoints: Array[Marker3D] = []
var _active_enemies: Array[Enemy] = []

# Reusable PhysicsRayQueryParameters3D allocated once, reused per LOS check.
var _ray_query: PhysicsRayQueryParameters3D


func _ready() -> void:
	# Resolve NodePath exports → typed arrays (hand-authored .tscn can't store Array[Marker3D]).
	for np: NodePath in spawn_marker_paths:
		var node: Node = get_node(np)
		if node is Marker3D:
			_spawn_markers.append(node as Marker3D)
		else:
			push_warning("WaveManager: spawn marker '%s' is not a Marker3D" % np)
	for np: NodePath in patrol_waypoint_paths:
		var node: Node = get_node(np)
		if node is Marker3D:
			_patrol_waypoints.append(node as Marker3D)
		else:
			push_warning("WaveManager: patrol waypoint '%s' is not a Marker3D" % np)

	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = WALL_MASK

	if enemy_scene == null:
		push_error("WaveManager: enemy_scene not assigned")
		return
	if _spawn_markers.is_empty():
		push_error("WaveManager: no spawn markers resolved")
		return

	# Defer seeding: _ready runs while the parent tree is still setting up children,
	# so add_child() would fail. call_deferred waits for the frame to settle first.
	_seed_start.call_deferred()


func _seed_start() -> void:
	for i: int in range(start_count):
		_spawn_one(true)
	print("WaveManager: seeded %d enemies" % _active_enemies.size())


# ── Spawn ─────────────────────────────────────────────────────────────────────


func _spawn_one(seed_phase: bool = false) -> void:
	if enemy_scene == null:
		return
	var pos: Vector3 = _pick_spawn_point(seed_phase)

	var inst: Node = enemy_scene.instantiate()
	if not inst is Enemy:
		push_error("WaveManager: enemy_scene root is not an Enemy")
		inst.queue_free()
		return

	var enemy: Enemy = inst as Enemy
	# Set patrol waypoint NodePaths so the enemy resolves them in its own _ready().
	# Paths must be relative from the enemy's future position in the scene tree.
	# The enemy will be a child of our parent (the level root).
	var relative_paths: Array[NodePath] = []
	for wp: Marker3D in _patrol_waypoints:
		relative_paths.append(NodePath(wp.get_path()))
	enemy.patrol_waypoint_paths = relative_paths

	# Collision settings mirror the static EnemyA/EnemyB that were baked in the scene.
	enemy.collision_layer = 8
	enemy.collision_mask = 1

	# Add to the level root (sibling of WaveManager) so nav and collision work normally.
	# Position before add_child avoids an extra transform flush.
	get_parent().add_child(enemy)
	# global_position requires the node to be in the tree; set after add_child.
	enemy.global_position = pos + Vector3(0.0, 0.5, 0.0)

	_connect_enemy(enemy)
	_active_enemies.append(enemy)


func _connect_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.touched_player.connect(_on_enemy_touched_player)


# ── Event handlers ────────────────────────────────────────────────────────────


func _on_enemy_died(enemy: Enemy) -> void:
	_active_enemies.erase(enemy)
	var count_after: int = _active_enemies.size()
	print("WaveManager: enemy died — active now %d" % count_after)

	if count_after < active_cap:
		# Spawn 2: the respawn replacement + one net-new enemy.
		_spawn_one()
		_spawn_one()
	else:
		# At cap: 1-for-1 replacement only.
		_spawn_one()

	print("WaveManager: active after respawn %d" % _active_enemies.size())


func _on_enemy_touched_player(_enemy: Enemy) -> void:
	print("WaveManager: touched — resetting run")
	# Free all live enemies.
	for e: Enemy in _active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()
	# Re-seed start_count fresh enemies (seed phase = FAR only).
	for i: int in range(start_count):
		_spawn_one(true)
	print("WaveManager: reset — seeded %d enemies" % _active_enemies.size())
	# Teleport the player back to spawn facing −Z.
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		player.global_position = SPAWN_POS
		player.rotation.y = SPAWN_ROT_Y
		# SEAM: duck-typed reset — velocity is on CharacterBody3D, not the Node3D base type.
		@warning_ignore("unsafe_property_access")
		player.velocity = Vector3.ZERO


# ── Spawn point selection ─────────────────────────────────────────────────────


## Returns a world-space spawn position using the close-ring + far-marker hybrid.
## seed_phase == true → always FAR (out-of-sight authored marker).
## Otherwise rolls ~40% CLOSE (procedural ring behind player, navmesh-snapped)
## and ~60% FAR (authored perimeter marker, LOS-hidden).
func _pick_spawn_point(seed_phase: bool) -> Vector3:
	if seed_phase or randf() > CLOSE_FRACTION:
		return _pick_far_marker_pos()
	var close_pos: Vector3 = _pick_close_point()
	# _pick_close_point returns Vector3.ZERO on failure; fall back to FAR.
	if close_pos == Vector3.ZERO:
		return _pick_far_marker_pos()
	return close_pos


## Picks a perimeter authored marker that is out of sight of the player.
## Fallback (all visible) returns the farthest marker to avoid clustering.
func _pick_far_marker_pos() -> Vector3:
	if _spawn_markers.is_empty():
		return SPAWN_POS

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return _spawn_markers[randi() % _spawn_markers.size()].global_position

	var player_pos: Vector3 = player.global_position
	var ray_from: Vector3 = player_pos + Vector3(0.0, EYE_HEIGHT, 0.0)
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state

	var hidden: Array[Marker3D] = []
	var farthest: Marker3D = _spawn_markers[0]
	var farthest_dist: float = 0.0

	_ray_query.exclude = []
	for marker: Marker3D in _spawn_markers:
		var dist: float = player_pos.distance_to(marker.global_position)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = marker
		_ray_query.from = ray_from
		_ray_query.to = marker.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		var result: Dictionary = space.intersect_ray(_ray_query)
		if not result.is_empty():
			hidden.append(marker)

	var chosen: Marker3D
	if not hidden.is_empty():
		chosen = hidden[randi() % hidden.size()]
	else:
		# Fallback: every marker visible — pick farthest to reduce clustering.
		chosen = farthest
	print(
		(
			"WaveManager: FAR pick — %d hidden / %d total → %s"
			% [hidden.size(), _spawn_markers.size(), chosen.name]
		)
	)
	return chosen.global_position


## Samples a random point in the rear arc (outside the forward FRONT_CONE_DEG) at
## distance [CLOSE_MIN, CLOSE_MAX] from the player, snaps it to the navmesh, and
## validates it lands within NAV_SNAP_TOLERANCE of the candidate. Returns Vector3.ZERO
## on failure (caller falls back to FAR).
func _pick_close_point() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.ZERO

	var player_pos: Vector3 = player.global_position
	var facing_y: float = player.rotation.y

	# Rear arc: angles [half_cone, 2π - half_cone] offset from facing direction.
	# front_half is the half-angle of the forbidden front cone in radians.
	var front_half: float = deg_to_rad(FRONT_CONE_DEG * 0.5)

	# Get the navmesh map RID from the NavigationServer.
	var map_rid: RID = get_tree().root.get_world_3d().get_navigation_map()

	for _attempt: int in range(CLOSE_RETRIES):
		# Sample angle from the rear arc: exclude [facing - front_half, facing + front_half].
		# Rear arc spans 2π - FRONT_CONE_DEG. Bias uniformly within that arc.
		var rear_span: float = TAU - deg_to_rad(FRONT_CONE_DEG)
		var raw_angle: float = randf() * rear_span
		# Shift to start just past the front-right edge of the forbidden cone.
		var angle: float = facing_y + front_half + raw_angle

		var radius: float = randf_range(CLOSE_MIN, CLOSE_MAX)
		var candidate: Vector3 = player_pos + Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)

		var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(map_rid, candidate)
		if nav_point.distance_to(candidate) <= NAV_SNAP_TOLERANCE:
			print(
				(
					"WaveManager: CLOSE pick — radius %.1f angle %.1f → nav OK"
					% [radius, rad_to_deg(angle)]
				)
			)
			return nav_point

	# All retries exhausted.
	push_warning("WaveManager: close-ring retries exhausted — falling back to FAR")
	return Vector3.ZERO
