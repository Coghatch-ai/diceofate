# tools/verify_enemy_ai.gd — headless behavioral check for B3 enemy AI in firing_yard.tscn.
# Usage: $GODOT --headless --path . --script tools/verify_enemy_ai.gd
# Prints PASS/FAIL per check. Exit 0 = all pass, Exit 1 = any fail.
# Does NOT require a display — all checks use physics, nav server, and FSM state reads.
#
# Headless caveats (noted per check):
# - CHECK 2: NavigationAgent3D.velocity_computed is async avoidance; confirmed enemy
#   receives valid next-path-position instead of checking body translation.
# - CHECK 3: EyeRay from enemy-eye-height to player-feet hits the floor on flat ground;
#   player is teleported to enemy-eye-height so LOS ray travels horizontally.
extends SceneTree

const SCENE_PATH: String = "res://levels/firing_yard.tscn"
# Frames to settle the scene (nav map, _ready callbacks, physics).
const SETTLE_FRAMES: int = 10
# After settling, re-trigger patrol to work around nav-target-lost-on-ready timing issue.
# Enemy's set_destination during _ready() is ignored if nav map not yet active on frame 0.
const PATROL_NAV_WAIT: int = 20
const CHASE_FRAMES: int = 60
const ATTACK_FRAMES: int = 30

var _scene_root: Node = null
var _frame: int = 0
var _phase: int = 0
var _fail_count: int = 0

var _enemy_a: Enemy = null
var _enemy_b: Enemy = null
var _player: Node3D = null


func _initialize() -> void:
	print("\n=== ENEMY AI HEADLESS VERIFY (B3) ===\n")
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("VERIFY: could not load %s" % SCENE_PATH)
		quit(1)
		return
	_scene_root = packed.instantiate()
	get_root().add_child(_scene_root)


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			# Settle — wait for _ready() chain, nav map registration, physics.
			if _frame >= SETTLE_FRAMES:
				_resolve_nodes()
				_phase = 1
				_frame = 0
		1:
			# CHECK 1 — navmesh non-empty + enemy spawn on nav surface.
			_check_navmesh()
			_phase = 2
			_frame = 0
		2:
			# CHECK 2 — patrol: re-trigger destination (nav-target-lost-on-ready), check path.
			if _frame == 1:
				_setup_patrol()
			if _frame >= PATROL_NAV_WAIT:
				_check_patrol()
				_phase = 3
				_frame = 0
		3:
			# CHECK 3 — chase: player at eye-height within detect range, assert FSM transitions.
			if _frame == 1:
				_setup_chase()
			if _frame >= CHASE_FRAMES:
				_check_chase()
				_phase = 4
				_frame = 0
		4:
			# CHECK 4 — attack: player inside attack_range, assert AttackState + timer.
			if _frame == 1:
				_setup_attack()
			if _frame >= ATTACK_FRAMES:
				_check_attack()
				_phase = 5
				_frame = 0
		5:
			# CHECK 5 — despawn: on_hit() frees one enemy; others + targets intact.
			_check_despawn()
			_phase = 6
		6:
			_finish()
			return true
	return false


# ── Node resolution ──────────────────────────────────────────────────────────


func _resolve_nodes() -> void:
	_enemy_a = _scene_root.get_node_or_null("EnemyA") as Enemy
	_enemy_b = _scene_root.get_node_or_null("EnemyB") as Enemy
	_player = _scene_root.get_node_or_null("Player") as Node3D
	if _enemy_a == null or _enemy_b == null:
		push_error("VERIFY: EnemyA or EnemyB not found — aborting")
		_fail_count += 2
		quit(1)
		return
	if _player == null:
		push_error("VERIFY: Player not found — aborting")
		_fail_count += 1
		quit(1)


# ── CHECK 1 — navmesh non-empty + enemy on nav surface ───────────────────────


