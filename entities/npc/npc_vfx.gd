# entities/npc/npc_vfx.gd — VFX component for the NPC: spawns rescue halo on saved branch only.
class_name NpcVfx
extends Node

const _FX_HALO: PackedScene = preload("res://entities/vfx/rescue_halo.tscn")

## Optional: set explicitly on the NPC scene to skip the tree search at runtime.
@export var vfx_root_path: NodePath = ^""

var _vfx_root: Node3D


func _ready() -> void:
	var npc: Npc = get_parent() as Npc
	if npc == null:
		push_error("NpcVfx: parent must be an Npc node.")
		return
	npc.rescued.connect(_on_rescued)


## Spawn halo at the NPC world position, reparented under VfxRoot so it outlives the NPC.
func _on_rescued(npc: Npc) -> void:
	var root: Node3D = _get_vfx_root()
	if root == null:
		return
	var fx: Node3D = _FX_HALO.instantiate() as Node3D
	root.add_child(fx)
	fx.global_transform = npc.global_transform


func _get_vfx_root() -> Node3D:
	if _vfx_root != null:
		return _vfx_root
	if not vfx_root_path.is_empty():
		var n: Node = get_node_or_null(vfx_root_path)
		if n is Node3D:
			_vfx_root = n as Node3D
			return _vfx_root
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var found: Node = scene_root.find_child("VfxRoot", true, false)
	if found is Node3D:
		_vfx_root = found as Node3D
	return _vfx_root
