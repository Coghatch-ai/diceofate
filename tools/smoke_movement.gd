# tools/smoke_movement.gd — headless L2.5 smoke: assert entity moves toward a nav target.
# Boots levels/iron_floor.tscn (real floor + baked 494-poly navmesh) so CharacterBody3D
# can move_and_slide() and NavigationAgent3D can compute real paths.
# Spawns an extra enemy at a fixed position, lets it nav toward the existing Player node.
# HONEST TEST: fails when enemy doesn't move (broken nav agent, frozen AI).
#
# Default invocation:
#   $GODOT --headless --path . --script tools/smoke_movement.gd
#   (no args needed — defaults use iron_floor.tscn + known spawn/target coords)
#
# Args (after --):
#   <entity_scene>  res://-relative path (default: entities/enemy/enemy.tscn)
#   <spawn_pos>     "X,Y,Z" enemy spawn position (default: "13,0,19" = Spawn_R2_b)
#   <sample_frames> record every N physics frames (default: 10)
#   <min_disp>      metres entity must travel in total XZ (default: 1.0)
#   [max_frames]    total physics frames to run (default: 300 ~ 5 s at 60 Hz)
#
# Exit 0 = displaced >= min_disp, exit 1 = not (enemy frozen).
# See library/tools/game-observe.md for rationale.
extends SceneTree

const _LEVEL_SCENE: String = "res://levels/iron_floor.tscn"
const _DEFAULT_ENTITY: String = "entities/enemy/enemy.tscn"
const _DEFAULT_SPAWN: String = "13,0,19"
const _DEFAULT_MAX_FRAMES: int = 300
const _DEFAULT_SAMPLE_FRAMES: int = 10
const _DEFAULT_MIN_DISP: float = 1.0

var _entity_scene_path: String = _DEFAULT_ENTITY
var _spawn_pos: Vector3 = Vector3(13.0, 0.0, 19.0)
var _sample_frames: int = _DEFAULT_SAMPLE_FRAMES
var _min_disp: float = _DEFAULT_MIN_DISP
var _max_frames: int = _DEFAULT_MAX_FRAMES

var _frame: int = 0
var _entity: Node3D = null
var _level_root: Node = null
# Start position captured at frame 2 after physics syncs the spawned entity position.
var _start_pos: Vector3 = Vector3.ZERO
var _last_sampled_pos: Vector3 = Vector3.ZERO
# XZ-only displacement — confirms nav pathing, not gravity fall.
var _xz_displacement: float = 0.0
var _done: bool = false
# Whether the enemy + waypoint have been spawned (deferred to frame 3 so all _ready()s fire).
var _spawned: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] != "":
		_entity_scene_path = args[0]
	if args.size() >= 2 and args[1] != "":
		_spawn_pos = _parse_vec3(args[1])
	if args.size() >= 3 and args[2] != "":
		_sample_frames = int(args[2])
	if args.size() >= 4 and args[3] != "":
		_min_disp = float(args[3])
	if args.size() >= 5 and args[4] != "":
		_max_frames = int(args[4])

	print("=== SMOKE MOVEMENT: %s ===" % _entity_scene_path)
	print(
		(
			"  level=%s spawn=%s sample_every=%d min_disp=%.2fm max_frames=%d"
			% [_LEVEL_SCENE, str(_spawn_pos), _sample_frames, _min_disp, _max_frames]
		)
	)

	# Boot iron_floor.tscn — provides the real floor + baked navmesh.
	if not ResourceLoader.exists(_LEVEL_SCENE):
		print("MOVEMENT: FAIL — level scene not found: %s" % _LEVEL_SCENE)
		quit(1)
		return
	var level_packed: PackedScene = load(_LEVEL_SCENE) as PackedScene
	if level_packed == null:
		print("MOVEMENT: FAIL — could not load level: %s" % _LEVEL_SCENE)
		quit(1)
		return
	_level_root = level_packed.instantiate()
	root.add_child(_level_root)
	print(
		(
			"  level loaded: %s (player group resolved after _ready — spawning enemy at frame 3)"
			% _LEVEL_SCENE
		)
	)