func _check_navmesh() -> void:
	var nav_region: NavigationRegion3D = (
		_scene_root.get_node_or_null("NavFloor") as NavigationRegion3D
	)
	if nav_region == null or nav_region.navigation_mesh == null:
		_fail("CHECK 1 [Navmesh]", "NavFloor or NavigationMesh missing")
		return

	var verts: PackedVector3Array = nav_region.navigation_mesh.get_vertices()
	if verts.is_empty():
		_fail("CHECK 1 [Navmesh]", "NavigationMesh has 0 vertices (not baked)")
		return

	# Confirm enemy A is close to the nav surface (spawn on walkable floor).
	var map_rid: RID = _enemy_a.get_world_3d().navigation_map
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(
		map_rid, _enemy_a.global_position
	)
	var dist: float = _enemy_a.global_position.distance_to(closest)
	if dist > 2.0:
		_fail("CHECK 1 [Navmesh]", "EnemyA %.2f m from nav surface (>2 m — off navmesh)" % dist)
		return

	_pass("CHECK 1 [Navmesh]", "%d vertices; EnemyA %.2f m from nav surface" % [verts.size(), dist])


# ── CHECK 2 — patrol: nav agent gets a valid path ────────────────────────────


func _setup_patrol() -> void:
	# NavigationAgent3D.target_position set during _ready() may be dropped if the
	# nav map is not yet active on frame 0. Re-trigger after settle.
	# Ensure player is far (out of detect_range) so enemy stays in PatrolState.
	_player.global_position = Vector3(24.0, 1.0, 30.0)
	if _enemy_a.patrol_waypoints.size() > 0:
		_enemy_a.set_destination(_enemy_a.patrol_waypoints[0].global_position)


func _check_patrol() -> void:
	var nav: NavigationAgent3D = _enemy_a.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav == null:
		_fail("CHECK 2 [Patrol]", "NavigationAgent3D not found on EnemyA")
		return

	var sm: EnemyStateMachine = _enemy_a.get_node_or_null("StateMachine") as EnemyStateMachine
	if sm == null or sm.current_state == null:
		_fail("CHECK 2 [Patrol]", "StateMachine or current_state null")
		return

	var state_name: String = String(sm.current_state.name)
	var waypoints_ok: bool = _enemy_a.patrol_waypoints.size() == 3
	# After PATROL_NAV_WAIT frames the nav should have a path to the waypoint.
	# nav_fin=false means agent has a pending path to navigate.
	var has_path: bool = not nav.is_navigation_finished()
	# next_path_position is the immediate next point along the path (not destination).
	var next_pt: Vector3 = nav.get_next_path_position()
	var next_differs: bool = next_pt.distance_to(_enemy_a.global_position) > 0.3

	if not waypoints_ok:
		_fail(
			"CHECK 2 [Patrol]",
			"patrol_waypoints.size() = %d (expected 3)" % _enemy_a.patrol_waypoints.size()
		)
		return
	if state_name != "PatrolState":
		_fail("CHECK 2 [Patrol]", "FSM not in PatrolState (state='%s')" % state_name)
		return
	if not has_path:
		_fail(
			"CHECK 2 [Patrol]", "nav reports finished (no path to waypoint) — enemy would be stuck"
		)
		return
	if not next_differs:
		_fail(
			"CHECK 2 [Patrol]", "next_path_position coincides with enemy pos — path leads nowhere"
		)
		return

	_pass(
		"CHECK 2 [Patrol]",
		(
			"PatrolState; 3 waypoints; nav path active; next_pt %.2f m ahead"
			% next_pt.distance_to(_enemy_a.global_position)
		)
	)


# ── CHECK 3 — chase on sight ──────────────────────────────────────────────────


func _setup_chase() -> void:
	# Teleport player to EnemyA's eye height and in front of it — 6 m away, clear LOS.
	# EyeRay starts at (0, 1.5, 0) local. If player is at floor height (y=1), the ray
	# goes downward and may hit the floor. Teleport player to eye height for horizontal ray.
	var eye_y: float = _enemy_a.global_position.y + 1.5
	_player.global_position = Vector3(22.0, eye_y, 14.0)
	# Ensure lowercase player group (enemy.target() uses "player" group).
	if not _player.is_in_group("player"):
		_player.add_to_group("player")


