# entities/vfx/acid_decal_router.gd — routes acid bullet impacts to the AcidDecalPool.
# Component child of Gun. Listens vfx_element_impact (cast_index == ACID_CAST_INDEX)
# and vfx_blast (AoE centre hit) when the active cast is acid (is_acid flag on CastData).
# Pool resolved by name fallback so no hard scene-path dependency (godot-composition).
class_name AcidDecalRouter
extends Node

## Bullet-casts slot index for the acid/blast bullet (T key = index 3).
## Must match rifle.tscn bullet_casts order: [pistol=0, heavy=1, stun=2, blast=3, rapid=4].
const ACID_CAST_INDEX: int = 3

## Optional explicit path to AcidDecalPool Node3D.
## Leave empty to use find_child("AcidCraterPool") fallback (resolved once at _ready).
@export var pool_path: NodePath = ^""

var _pool: AcidDecalPool
var _weapon: Gun


func _ready() -> void:
	_weapon = get_parent() as Gun
	if _weapon == null:
		push_error("AcidDecalRouter: parent must be a Gun node.")
		return
	_weapon.vfx_element_impact.connect(_on_element_impact)
	_weapon.vfx_blast.connect(_on_blast)
	_resolve_pool.call_deferred()


## Called on Gun.vfx_element_impact — place acid crater only for the acid cast slot.
func _on_element_impact(pos: Vector3, normal: Vector3, cast_index: int) -> void:
	if cast_index != ACID_CAST_INDEX:
		return
	var p: AcidDecalPool = _get_pool()
	if p == null:
		return
	p.place(pos, normal)


## Called on Gun.vfx_blast — AoE centre point also gets an acid crater mark.
## Guard: only place when active cast is acid (cast_data.is_acid check).
func _on_blast(pos: Vector3) -> void:
	if _weapon == null:
		return
	if _weapon.cast_data == null or not _weapon.cast_data.is_acid:
		return
	var p: AcidDecalPool = _get_pool()
	if p == null:
		return
	# Blast hits the floor: use UP as default normal for AoE centre crater.
	p.place(pos, Vector3.UP)


func _resolve_pool() -> void:
	if not pool_path.is_empty():
		var n: Node = get_node_or_null(pool_path)
		if n is AcidDecalPool:
			_pool = n as AcidDecalPool
			return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var found: Node = scene_root.find_child("AcidCraterPool", true, false)
	if found is AcidDecalPool:
		_pool = found as AcidDecalPool


func _get_pool() -> AcidDecalPool:
	return _pool
