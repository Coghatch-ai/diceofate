# levels/wave_manager.gd — WaveManager: owns the live enemy set, escalating respawn, cap logic.
class_name WaveManager
extends Node

signal kills_changed(total: int)
signal active_changed(count: int)
signal score_changed(total: int)
signal run_lost(score: int)
signal advance_level(score: int, lives: int)
signal lives_changed(remaining: int)
## Emitted when the player loses a life but the run continues (remaining > 0).
## Connect to ArenaHud.flash_life_lost() in main.gd.
signal life_lost

## Collision mask bit for the world/wall layer (layer 1 = bit 0).
const WALL_MASK: int = 1
## Eye height used for LOS raycasts to avoid floor collider hits.
const EYE_HEIGHT: float = 1.0

## Close-ring spawn tunables (design doc constants).
const CLOSE_MIN: float = 6.0
const CLOSE_MAX: float = 12.0
const CLOSE_FRACTION: float = 0.4
const FRONT_CONE_DEG: float = 90.0
const NAV_SNAP_TOLERANCE: float = 1.5
const CLOSE_RETRIES: int = 6

## Player spawn position for life-loss respawn. Set per-level by the builder or scene.
## Default matches FiringYard so that scene requires no override.
@export var spawn_pos: Vector3 = Vector3(24.0, 1.0, 30.0)
## Player spawn rotation Y for life-loss respawn. Default matches FiringYard (facing −Z = PI).
@export var spawn_rot_y: float = PI
## Packed scene used to instance enemies at runtime.
@export var enemy_scene: PackedScene
## Optional second enemy type (Runner). If null, all spawns use enemy_scene.
@export var enemy_scene_b: PackedScene
## Fraction of spawns that use enemy_scene_b (Runner). 0.0 = none, 1.0 = all.
@export var runner_ratio: float = 0.3
## Optional third enemy type (Tank). Checked before runner roll.
@export var enemy_scene_c: PackedScene
## Fraction of spawns that use enemy_scene_c (Tank). 0.0 = none, 1.0 = all.
@export var tank_ratio: float = 0.2
## Optional fourth enemy type (Magnetic). Checked before tank roll.
@export var enemy_scene_d: PackedScene
## Fraction of spawns that use enemy_scene_d (Magnetic). 0.0 = none, 1.0 = all.
@export var magnet_ratio: float = 0.1
## Optional fifth enemy type (Shooter). Checked before magnet roll.
@export var enemy_scene_e: PackedScene
## Fraction of spawns that use enemy_scene_e (Shooter). 0.0 = none, 1.0 = all.
@export var shooter_ratio: float = 0.1
## NodePaths to SpawnMarker* Marker3D nodes (children of WaveManager, resolved in _ready).
@export var spawn_marker_paths: Array[NodePath] = []
## NodePaths to patrol waypoints shared by all spawned enemies (resolved in _ready).
@export var patrol_waypoint_paths: Array[NodePath] = []
## How many enemies seed the run and re-seed after each reset.
@export var start_count: int = 2
## Maximum simultaneous active enemies; above this deaths respawn 1-for-1.
@export var active_cap: int = 30
## Score target required to win the run (replaces flat kill count from G2).
## With grunt=1/runner=2/magnet=4/tank=5 and mixed spawns, ~75 pts ≈ 2–4 min.
@export var win_score: int = 75
## Lives the player starts with; depleted by enemy touches.
@export var lives: int = 3

var _spawn_markers: Array[Marker3D] = []
var _patrol_waypoints: Array[Marker3D] = []
var _active_enemies: Array[Enemy] = []
var _kills: int = 0
var _score: int = 0
var _lives: int = 0
var _run_over: bool = false

# Tracks which markers are occupied by live spawned enemies (cleared when an enemy dies/frees).
# Used to avoid placing two enemies on the same marker within one spawn batch.
var _occupied_markers: Array[Marker3D] = []
# Last marker chosen by _pick_far_marker_pos; tagged onto the spawned enemy for death cleanup.
var _last_spawn_marker: Marker3D = null

# Reusable PhysicsRayQueryParameters3D allocated once, reused per LOS check.
var _ray_query: PhysicsRayQueryParameters3D

