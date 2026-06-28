extends SceneTree

var _combined: AABB = AABB()
var _first: bool = true


func _init() -> void:
	var scene: PackedScene = load("res://x-shared-assets/models/scouter-eye-glass-frame.glb")
	if scene == null:
		print("INSPECT-FAIL: could not load PackedScene")
		quit(1)
		return
	var scene_root: Node = scene.instantiate()
	_walk(scene_root, Transform3D.IDENTITY)
	print("COMBINED_AABB pos=", _combined.position, " size=", _combined.size)
	print("COMBINED_AABB end=", _combined.end)
	scene_root.queue_free()
	quit(0)


func _walk(node: Node, xform: Transform3D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			var local_aabb: AABB = mi.mesh.get_aabb()
			var world_aabb: AABB = xform * local_aabb
			print(
				"MI '",
				node.name,
				"' local_size=",
				local_aabb.size,
				" surfs=",
				mi.mesh.get_surface_count()
			)
			if _first:
				_combined = world_aabb
				_first = false
			else:
				_combined = _combined.merge(world_aabb)
	if node is Node3D:
		var n3: Node3D = node as Node3D
		for child: Node in node.get_children():
			_walk(child, xform * n3.transform)
	else:
		for child: Node in node.get_children():
			_walk(child, xform)