func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1

	# Defer enemy spawn to frame 3 so all _ready()s in the level fire first
	# (Player adds itself to "player" group in _ready, which runs the frame after add_child).
	if not _spawned and _frame == 3:
		_spawn_enemy()

	if not _spawned:
		return false

	# Capture start position at frame 5 after physics syncs the spawned entity position.
	if _frame == 5 and _entity != null:
		_start_pos = _entity.global_position
		_last_sampled_pos = _start_pos
		print("MOVEMENT: frame=5 pos=%s (start — physics synced)" % str(_start_pos))

	# Sample XZ position at each interval (Y excluded — gravity fall is not nav movement).
	var sample_origin: int = 5
	if _entity != null and _frame >= sample_origin + _sample_frames:
		var rel: int = _frame - sample_origin
		if rel % _sample_frames == 0:
			var cur_pos: Vector3 = _entity.global_position
			var cur_xz: Vector2 = Vector2(cur_pos.x, cur_pos.z)
			var last_xz: Vector2 = Vector2(_last_sampled_pos.x, _last_sampled_pos.z)
			var step_xz: float = last_xz.distance_to(cur_xz)
			_xz_displacement += step_xz
			_last_sampled_pos = cur_pos
			print(
				(
					"MOVEMENT: frame=%d pos=%s (step_xz=%.3fm total_xz=%.3fm)"
					% [_frame, str(cur_pos), step_xz, _xz_displacement]
				)
			)

	if _frame >= _max_frames:
		_done = true
		_finish()

	return false


func _spawn_enemy() -> void:
	# Confirm player node exists (target for nav agent).
	var player_node: Node = get_first_node_in_group("player")
	if player_node == null:
		print(
			"MOVEMENT: FAIL — no node in 'player' group after level _ready(); check Player._ready()"
		)
		quit(1)
		return
	var player3d: Node3D = player_node as Node3D
	if player3d == null:
		print("MOVEMENT: FAIL — player node is not a Node3D")
		quit(1)
		return
	print("  player found: %s pos=%s" % [player_node.name, str(player3d.global_position)])

	# Spawn enemy entity at the given spawn position (must be on the navmesh).
	var res_path: String = "res://" + _entity_scene_path
	if not ResourceLoader.exists(res_path):
		print("MOVEMENT: FAIL — entity scene not found: %s" % res_path)
		quit(1)
		return
	var packed: PackedScene = load(res_path) as PackedScene
	if packed == null:
		print("MOVEMENT: FAIL — could not load entity: %s" % res_path)
		quit(1)
		return
	_entity = packed.instantiate() as Node3D
	if _entity == null:
		print("MOVEMENT: FAIL — entity root is not Node3D: %s" % res_path)
		quit(1)
		return
	_level_root.add_child(_entity)
	_entity.position = _spawn_pos
	print("  enemy spawned at %s" % str(_spawn_pos))

	# Inject a patrol waypoint pointing at the player so PatrolState immediately navigates.
	var waypoint: Marker3D = Marker3D.new()
	waypoint.name = "SmokeWaypoint"
	_level_root.add_child(waypoint)
	waypoint.position = player3d.position
	# SEAM: _entity typed as Node3D; patrol_waypoints is Array[Marker3D] on Enemy.
	if _entity.get("patrol_waypoints") != null:
		@warning_ignore("unsafe_method_access")
		_entity.get("patrol_waypoints").append(waypoint)
		print("  waypoint injected at %s" % str(waypoint.position))
	else:
		print("  WARNING: entity has no patrol_waypoints — AI may not nav")

	_spawned = true
	print("  enemy ready — sampling XZ displacement for %d frames" % (_max_frames - _frame))


func _finish() -> void:
	var final_pos: Vector3 = Vector3.ZERO
	if _entity != null:
		final_pos = _entity.global_position

	print(
		(
			"MOVEMENT: summary — start=%s end=%s xz_disp=%.3fm min=%.2fm frames=%d"
			% [str(_start_pos), str(final_pos), _xz_displacement, _min_disp, _max_frames]
		)
	)

	if _xz_displacement >= _min_disp:
		print(
			(
				"MOVEMENT: OK — %s moved %.3fm XZ in %d frames (min=%.2fm)"
				% [_entity_scene_path, _xz_displacement, _max_frames, _min_disp]
			)
		)
		quit(0)
	else:
		var msg: String = (
			"MOVEMENT: FAIL — %s moved %.3fm XZ in %d frames (min=%.2fm) — NavAgent not pathing or AI frozen"
			% [_entity_scene_path, _xz_displacement, _max_frames, _min_disp]
		)
		print(msg)
		quit(1)


func _parse_vec3(s: String) -> Vector3:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 3:
		return Vector3(13.0, 0.0, 19.0)
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
