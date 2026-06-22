# tools/bake_navmesh.gd — headless: parse + bake NavFloor NavigationMesh and save to disk.
# Usage: $GODOT --headless --path . --script tools/bake_navmesh.gd
# Saves res://levels/firing_yard_navmesh.tres — a pre-baked NavigationMesh resource.
# After running: assign that .tres to NavFloor.navigation_mesh in firing_yard.tscn so
# the scene no longer needs a runtime bake_navigation_mesh() call in _ready().
extends SceneTree

const SCENE_PATH: String = "res://levels/firing_yard.tscn"
const OUTPUT_PATH: String = "res://levels/firing_yard_navmesh.tres"
const NAV_NODE_NAME: String = "NavFloor"
const WAIT_FRAMES: int = 3

var _scene_root: Node = null
var _frame: int = 0


func _initialize() -> void:
	print("NAVBAKE: loading %s" % SCENE_PATH)
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("NAVBAKE: FAIL — could not load scene")
		quit(1)
		return
	_scene_root = packed.instantiate()
	if _scene_root == null:
		push_error("NAVBAKE: FAIL — could not instantiate scene")
		quit(1)
		return
	# Add to tree so all nodes enter the SceneTree and their geometry is available.
	get_root().add_child(_scene_root)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < WAIT_FRAMES:
		return false
	_do_bake()
	return true


func _do_bake() -> void:
	var nav_region: NavigationRegion3D = (
		_scene_root.get_node_or_null(NAV_NODE_NAME) as NavigationRegion3D
	)
	if nav_region == null:
		push_error("NAVBAKE: FAIL — node '%s' not found in scene" % NAV_NODE_NAME)
		quit(1)
		return

	var mesh: NavigationMesh = nav_region.navigation_mesh
	if mesh == null:
		push_error("NAVBAKE: FAIL — NavFloor has no NavigationMesh resource")
		quit(1)
		return

	print("NAVBAKE: parsing source geometry from scene root...")
	var source_geo := NavigationMeshSourceGeometryData3D.new()
	# parse_source_geometry_data uses the mesh's geometry_parsed_geometry_type and
	# geometry_source_geometry_mode settings (static colliders, root children).
	NavigationMeshGenerator.parse_source_geometry_data(mesh, source_geo, _scene_root)
	var parsed_verts: int = source_geo.get_vertices().size()
	print("NAVBAKE: parsed %d source vertices" % parsed_verts)

	if parsed_verts == 0:
		push_error("NAVBAKE: FAIL — 0 source vertices; check geometry settings in NavigationMesh")
		quit(1)
		return

	print("NAVBAKE: baking navmesh from parsed geometry...")
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, source_geo)

	var baked_verts: int = mesh.get_vertices().size()
	print("NAVBAKE: baked mesh has %d vertices" % baked_verts)

	if baked_verts == 0:
		push_error("NAVBAKE: FAIL — bake produced 0 vertices")
		quit(1)
		return

	var err: int = ResourceSaver.save(mesh, OUTPUT_PATH)
	if err != OK:
		push_error("NAVBAKE: FAIL — ResourceSaver.save error %d" % err)
		quit(1)
		return

	print("NAVBAKE: OK — %s saved (%d vertices)" % [OUTPUT_PATH, baked_verts])
	quit(0)
