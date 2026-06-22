# levels/wave_manager.gd — WaveManager: owns the live enemy set, escalating respawn, cap logic.
class_name WaveManager
extends Node

signal kills_changed(total: int)
signal active_changed(count: int)
signal score_changed(total: int)
signal run_lost(score: int)
signal advance_level(score: int)

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

## Player spawn position for respawn. Default matches FiringYard.
@export var spawn_pos: Vector3 = Vector3(24.0, 1.0, 30.0)
## Player spawn rotation Y. Default matches FiringYard (facing −Z = PI).
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
## Optional sixth enemy type (Flying Stinger). Checked first in priority chain.
@export var enemy_scene_f: PackedScene
## Fraction of spawns that use enemy_scene_f (Flyer). 0.0 = none, 1.0 = all.
@export var flyer_ratio: float = 0.1
## Optional archetype-driven spawn slot A. When set, spawns the generic enemy_scene with
## this archetype assigned before add_child (alongside the existing PackedScene slots).
## Checked after PackedScene slots in the priority chain.
@export var spawn_archetype: EnemyArchetype
## Fraction of spawns that use spawn_archetype. 0.0 = none, 1.0 = all.
@export_range(0.0, 1.0, 0.05) var archetype_ratio: float = 0.0
## Optional archetype-driven spawn slot B (e.g. tank_magnet).
@export var spawn_archetype_b: EnemyArchetype
## Fraction of spawns that use spawn_archetype_b. 0.0 = none, 1.0 = all.
@export_range(0.0, 1.0, 0.05) var archetype_b_ratio: float = 0.0
## Optional archetype-driven spawn slot C (e.g. tank_shooter).
@export var spawn_archetype_c: EnemyArchetype
## Fraction of spawns that use spawn_archetype_c. 0.0 = none, 1.0 = all.
@export_range(0.0, 1.0, 0.05) var archetype_c_ratio: float = 0.0
## DEBUG: guarantee one Stinger on the Nth kill (1 = first kill, 0 = disabled).
@export var debug_flyer_on_kill: int = 0
## NodePaths to SpawnMarker* Marker3D nodes (children of WaveManager, resolved in _ready).
@export var spawn_marker_paths: Array[NodePath] = []
## NodePaths to patrol waypoints shared by all spawned enemies (resolved in _ready).
@export var patrol_waypoint_paths: Array[NodePath] = []
## How many enemies seed the run and re-seed after each reset.
@export var start_count: int = 2
## Maximum simultaneous active enemies; above this deaths respawn 1-for-1.
@export var active_cap: int = 30
## Score target required to win the run.
@export var win_score: int = 75
## Damage applied to player HP on each enemy touch.
@export_range(1, 100, 1) var touch_damage: int = 25

var _spawn_markers: Array[Marker3D] = []
var _patrol_waypoints: Array[Marker3D] = []
var _active_enemies: Array[Enemy] = []
var _kills: int = 0
var _score: int = 0
var _run_over: bool = false

# Tracks which markers are occupied by live spawned enemies (cleared when an enemy dies/frees).
var _occupied_markers: Array[Marker3D] = []
var _last_spawn_marker: Marker3D = null

# Reusable PhysicsRayQueryParameters3D allocated once, reused per LOS check.
var _ray_query: PhysicsRayQueryParameters3D

# Cached nav map RID for navmesh-snap of close-ring candidates.
var _nav_map: RID


func _ready() -> void:
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

	var nav_region: NavigationRegion3D = (
		get_tree().get_first_node_in_group("nav_region") as NavigationRegion3D
	)
	if nav_region == null:
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

	_seed_start.call_deferred()


func _seed_start() -> void:
	if RunStateData.active:
		_score = RunStateData.score
		RunStateData.active = false
	else:
		_score = 0
	_kills = 0
	_run_over = false
	_occupied_markers.clear()
	kills_changed.emit(_kills)
	score_changed.emit(_score)
	# Wire player HP → run_lost. Player must be in group "player".
	_wire_player_health()
	_spawn_one(true, false, true)
	for i: int in range(start_count - 1):
		_spawn_one(true, true)
	print("WaveManager: seeded %d enemies" % _active_enemies.size())
	active_changed.emit(_active_enemies.size())


## Connect player HealthComponent.died → _on_player_died so HP=0 ends the run.
func _wire_player_health() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not player.has_method("get_health_comp"):
		return
	# SEAM: duck-typed get_health_comp() — Player exposes this to avoid reaching into internals.
	# Return is Variant from duck call; cast to HealthComponent is safe by contract.
	@warning_ignore("unsafe_method_access")
	@warning_ignore("unsafe_cast")
	var hc: HealthComponent = player.get_health_comp() as HealthComponent
	if hc == null:
		return
	if not hc.died.is_connected(_on_player_died):
		hc.died.connect(_on_player_died)


# ── Spawn ─────────────────────────────────────────────────────────────────────


