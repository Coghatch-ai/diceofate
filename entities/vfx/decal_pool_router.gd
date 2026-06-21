# entities/vfx/decal_pool_router.gd — routes weapon impact/kill signals to the ScorchDecalPool.
# Component child of a Gun node. Inject `pool` via the scene inspector or from the level.
class_name DecalPoolRouter
extends Node

## The shared scorch decal pool. Must be set before _ready() or wired by the level root.
@export var pool: ScorchDecalPool

var _weapon: Gun


func _ready() -> void:
	_weapon = get_parent() as Gun
	if _weapon == null:
		push_error("DecalPoolRouter: parent must be a Gun node.")
		return
	_weapon.vfx_impact.connect(_on_impact)
	_weapon.vfx_kill.connect(_on_kill)
	# Eagerly resolve pool on _ready (deferred so scene tree is settled) to avoid a
	# recursive tree walk on every impact/kill signal during combat.
	if pool == null:
		_resolve_pool.call_deferred()


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


## Resolve pool once (called deferred from _ready) so combat signals find it already cached.
## Uses find_child on the scene root — rename-safe, runs once at load not per-hit.
func _resolve_pool() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var found: Node = scene_root.find_child("ScorchDecalPool", true, false)
	if found is ScorchDecalPool:
		pool = found as ScorchDecalPool


func _get_pool() -> ScorchDecalPool:
	return pool