# Cached nav map RID for navmesh-snap of close-ring candidates.
# Populated in _ready() once NavigationRegion3D is available in the tree.
var _nav_map: RID


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

	# Cache the nav map RID from the first NavigationRegion3D in the parent scene.
	var nav_region: NavigationRegion3D = (
		get_tree().get_first_node_in_group("nav_region") as NavigationRegion3D
	)
	if nav_region == null:
		# Fallback: search parent for any NavigationRegion3D child.
		nav_region = _find_nav_region()
	if nav_region != null:
		_nav_map = nav_region.get_navigation_map()
	else:
		push_warning("WaveManager: no NavigationRegion3D found — close-ring will fall back to FAR")

	if enemy_scene == null:
		push_error("WaveManager: enemy_scene not assigned")
		return
	if _spawn_markers.is_empty():
		push_error("WaveManager: no spawn markers resolved")
		return

	# Defer seeding: _ready runs while the parent tree is still setting up children,
	# so add_child() would fail. call_deferred waits for the frame to settle first.
	_seed_start.call_deferred()


## Adds one life up to the cap (lives export). Returns false (no-op) if already at cap.
func add_life() -> bool:
	if _lives >= lives:
		return false
	_lives += 1
	lives_changed.emit(_lives)
	return true


func _seed_start() -> void:
	if RunStateData.active:
		_lives = RunStateData.lives
		_score = RunStateData.score
		RunStateData.active = false
	else:
		_lives = lives
		_score = 0
	_kills = 0
	_run_over = false
	_occupied_markers.clear()
	lives_changed.emit(_lives)
	kills_changed.emit(_kills)
	score_changed.emit(_score)
	# SEED RULE: first enemy is always a magnet (cyan) for quick melee testing; remaining are grunts.
	# Per-kill escalation respawns use the random type roll (see _spawn_one force_grunt=false).
	_spawn_one(true, false, true)
	for i: int in range(start_count - 1):
		_spawn_one(true, true)
	print("WaveManager: seeded %d enemies" % _active_enemies.size())
	active_changed.emit(_active_enemies.size())


# ── Spawn ─────────────────────────────────────────────────────────────────────


## Spawn one enemy.
## seed_phase: passed to _pick_spawn_point for LOS exclusion semantics (same logic both paths).
## force_grunt: when true, always uses enemy_scene (base grunt) regardless of ratios.
##   Seeds and re-seeds use force_grunt=true for deterministic grunt opening waves.
##   Per-kill escalation respawns use force_grunt=false for the random type mix.
## force_magnet: when true, always uses enemy_scene_d (magnet/cyan) — used for first seed slot.
func _spawn_one(
	seed_phase: bool = false, force_grunt: bool = false, force_magnet: bool = false
) -> void:
	if enemy_scene == null:
		return
	var pos: Vector3 = _pick_spawn_point(seed_phase)

	# Type selection priority: force_magnet > force_grunt > random roll by ratios.
	var chosen_scene: PackedScene = enemy_scene
	if force_magnet and enemy_scene_d != null:
		chosen_scene = enemy_scene_d
	elif not force_grunt:
		var roll: float = randf()
		if enemy_scene_e != null and roll < shooter_ratio:
			chosen_scene = enemy_scene_e
		elif enemy_scene_d != null and roll < shooter_ratio + magnet_ratio:
			chosen_scene = enemy_scene_d
		elif enemy_scene_c != null and roll < shooter_ratio + magnet_ratio + tank_ratio:
			chosen_scene = enemy_scene_c
		elif (
			enemy_scene_b != null
			and roll < shooter_ratio + magnet_ratio + tank_ratio + runner_ratio
		):
			chosen_scene = enemy_scene_b

	var inst: Node = chosen_scene.instantiate()
	if not inst is Enemy:
		push_error("WaveManager: enemy_scene root is not an Enemy")
		inst.queue_free()
		return

	var enemy: Enemy = inst as Enemy
	# Set patrol waypoint NodePaths so the enemy resolves them in its own _ready().
	# Paths must be absolute from the scene tree root so they resolve from the enemy's
	# future parent (the level root, sibling of WaveManager).
	var relative_paths: Array[NodePath] = []
	for wp: Marker3D in _patrol_waypoints:
		relative_paths.append(NodePath(wp.get_path()))
	enemy.patrol_waypoint_paths = relative_paths

	# Collision settings mirror the original baked enemies.
	enemy.collision_layer = 8
	enemy.collision_mask = 1

	# Add to the level root (sibling of WaveManager) so nav and collision work normally.
	get_parent().add_child(enemy)
	# global_position requires the node to be in the tree; set after add_child.
	enemy.global_position = pos + Vector3(0.0, 0.1, 0.0)
	# Tag the marker used so _on_enemy_died can release it from _occupied_markers.
	if _last_spawn_marker != null:
		enemy.set_meta("spawn_marker", _last_spawn_marker)
	_last_spawn_marker = null

	_connect_enemy(enemy)
	_active_enemies.append(enemy)
	active_changed.emit(_active_enemies.size())


