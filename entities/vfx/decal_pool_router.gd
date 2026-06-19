# entities/vfx/decal_pool_router.gd — routes weapon impact/kill signals to the ScorchDecalPool.
# Component child of a Weapon node. Inject `pool` via the scene inspector or from the level.
class_name DecalPoolRouter
extends Node

## The shared scorch decal pool. Must be set before _ready() or wired by the level root.
@export var pool: ScorchDecalPool

var _weapon: Weapon


func _ready() -> void:
	_weapon = get_parent() as Weapon
	if _weapon == null:
		push_error("DecalPoolRouter: parent must be a Weapon node.")
		return
	_weapon.vfx_impact.connect(_on_impact)
	_weapon.vfx_kill.connect(_on_kill)


## Place a scorch decal at generic impact position (wall, floor hit).
func _on_impact(pos: Vector3, normal: Vector3) -> void:
	var p: ScorchDecalPool = _get_pool()
	if p == null:
		return
	p.place(pos, normal)


## Place a scorch decal at kill position (enemy death). Normal typically UP for floor kills.
func _on_kill(pos: Vector3, normal: Vector3) -> void:
	var p: ScorchDecalPool = _get_pool()
	if p == null:
		return
	p.place(pos, normal)


func _get_pool() -> ScorchDecalPool:
	if pool != null:
		return pool
	# Fallback: find first ScorchDecalPool by type anywhere in the current scene.
	# Type-based search is rename-safe; no hard-coded node name required.
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var found: ScorchDecalPool = _find_pool_in(scene_root)
	if found != null:
		pool = found
	return pool


func _find_pool_in(node: Node) -> ScorchDecalPool:
	if node is ScorchDecalPool:
		return node as ScorchDecalPool
	for child: Node in node.get_children():
		var result: ScorchDecalPool = _find_pool_in(child)
		if result != null:
			return result
	return null
