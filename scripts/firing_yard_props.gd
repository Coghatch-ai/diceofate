# scripts/firing_yard_props.gd — props, actors, lighting phase.
class_name FiringYardProps

const WAVE_MANAGER_SCRIPT: String = "res://levels/wave_manager.gd"
const ENEMY_SCENE: String = "res://entities/enemy/enemy.tscn"
const NPC_SCENE: String = "res://entities/npc/npc.tscn"
const NAVMESH_PATH: String = "res://levels/firing_yard_navmesh.tres"

# Stationary NPC positions — mid-floor ahead of spawn (24,1,30 facing -Z).
# Capsule centre y=0.9 so base sits on floor (height 1.8, half = 0.9).
const NPC_POSITIONS: Array[Vector3] = [
	Vector3(18.0, 0.9, 14.0),
	Vector3(21.0, 0.9, 18.0),
	Vector3(24.0, 0.9, 22.0),
	Vector3(27.0, 0.9, 16.0),
	Vector3(30.0, 0.9, 20.0),
]

# Patrol waypoints (world-space positions).
const ENEMY_WAYPOINTS: Array[Vector3] = [
	Vector3(22.0, 0.0, 12.0),
	Vector3(30.0, 0.0, 16.0),
	Vector3(26.0, 0.0, 22.0),
]

# Perimeter spawn markers (world-space positions, out-of-sight ring).
# Y = 0.0 matches floor top surface; wave_manager adds a small clearance offset on spawn.
const SPAWN_MARKERS: Array[Vector3] = [
	Vector3(3.0, 0.0, 3.0),
	Vector3(14.0, 0.0, 3.0),
	Vector3(30.0, 0.0, 3.0),
	Vector3(45.0, 0.0, 3.0),
	Vector3(45.0, 0.0, 10.0),
	Vector3(45.0, 0.0, 20.0),
	Vector3(45.0, 0.0, 37.0),
	Vector3(35.0, 0.0, 37.0),
	Vector3(13.0, 0.0, 37.0),
	Vector3(3.0, 0.0, 37.0),
	Vector3(3.0, 0.0, 20.0),
	Vector3(3.0, 0.0, 10.0),
]


static func add_platforms(scene_root: Node3D, cover_color: Color) -> void:
	var cov: StandardMaterial3D = StandardMaterial3D.new()
	cov.albedo_color = cover_color

	FiringYardNodes.build_box_body(
		scene_root, "HighPlatform", Vector3(4.0, 2.0, 4.0), Vector3(40.0, 1.0, 6.0), cov
	)
	FiringYardNodes.build_box_body(
		scene_root, "MidPlatform", Vector3(4.0, 1.0, 4.0), Vector3(40.0, 0.5, 24.0), cov
	)
	FiringYardNodes.build_ramp_body(
		scene_root, "HighPlatformRamp", Vector3(4.0, 0.3, 2.828), Vector3(40.0, 1.0, 9.0), 45.0, cov
	)
	FiringYardNodes.build_ramp_body(
		scene_root,
		"MidPlatformRamp",
		Vector3(4.0, 0.3, 2.236),
		Vector3(40.0, 0.5, 27.0),
		26.565,
		cov
	)

	var deco_col: Color = Color(0.306, 0.314, 0.063, 1.0)
	var deco_sz: Vector3 = Vector3(0.8, 0.8, 0.8)
	var deco_pos: Array[Vector3] = [
		Vector3(5.0, 0.4, 13.0),
		Vector3(17.0, 0.4, 17.0),
		Vector3(13.0, 0.4, 21.0),
		Vector3(31.0, 0.4, 21.0),
		Vector3(5.0, 0.4, 27.0),
	]
	for di: int in range(deco_pos.size()):
		FiringYardNodes.vis_mesh(scene_root, "DecoProp" + str(di), deco_sz, deco_pos[di], deco_col)


static func add_targets(scene_root: Node3D, target_scene_path: String) -> void:
	var tp: PackedScene = load(target_scene_path) as PackedScene
	var configs: Array[Dictionary] = [
		{"name": "TargetA", "pos": Vector3(24.0, 0.5, 20.0)},
		{"name": "TargetB", "pos": Vector3(18.0, 0.5, 14.0)},
		{"name": "TargetC", "pos": Vector3(40.0, 1.5, 24.0)},
		{"name": "TargetD", "pos": Vector3(40.0, 2.5, 6.0)},
	]
	for cfg: Dictionary in configs:
		var inst: Node = tp.instantiate()
		@warning_ignore("unsafe_cast")
		var t: StaticBody3D = inst as StaticBody3D
		@warning_ignore("unsafe_cast")
		t.name = cfg["name"] as String
		@warning_ignore("unsafe_cast")
		t.position = cfg["pos"] as Vector3
		t.collision_layer = 8
		t.collision_mask = 0
		# Script already attached in target.tscn root — do NOT set_script here.
		scene_root.add_child(t)
		t.owner = scene_root