func _check_chase() -> void:
	var sm: EnemyStateMachine = _enemy_a.get_node_or_null("StateMachine") as EnemyStateMachine
	if sm == null or sm.current_state == null:
		_fail("CHECK 3 [Chase]", "StateMachine or current_state null")
		return

	var state_name: String = String(sm.current_state.name)
	var dist: float = _enemy_a.distance_to_target()
	var can_see: bool = _enemy_a.can_see_target()
	# Accept Chase or Attack (enemy may have closed gap in 60 frames).
	var in_pursuit: bool = state_name in ["ChaseState", "AttackState"]
	if not in_pursuit:
		_fail(
			"CHECK 3 [Chase]",
			(
				"FSM still in '%s' after %d frames (dist=%.2f, can_see=%s)"
				% [state_name, CHASE_FRAMES, dist, str(can_see)]
			)
		)
		return

	_pass(
		"CHECK 3 [Chase]",
		"FSM in '%s' after %d frames (dist=%.2f)" % [state_name, CHASE_FRAMES, dist]
	)


# ── CHECK 4 — attack state + cooldown ────────────────────────────────────────


func _setup_attack() -> void:
	# Teleport player inside attack_range (1.8 m) of EnemyA.
	_player.global_position = _enemy_a.global_position + Vector3(0.0, 0.0, -1.5)


func _check_attack() -> void:
	var sm: EnemyStateMachine = _enemy_a.get_node_or_null("StateMachine") as EnemyStateMachine
	if sm == null or sm.current_state == null:
		_fail("CHECK 4 [Attack]", "StateMachine or current_state null")
		return

	var state_name: String = String(sm.current_state.name)
	if state_name != "AttackState":
		_fail(
			"CHECK 4 [Attack]",
			(
				"expected AttackState; got '%s' (dist=%.2f)"
				% [state_name, _enemy_a.distance_to_target()]
			)
		)
		return
	# attack_timer running = attack fired and cooldown is counting down.
	# After ATTACK_FRAMES (30 ≈ 0.5 s), attack_cooldown=0.8 s → timer still running.
	if _enemy_a.attack_timer.is_stopped():
		_fail(
			"CHECK 4 [Attack]",
			"AttackState active but attack_timer stopped — cooldown not respected or attack never fired"
		)
		return

	_pass(
		"CHECK 4 [Attack]",
		"AttackState; attack_timer running (cooldown %.1f s)" % _enemy_a.attack_cooldown
	)


# ── CHECK 5 — despawn: on_hit() frees enemy, others unaffected ───────────────


func _check_despawn() -> void:
	var target_a: Node = _scene_root.get_node_or_null("TargetA")
	var target_b: Node = _scene_root.get_node_or_null("TargetB")
	var enemy_b_ref: Enemy = _enemy_b

	if not is_instance_valid(_enemy_a):
		_fail("CHECK 5 [Despawn]", "EnemyA already invalid before on_hit() — prior phase freed it")
		return

	_enemy_a.on_hit()

	# queue_free() is deferred — is_queued_for_deletion() is immediate.
	var a_freed: bool = not is_instance_valid(_enemy_a) or _enemy_a.is_queued_for_deletion()
	var b_intact: bool = is_instance_valid(enemy_b_ref) and not enemy_b_ref.is_queued_for_deletion()
	var ta_ok: bool = is_instance_valid(target_a)
	var tb_ok: bool = is_instance_valid(target_b)

	if not a_freed:
		_fail("CHECK 5 [Despawn]", "EnemyA still valid after on_hit() — queue_free not called")
		return
	if not b_intact:
		_fail("CHECK 5 [Despawn]", "EnemyB freed or queued — unintended side effect")
		return
	if not ta_ok or not tb_ok:
		_fail("CHECK 5 [Despawn]", "TargetA or TargetB invalid after EnemyA despawn")
		return

	_pass("CHECK 5 [Despawn]", "EnemyA queued_for_deletion; EnemyB + TargetA/B intact")


# ── Helpers ──────────────────────────────────────────────────────────────────


func _pass(check: String, detail: String) -> void:
	print("PASS  %s — %s" % [check, detail])


func _fail(check: String, detail: String) -> void:
	print("FAIL  %s — %s" % [check, detail])
	_fail_count += 1


func _finish() -> void:
	print("\n=== RESULT: %d/%d checks FAILED ===" % [_fail_count, 5])
	if _fail_count == 0:
		print("ALL PASS")
	quit(_fail_count)
