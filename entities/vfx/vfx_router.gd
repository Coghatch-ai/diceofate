# entities/vfx/vfx_router.gd — thin router: Weapon signals -> one-shot VFX scenes. No autoload.
class_name VfxRouter
extends Node

## Art-director tuning knobs (Phase-1 defaults; refine per-scene):
## Muzzle spark: white-hot (1.0, 0.95, 0.8) -> orange (0.7, 0.35, 0.05) — muzzle_spark.tscn.
## Impact burst: HAZARD_AMBER (0.7, 0.46, 0.12) -> grey (0.55, 0.55, 0.55) — impact_burst.tscn.

const _FX_MUZZLE: PackedScene = preload("res://entities/vfx/muzzle_spark.tscn")
const _FX_IMPACT: PackedScene = preload("res://entities/vfx/impact_burst.tscn")

## Path to a surviving VfxRoot Node3D. Optional: if empty, find_child("VfxRoot") is used.
## Set explicitly to avoid the tree search cost (e.g. ../../../VfxRoot from weapon context).
@export var vfx_root_path: NodePath = ^""

var _vfx_root: Node3D


func _ready() -> void:
	# vfx_root_path is optional; _get_vfx_root() falls back to find_child("VfxRoot") if empty.
	# Parent is a Weapon — typed cast is safe (wiring down to known type, godot-composition).
	var weapon: Weapon = get_parent() as Weapon
	if weapon == null:
		push_error("VfxRouter: parent is not a Weapon node.")
		return
	weapon.fired.connect(_on_fired)
	weapon.vfx_impact.connect(_on_impact)


## Called by weapon.gd _fire() path after shot fires.
func _on_fired() -> void:
	# Spawn spark at Muzzle world position. Muzzle is a sibling path under the view-model;
	# weapon.gd owns the typed _muzzle ref but we can't reach it here without coupling.
	# Instead, search parent for the Muzzle Marker3D by group/name (composition-safe).
	var muzzle: Marker3D = _find_muzzle()
	if muzzle == null:
		return
	_spawn_vfx(_FX_MUZZLE, muzzle.global_transform)


## Called by weapon.gd when a projectile hits (carries world position).
func _on_impact(pos: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY, pos)
	_spawn_vfx(_FX_IMPACT, t)


func _spawn_vfx(scene: PackedScene, at: Transform3D) -> void:
	var root: Node3D = _get_vfx_root()
	if root == null:
		return
	var fx: Node3D = scene.instantiate() as Node3D
	root.add_child(fx)
	fx.global_transform = at


func _get_vfx_root() -> Node3D:
	if _vfx_root != null:
		return _vfx_root
	if not vfx_root_path.is_empty():
		var n: Node = get_node_or_null(vfx_root_path)
		if n is Node3D:
			_vfx_root = n as Node3D
			return _vfx_root
	# Fallback: find VfxRoot by name in scene tree.
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var found: Node = scene_root.find_child("VfxRoot", true, false)
	if found is Node3D:
		_vfx_root = found as Node3D
	return _vfx_root


func _find_muzzle() -> Marker3D:
	# Search parent subtree for Muzzle Marker3D. Weapon.gd already caches _muzzle but
	# it is private — we find it by name to avoid coupling to weapon.gd internals.
	var parent: Node = get_parent()
	if parent == null:
		return null
	var found: Node = parent.find_child("Muzzle", true, false)
	if found is Marker3D:
		return found as Marker3D
	return null
