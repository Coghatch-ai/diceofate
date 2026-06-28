extends SceneTree


func _init() -> void:
	var scene: PackedScene = load("res://assets/models/wall.glb") as PackedScene
	if scene == null:
		print("ERROR: could not load wall.glb")
		quit(1)
		return
	var scene_root: Node = scene.instantiate()
	_print_bounds(scene_root, "")
	scene_root.queue_free()
	quit()


func _print_bounds(node: Node, indent: String) -> void:
	print(indent + node.name + " [" + node.get_class() + "]")
	if node is Node3D:
		var n3d: Node3D = node as Node3D
		print(indent + "  local pos=" + str(n3d.position) + " scale=" + str(n3d.scale))
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var aabb: AABB = mi.get_aabb()
		print(indent + "  AABB size=" + str(aabb.size) + " pos=" + str(aabb.position))
	for i: int in range(node.get_child_count()):
		_print_bounds(node.get_child(i), indent + "  ")
