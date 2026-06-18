# levels/wave_manager.gd — WaveManager: owns the live enemy set, escalating respawn, cap logic.
class_name WaveManager
extends Node

signal kills_changed(total: int)
signal active_changed(count: int)
signal score_changed(total: int)
signal run_won(score: int)
signal run_lost(score: int)
signal advance_level(score: int, lives: int)
signal lives_changed(remaining: int)

## Collision mask bit for the world/wall layer (layer 1 = bit 0).
const WALL_MASK: int = 1
## Eye height used for LOS raycasts to avoid floor collider hits.
const EYE_HEIGHT: float = 1.0

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
	var marker: Marker3D = _pick_spawn_marker(seed_phase)
	var pos: Vector3 = marker.global_position if marker != null else spawn_pos

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

	# Track occupied marker so the next call in the same batch avoids it.
	if marker != null:
		_occupied_markers.append(marker)

	_connect_enemy(enemy)
	_active_enemies.append(enemy)
	active_changed.emit(_active_enemies.size())


func _connect_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.touched_player.connect(_on_enemy_touched_player)


# ── Event handlers ────────────────────────────────────────────────────────────


func _on_enemy_died(enemy: Enemy) -> void:
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


func _on_enemy_touched_player(_enemy: Enemy) -> void:
	if _run_over:
		return

	print("WaveManager: touched — losing life")
	_lives -= 1
	lives_changed.emit(_lives)

	if _lives <= 0:
		_run_over = true
		# Free all live enemies before emitting run_lost.
		for e: Enemy in _active_enemies:
			if is_instance_valid(e):
				e.queue_free()
		_active_enemies.clear()
		_occupied_markers.clear()
		active_changed.emit(_active_enemies.size())
		run_lost.emit(_score)
		return

	# Lives remain — advance to the next level carrying the decremented lives + current score.
	_run_over = true
	for e: Enemy in _active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()
	_occupied_markers.clear()
	active_changed.emit(_active_enemies.size())
	advance_level.emit(_score, _lives)


# ── Spawn point selection ─────────────────────────────────────────────────────


## Returns the best available Marker3D for spawning, avoiding markers already used
## in the current batch (_occupied_markers). Falls back gracefully if all markers
## are occupied: clears the batch list and picks freely.
func _pick_spawn_marker(_seed_phase: bool) -> Marker3D:
	if _spawn_markers.is_empty():
		return _spawn_markers[0] if not _spawn_markers.is_empty() else null

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return _pick_unoccupied_random()

	var player_pos: Vector3 = player.global_position
	var ray_from: Vector3 = player_pos + Vector3(0.0, EYE_HEIGHT, 0.0)
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state

	# Separate markers into hidden/visible pools, both excluding already-occupied markers.
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

		# Skip markers already assigned in this spawn batch.
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
		# No hidden free markers — pick random visible-but-unoccupied.
		chosen = visible_free[randi() % visible_free.size()]
	else:
		# All markers occupied (batch larger than marker count): clear occupancy and
		# fall back to farthest so at least different positions are tried across calls.
		push_warning("WaveManager: all markers occupied — clearing batch list, using farthest")
		_occupied_markers.clear()
		chosen = farthest

	print(
		(
			"WaveManager: spawn pick — %d hidden_free / %d vis_free / %d occupied → %s"
			% [hidden_free.size(), visible_free.size(), _occupied_markers.size(), chosen.name]
		)
	)
	return chosen


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