static func add_lighting(scene_root: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-10.0, 180.0, 0.0)
	sun.light_color = Color(1.0, 0.6, 0.2, 1.0)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 60.0
	scene_root.add_child(sun)
	sun.owner = scene_root

	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.35, 0.2, 1.0)
	sky_mat.sky_horizon_color = Color(0.9, 0.55, 0.2, 1.0)
	sky_mat.ground_horizon_color = Color(0.9, 0.55, 0.2, 1.0)
	sky_mat.ground_bottom_color = Color(0.05, 0.03, 0.01, 1.0)
	sky_mat.sun_angle_max = 0.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.25, 0.15, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	scene_root.add_child(we)
	we.owner = scene_root


static func add_player(
	scene_root: Node3D, player_scene_path: String, spawn_pos: Vector3, spawn_rot_y: float
) -> void:
	var pp: PackedScene = load(player_scene_path) as PackedScene
	var inst: Node = pp.instantiate()
	@warning_ignore("unsafe_cast")
	var player: CharacterBody3D = inst as CharacterBody3D
	player.name = "Player"
	player.add_to_group("player")
	player.position = spawn_pos
	player.rotation.y = spawn_rot_y
	player.collision_layer = 2
	# Script already attached in player.tscn root — do NOT set_script here.
	scene_root.add_child(player)
	player.owner = scene_root


static func add_navmesh(scene_root: Node3D) -> void:
	var nav_mesh: NavigationMesh = load(NAVMESH_PATH) as NavigationMesh
	if nav_mesh == null:
		push_error("FiringYardProps: could not load navmesh from " + NAVMESH_PATH)
		return
	var nav_region: NavigationRegion3D = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	nav_region.navigation_mesh = nav_mesh
	scene_root.add_child(nav_region)
	nav_region.owner = scene_root
	print("FiringYardProps: NavigationRegion3D added with pre-baked navmesh")


static func add_enemies(scene_root: Node3D) -> void:
	var wm_script: Script = load(WAVE_MANAGER_SCRIPT) as Script
	var enemy_packed: PackedScene = load(ENEMY_SCENE) as PackedScene

	# Patrol waypoints.
	var wp_paths: Array[NodePath] = []
	for i: int in range(ENEMY_WAYPOINTS.size()):
		var wp: Marker3D = Marker3D.new()
		wp.name = "EnemyWP" + str(i)
		wp.position = ENEMY_WAYPOINTS[i]
		scene_root.add_child(wp)
		wp.owner = scene_root
		wp_paths.append(NodePath("../" + wp.name))

	# Perimeter spawn markers.
	var sm_paths: Array[NodePath] = []
	for i: int in range(SPAWN_MARKERS.size()):
		var sm: Marker3D = Marker3D.new()
		sm.name = "SpawnMarker" + str(i)
		sm.position = SPAWN_MARKERS[i]
		scene_root.add_child(sm)
		sm.owner = scene_root
		sm_paths.append(NodePath("../" + sm.name))

	# WaveManager node.
	var wm: Node = Node.new()
	wm.name = "WaveManager"
	wm.set_script(wm_script)
	scene_root.add_child(wm)
	wm.owner = scene_root
	# SEAM: duck-typed export assignment — WaveManager is a plain Node at build time.
	@warning_ignore("unsafe_property_access")
	wm.enemy_scene = enemy_packed
	@warning_ignore("unsafe_property_access")
	wm.spawn_marker_paths = sm_paths
	@warning_ignore("unsafe_property_access")
	wm.patrol_waypoint_paths = wp_paths


static func add_npcs(scene_root: Node3D, npc_scene_path: String) -> void:
	var np: PackedScene = load(npc_scene_path) as PackedScene
	for i: int in range(NPC_POSITIONS.size()):
		var inst: Node = np.instantiate()
		@warning_ignore("unsafe_cast")
		var npc: StaticBody3D = inst as StaticBody3D
		npc.name = "Npc" + str(i)
		npc.position = NPC_POSITIONS[i]
		npc.collision_layer = 8
		npc.collision_mask = 0
		scene_root.add_child(npc)
		npc.owner = scene_root