func _connect_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.touched_player.connect(_on_enemy_touched_player)
	enemy.bumped_player.connect(_on_enemy_bumped_player)


# ── Event handlers ────────────────────────────────────────────────────────────


func _on_enemy_died(enemy: Enemy) -> void:
	# Release any marker this enemy occupied so future spawns can reuse it.
	if enemy.has_meta("spawn_marker"):
		# SEAM: meta value is Marker3D by construction (set in _spawn_one).
		@warning_ignore("unsafe_cast")
		var m: Marker3D = enemy.get_meta("spawn_marker") as Marker3D
		_occupied_markers.erase(m)
	if _run_over:
		_active_enemies.erase(enemy)
		active_changed.emit(_active_enemies.size())
		return

	_active_enemies.erase(enemy)
	_kills += 1
	_score += enemy.score_value
	kills_changed.emit(_kills)
	score_changed.emit(_score)
	active_changed.emit(_active_enemies.size())
	var count_after: int = _active_enemies.size()
	print(
		(
			"WaveManager: enemy died — active now %d, kills %d, score %d"
			% [count_after, _kills, _score]
		)
	)

	if _score >= win_score:
		_run_over = true
		advance_level.emit(_score, _lives)
		return

	if count_after < active_cap:
		# Spawn 2: the respawn replacement + one net-new enemy. Both are ESCALATION spawns
		# (random type mix). Only the initial seed and re-seeds use force_grunt.
		_spawn_one(false, false)
		_spawn_one(false, false)
	else:
		# At cap: 1-for-1 replacement only.
		_spawn_one(false, false)

	print("WaveManager: active after respawn %d" % _active_enemies.size())


## Shared life-loss entry point — decrement, emit signals, re-seed or end run.
## Call from enemy touches AND fall/hazard resets so all life-loss routes are unified.
func lose_life() -> void:
	if _run_over:
		return

	print("WaveManager: lose_life — lives before: %d" % _lives)
	_lives -= 1
	lives_changed.emit(_lives)

	if _lives <= 0:
		_run_over = true
		for e: Enemy in _active_enemies:
			if is_instance_valid(e):
				e.queue_free()
		_active_enemies.clear()
		_occupied_markers.clear()
		active_changed.emit(_active_enemies.size())
		run_lost.emit(_score)
		return

	# Lives remain — flash, clear enemies, advance to re-seed.
	life_lost.emit()
	_run_over = true
	for e: Enemy in _active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()
	_occupied_markers.clear()
	active_changed.emit(_active_enemies.size())
	advance_level.emit(_score, _lives)


func _on_enemy_touched_player(_enemy: Enemy) -> void:
	lose_life()


func _on_enemy_bumped_player(enemy: Enemy) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not player.has_method("apply_knockback"):
		return
	# SEAM: duck-typed apply_knockback seam — any node with apply_knockback(Vector3) accepted.
	@warning_ignore("unsafe_method_access")
	player.apply_knockback(enemy.global_position)


# ── Spawn point selection ─────────────────────────────────────────────────────


## Returns a world-space spawn position. seed_phase=true always picks a FAR marker
## (out-of-sight, or farthest fallback). Otherwise rolls CLOSE_FRACTION chance for a
## procedural close-ring point behind the player; falls back to FAR on nav-snap failure.
func _pick_spawn_point(seed_phase: bool) -> Vector3:
	if _spawn_markers.is_empty():
		return spawn_pos

	if not seed_phase and randf() < CLOSE_FRACTION:
		var close_pos: Vector3 = _try_close_ring_point()
		if close_pos != Vector3.ZERO:
			print("WaveManager: CLOSE spawn at %s" % close_pos)
			return close_pos

	return _pick_far_marker_pos()


