# tools/bake_iron_floor_navmesh.gd — headless navmesh bake attempt for iron_floor.tscn.
# NOTE: Headless baking produces 0 vertices because the DUMMY renderer cannot scan
# MeshInstance3D surfaces for NavMesh geometry source.
# Bake in-editor: open iron_floor.tscn, select NavigationRegion3D, click "Bake NavMesh".
# The baked result will update res://levels/iron_floor_navmesh.tres.
#
# Run: $GODOT --headless --path . --script tools/bake_iron_floor_navmesh.gd
extends SceneTree

const SETTLE_FRAMES: int = 5

var _nav_region: NavigationRegion3D = null
var _frames: int = 0


func _init() -> void:
	var packed := load("res://levels/iron_floor.tscn") as PackedScene
	if packed == null:
		push_error("bake_navmesh: failed to load iron_floor.tscn")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	get_root().add_child(scene)

	_nav_region = scene.find_child("NavigationRegion3D", true, false) as NavigationRegion3D
	if _nav_region == null:
		push_error("bake_navmesh: NavigationRegion3D not found")
		quit(1)
		return
	print("bake_navmesh: scene loaded, settling %d frames..." % SETTLE_FRAMES)


func _process(_delta: float) -> bool:
	if _nav_region == null:
		return false
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	print("bake_navmesh: baking NavigationMesh after %d frames..." % _frames)
	_nav_region.bake_navigation_mesh(false)
	var mesh: NavigationMesh = _nav_region.navigation_mesh
	if mesh == null:
		push_error("bake_navmesh: bake produced null mesh")
		quit(1)
		return false
	var verts: PackedVector3Array = mesh.get_vertices()
	print("bake_navmesh: mesh has %d vertices (0 = headless limitation)" % verts.size())
	var err: int = ResourceSaver.save(mesh, "res://levels/iron_floor_navmesh.tres")
	if err != OK:
		push_error("bake_navmesh: ResourceSaver.save failed, error %d" % err)
		quit(1)
		return false
	print("bake_navmesh: saved res://levels/iron_floor_navmesh.tres")
	quit(0)
	return false
