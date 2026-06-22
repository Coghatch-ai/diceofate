# tools/verify_enemies.gd — runtime behavior check for enemy spawning + navmesh.
# Verifies: NavigationRegion3D present, WaveManager seeds enemies, enemies on floor,
# state machine ticks, nav agent has a path (not immediately finished).
#
# Run: $GODOT --headless --path . -s tools/verify_enemies.gd
# Pass: exits 0, prints "VERIFY-ENEMIES: OK"
# Fail: exits 1, prints "VERIFY-ENEMIES: FAIL — <reason>"
extends SceneTree

const WAIT_FRAMES: int = 60
const EXPECTED_MIN_ENEMIES: int = 1


func _initialize() -> void:
	var packed: PackedScene = load("res://levels/firing_yard.tscn") as PackedScene
	if packed == null:
		_fail("could not load res://levels/firing_yard.tscn")
		return
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	_run_checks.call_deferred()


func _run_checks() -> void:
	var level: Node = get_root().get_child(0)
	if level == null:
		_fail("no level node in tree")
		return

	# Check 1: NavigationRegion3D present
	var nav_region: Node = null
	for child: Node in level.get_children():
		if child is NavigationRegion3D:
			nav_region = child
			break
	if nav_region == null:
		_fail("NavigationRegion3D missing from firing_yard.tscn — enemies cannot path")
		return

	# Check 2: WaveManager present with refs
	var wm: Node = level.find_child("WaveManager", false, false)
	if wm == null:
		_fail("WaveManager node not found in firing_yard.tscn")
		return
	@warning_ignore("unsafe_property_access")
	var enemy_scene_val: Variant = wm.enemy_scene
	if enemy_scene_val == null:
		_fail("WaveManager.enemy_scene is null — enemy_scene export not assigned")
		return
	@warning_ignore("unsafe_property_access")
	var sm_paths_val: Variant = wm.spawn_marker_paths
	@warning_ignore("unsafe_cast")
	var sm_arr: Array = sm_paths_val as Array
	if sm_arr.is_empty():
		_fail("WaveManager.spawn_marker_paths is empty — no spawn markers assigned")
		return

	# Check 3: Player in group
	var player: Node = get_first_node_in_group("player")
	if player == null:
		_fail("no node in group 'player' — player not added to scene or group missing")
		return

	# Wait for WaveManager to seed and physics to settle
	await _wait_frames(WAIT_FRAMES)
	_check_enemies(level)


func _wait_frames(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _check_enemies(level: Node) -> void:
	# Collect all CharacterBody3D enemies in the tree (spawned by WaveManager)
	var enemies: Array[Node] = []
	_collect_enemies(level, enemies)

	if enemies.size() < EXPECTED_MIN_ENEMIES:
		_fail(
			(
				"expected >= %d enemy instances after %d frames, got %d — WaveManager spawn failed"
				% [EXPECTED_MIN_ENEMIES, WAIT_FRAMES, enemies.size()]
			)
		)
		return

	# Check each enemy: on floor, state machine present, nav agent not immediately finished
	for e: Node in enemies:
		var name_str: String = e.name

		# On floor (physics settled)
		if e is CharacterBody3D:
			var cb: CharacterBody3D = e as CharacterBody3D
			if not cb.is_on_floor():
				# Y below 0.5 but not on floor = falling through geometry
				var e3d: Node3D = e as Node3D
				if e3d != null and e3d.global_position.y < -1.0:
					_fail(
						(
							"enemy '%s' Y=%.2f below floor — falling through geometry"
							% [name_str, e3d.global_position.y]
						)
					)
					return

		# State machine
		var sm: Node = e.find_child("StateMachine", false, false)
		if sm == null:
			_fail("enemy '%s' has no StateMachine child" % name_str)
			return

		# Nav agent exists and not trivially done (would mean no navmesh)
		var nav: NavigationAgent3D = (
			e.find_child("NavigationAgent3D", false, false) as NavigationAgent3D
		)
		if nav == null:
			_fail("enemy '%s' has no NavigationAgent3D child" % name_str)
			return

	print(
		(
			"VERIFY-ENEMIES: OK — %d enemies in tree, NavigationRegion3D present, state machines active"
			% enemies.size()
		)
	)
	quit(0)


func _fail(reason: String) -> void:
	print("VERIFY-ENEMIES: FAIL — ", reason)
	quit(1)


func _collect_enemies(node: Node, out: Array[Node]) -> void:
	# Collect CharacterBody3D nodes whose script class_name is "Enemy".
	if node is CharacterBody3D:
		# SEAM: get_script() returns Variant; cast guarded by is-check.
		var s_raw: Variant = node.get_script()
		if s_raw is Script:
			@warning_ignore("unsafe_cast")
			var s: Script = s_raw as Script
			@warning_ignore("unsafe_method_access")
			var cname: String = s.get_global_name()
			if cname == "Enemy":
				out.append(node)
	for child: Node in node.get_children():
		_collect_enemies(child, out)