## Spawn one enemy.
func _spawn_one(
	seed_phase: bool = false,
	force_grunt: bool = false,
	force_magnet: bool = false,
	force_flyer: bool = false
) -> void:
	if enemy_scene == null:
		return
	var pos: Vector3 = _pick_spawn_point(seed_phase)

	var chosen_scene: PackedScene = enemy_scene
	var chosen_archetype: EnemyArchetype = null
	if force_flyer and enemy_scene_f != null:
		chosen_scene = enemy_scene_f
	elif force_magnet and enemy_scene_d != null:
		chosen_scene = enemy_scene_d
	elif not force_grunt:
		var roll: float = randf()
		if enemy_scene_f != null and roll < flyer_ratio:
			chosen_scene = enemy_scene_f
		elif enemy_scene_e != null and roll < flyer_ratio + shooter_ratio:
			chosen_scene = enemy_scene_e
		elif enemy_scene_d != null and roll < flyer_ratio + shooter_ratio + magnet_ratio:
			chosen_scene = enemy_scene_d
		elif (
			enemy_scene_c != null and roll < flyer_ratio + shooter_ratio + magnet_ratio + tank_ratio
		):
			chosen_scene = enemy_scene_c
		elif (
			enemy_scene_b != null
			and roll < flyer_ratio + shooter_ratio + magnet_ratio + tank_ratio + runner_ratio
		):
			chosen_scene = enemy_scene_b
		elif (
			spawn_archetype != null
			and (
				roll
				< (
					flyer_ratio
					+ shooter_ratio
					+ magnet_ratio
					+ tank_ratio
					+ runner_ratio
					+ archetype_ratio
				)
			)
		):
			# Archetype slot: use generic enemy_scene with archetype assigned.
			chosen_scene = enemy_scene
			chosen_archetype = spawn_archetype

	var inst: Node = chosen_scene.instantiate()
	if not inst is Enemy:
		push_error("WaveManager: enemy_scene root is not an Enemy")
		inst.queue_free()
		return

	var enemy: Enemy = inst as Enemy
	# Assign archetype before add_child so _ready() can seed stats from it.
	if chosen_archetype != null:
		enemy.archetype = chosen_archetype
	var relative_paths: Array[NodePath] = []
	for wp: Marker3D in _patrol_waypoints:
		relative_paths.append(NodePath(wp.get_path()))
	enemy.patrol_waypoint_paths = relative_paths

	enemy.collision_layer = 8
	enemy.collision_mask = 1

	get_parent().add_child(enemy)
	enemy.global_position = pos + Vector3(0.0, 0.1, 0.0)
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


func _on_player_died() -> void:
	if _run_over:
		return
	_run_over = true
	for e: Enemy in _active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()
	_occupied_markers.clear()
	active_changed.emit(_active_enemies.size())
	run_lost.emit(_score)


func _on_enemy_died(enemy: Enemy) -> void:
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
		advance_level.emit(_score)
		return

	var force_flyer_now: bool = (
		debug_flyer_on_kill > 0 and _kills == debug_flyer_on_kill and enemy_scene_f != null
	)

	if count_after < active_cap:
		_spawn_one(false, false, false, force_flyer_now)
		_spawn_one(false, false)
	else:
		_spawn_one(false, false, false, force_flyer_now)

	print("WaveManager: active after respawn %d" % _active_enemies.size())


func _on_enemy_touched_player(_enemy: Enemy) -> void:
	if _run_over:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not player.has_method("apply_damage"):
		return
	# SEAM: duck-typed apply_damage — any node with apply_damage(int) accepted.
	@warning_ignore("unsafe_method_access")
	player.apply_damage(touch_damage)


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


func _pick_spawn_point(seed_phase: bool) -> Vector3:
	if _spawn_markers.is_empty():
		return spawn_pos

	if not seed_phase and randf() < CLOSE_FRACTION:
		var close_pos: Vector3 = _try_close_ring_point()
		if close_pos != Vector3.ZERO:
			print("WaveManager: CLOSE spawn at %s" % close_pos)
			return close_pos

	return _pick_far_marker_pos()


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


func _try_close_ring_point() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.ZERO

	var player_pos: Vector3 = player.global_position
	var facing_y: float = player.rotation.y
	var half_cone: float = deg_to_rad(FRONT_CONE_DEG * 0.5)

	for _i: int in range(CLOSE_RETRIES):
		var arc_span: float = TAU - deg_to_rad(FRONT_CONE_DEG)
		var angle: float = facing_y + half_cone + randf() * arc_span

		var radius: float = CLOSE_MIN + randf() * (CLOSE_MAX - CLOSE_MIN)
		var offset: Vector3 = Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		var candidate: Vector3 = player_pos + offset
		candidate.y = 0.5

		var snapped_pos: Vector3 = _nav_snap(candidate)
		if snapped_pos == Vector3.ZERO:
			continue
		var xz_dist: float = (
			Vector2(snapped_pos.x - candidate.x, snapped_pos.z - candidate.z).length()
		)
		if xz_dist <= NAV_SNAP_TOLERANCE:
			if player_pos.distance_to(snapped_pos) >= CLOSE_MIN:
				return snapped_pos

	return Vector3.ZERO


func _nav_snap(pos: Vector3) -> Vector3:
	if not _nav_map.is_valid():
		var nav_region: NavigationRegion3D = _find_nav_region()
		if nav_region != null:
			_nav_map = nav_region.get_navigation_map()
		if not _nav_map.is_valid():
			return Vector3.ZERO
	return NavigationServer3D.map_get_closest_point(_nav_map, pos)


func _find_nav_region() -> NavigationRegion3D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is NavigationRegion3D:
			return child as NavigationRegion3D
	return null


func _pick_unoccupied_random() -> Marker3D:
	var free_markers: Array[Marker3D] = []
	for m: Marker3D in _spawn_markers:
		if not _occupied_markers.has(m):
			free_markers.append(m)
	if free_markers.is_empty():
		_occupied_markers.clear()
		return _spawn_markers[randi() % _spawn_markers.size()]
	return free_markers[randi() % free_markers.size()]