## Pick a FAR marker: prefer out-of-sight + unoccupied; fallback = farthest marker.
func _pick_far_marker_pos() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return _pick_unoccupied_random().global_position

	var player_pos: Vector3 = player.global_position
	var ray_from: Vector3 = player_pos + Vector3(0.0, EYE_HEIGHT, 0.0)
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state

	var hidden_free: Array[Marker3D] = []
	var visible_free: Array[Marker3D] = []
	var farthest: Marker3D = _spawn_markers[0]
	var farthest_dist: float = 0.0

	_ray_query.exclude = []
	for marker: Marker3D in _spawn_markers:
		var dist: float = player_pos.distance_to(marker.global_position)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = marker

		if _occupied_markers.has(marker):
			continue

		_ray_query.from = ray_from
		_ray_query.to = marker.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
		var result: Dictionary = space.intersect_ray(_ray_query)
		if not result.is_empty():
			hidden_free.append(marker)
		else:
			visible_free.append(marker)

	var chosen: Marker3D
	if not hidden_free.is_empty():
		chosen = hidden_free[randi() % hidden_free.size()]
	elif not visible_free.is_empty():
		chosen = visible_free[randi() % visible_free.size()]
	else:
		push_warning("WaveManager: all markers occupied — clearing batch list, using farthest")
		_occupied_markers.clear()
		chosen = farthest

	_occupied_markers.append(chosen)
	_last_spawn_marker = chosen
	print(
		(
			"WaveManager: FAR spawn pick — %d hidden_free / %d vis_free / %d occupied → %s"
			% [hidden_free.size(), visible_free.size(), _occupied_markers.size(), chosen.name]
		)
	)
	return chosen.global_position


## Attempt to pick a navmesh-valid point on the close ring behind the player.
## Returns Vector3.ZERO if all retries fail (caller falls back to FAR).
func _try_close_ring_point() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.ZERO

	var player_pos: Vector3 = player.global_position
	# Player forward in XZ: rotation.y is the yaw; forward = -Z rotated by yaw.
	var facing_y: float = player.rotation.y
	# Rear arc: angles where the candidate falls OUTSIDE the front ±45° cone.
	# We bias toward the rear half by sampling in [front+45°, front+315°] range
	# (i.e. 270° of the rear+side arc), with equal probability across that range.
	var half_cone: float = deg_to_rad(FRONT_CONE_DEG * 0.5)

	for _i: int in range(CLOSE_RETRIES):
		# Sample angle in rear 270° arc (exclude front 90° cone).
		# rear arc = [facing_y + half_cone, facing_y + 2PI - half_cone]
		# arc_span = 2PI - FRONT_CONE_DEG_rad
		var arc_span: float = TAU - deg_to_rad(FRONT_CONE_DEG)
		var angle: float = facing_y + half_cone + randf() * arc_span

		var radius: float = CLOSE_MIN + randf() * (CLOSE_MAX - CLOSE_MIN)
		var offset: Vector3 = Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		var candidate: Vector3 = player_pos + offset
		# Keep candidate at floor height (y=0 on navmesh; enemy spawns +0.1 above).
		candidate.y = 0.5

		var snapped_pos: Vector3 = _nav_snap(candidate)
		if snapped_pos == Vector3.ZERO:
			continue
		# Accept if snapped point is within tolerance of candidate (XZ only).
		var xz_dist: float = (
			Vector2(snapped_pos.x - candidate.x, snapped_pos.z - candidate.z).length()
		)
		if xz_dist <= NAV_SNAP_TOLERANCE:
			# Also verify minimum distance from player to prevent spawning on top of them.
			if player_pos.distance_to(snapped_pos) >= CLOSE_MIN:
				return snapped_pos

	return Vector3.ZERO


## Snap a world position to the navmesh. Returns Vector3.ZERO if nav map not ready.
func _nav_snap(pos: Vector3) -> Vector3:
	if not _nav_map.is_valid():
		# Try to re-acquire on demand (map may not have been ready at _ready time).
		var nav_region: NavigationRegion3D = _find_nav_region()
		if nav_region != null:
			_nav_map = nav_region.get_navigation_map()
		if not _nav_map.is_valid():
			return Vector3.ZERO
	return NavigationServer3D.map_get_closest_point(_nav_map, pos)


## Walk the parent scene tree to find the first NavigationRegion3D child.
func _find_nav_region() -> NavigationRegion3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is NavigationRegion3D:
			return child as NavigationRegion3D
	return null


## Pick a random unoccupied marker (no-player fallback path).
func _pick_unoccupied_random() -> Marker3D:
	var free_markers: Array[Marker3D] = []
	for m: Marker3D in _spawn_markers:
		if not _occupied_markers.has(m):
			free_markers.append(m)
	if free_markers.is_empty():
		_occupied_markers.clear()
		return _spawn_markers[randi() % _spawn_markers.size()]
	return free_markers[randi() % free_markers.size()]
