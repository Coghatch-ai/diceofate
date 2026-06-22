# tools/diag_enemies.gd — throwaway headless diagnostic for enemy/WaveManager health.
# Run: $GODOT --headless --path . -s tools/diag_enemies.gd
extends SceneTree


func _initialize() -> void:
	var packed: PackedScene = load("res://levels/firing_yard.tscn") as PackedScene
	if packed == null:
		print("DIAG ERROR: could not load firing_yard.tscn")
		quit(1)
		return
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	_check.call_deferred()


func _check() -> void:
	var level: Node = get_root().get_child(0)
	if level == null:
		print("DIAG ERROR: no level in tree")
		quit(1)
		return

	print("=== DIAG: root=", level.name, " class=", level.get_class())

	# 1. WaveManager
	var wm: Node = level.find_child("WaveManager", false, false)
	if wm == null:
		print("DIAG FAIL: WaveManager NOT FOUND")
	else:
		print("DIAG OK: WaveManager found")
		@warning_ignore("unsafe_property_access")
		var enemy_scene_val: Variant = wm.enemy_scene
		print("  enemy_scene assigned: ", enemy_scene_val != null)
		@warning_ignore("unsafe_property_access")
		var sm_paths_val: Variant = wm.spawn_marker_paths
		@warning_ignore("unsafe_cast")
		var sm_arr: Array = sm_paths_val as Array
		print("  spawn_marker_paths count: ", sm_arr.size())
		@warning_ignore("unsafe_property_access")
		var wp_paths_val: Variant = wm.patrol_waypoint_paths
		@warning_ignore("unsafe_cast")
		var wp_arr: Array = wp_paths_val as Array
		print("  patrol_waypoint_paths count: ", wp_arr.size())

	# 2. Spawn markers + waypoints
	var marker_count: int = 0
	var wp_count: int = 0
	for child: Node in level.get_children():
		if child.name.begins_with("SpawnMarker"):
			marker_count += 1
		elif child.name.begins_with("EnemyWP"):
			wp_count += 1
	print("DIAG: SpawnMarker nodes=", marker_count)
	print("DIAG: EnemyWP nodes=", wp_count)

	# 3. NavigationRegion3D
	var found_nav: bool = false
	for child: Node in level.get_children():
		if child is NavigationRegion3D:
			found_nav = true
			print("DIAG OK: NavigationRegion3D found name=", child.name)
			break
	if not found_nav:
		print("DIAG FAIL: NO NavigationRegion3D in level root children")

	# 4. Player in group
	var player: Node = get_first_node_in_group("player")
	if player == null:
		print("DIAG FAIL: no node in group 'player'")
	else:
		var p3d: Node3D = player as Node3D
		print(
			"DIAG OK: player=",
			player.name,
			" pos=",
			p3d.global_position if p3d != null else Vector3.ZERO
		)

	# 5. Wait physics frames
	await _wait_frames(30)
	_count_enemies(level)


func _wait_frames(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _count_enemies(level: Node) -> void:
	# Dump ALL direct children of level root to catch renamed enemies
	print("DIAG: ALL level root children (", level.get_child_count(), " total):")
	for child: Node in level.get_children():
		print("  [", child.get_class(), "] ", child.name)

	# Collect enemies anywhere in tree
	var enemies: Array[Node] = []
	_collect_enemies(level, enemies)
	print("DIAG: CharacterBody3D nodes beginning 'Enemy' in full tree=", enemies.size())
	for e: Node in enemies:
		var e3d: Node3D = e as Node3D
		var pos: Vector3 = e3d.global_position if e3d != null else Vector3.ZERO
		var on_floor: bool = false
		if e is CharacterBody3D:
			on_floor = (e as CharacterBody3D).is_on_floor()
		print("  '", e.name, "' pos=", pos, " on_floor=", on_floor)
		var sm: Node = e.find_child("StateMachine", false, false)
		print("    StateMachine present=", sm != null)
		if sm != null:
			print("    StateMachine children=", sm.get_child_count())
			# Try to get current state name
			@warning_ignore("unsafe_property_access")
			var cur: Variant = sm.current_state
			print("    current_state=", cur)
		var nav: NavigationAgent3D = (
			e.find_child("NavigationAgent3D", false, false) as NavigationAgent3D
		)
		if nav != null:
			print(
				"    NavAgent finished=",
				nav.is_navigation_finished(),
				" target=",
				nav.target_position
			)
		# Check patrol waypoints resolved
		@warning_ignore("unsafe_property_access")
		var pwp: Variant = e.patrol_waypoints
		@warning_ignore("unsafe_cast")
		var pwp_arr: Array = pwp as Array
		print("    patrol_waypoints resolved=", pwp_arr.size())
	if enemies.is_empty():
		print("DIAG FAIL: ZERO enemies in tree after 30 frames")
	quit(0)


func _collect_enemies(node: Node, out: Array[Node]) -> void:
	if node is CharacterBody3D and node.name.begins_with("Enemy"):
		out.append(node)
	for child: Node in node.get_children():
		_collect_enemies(child, out)
