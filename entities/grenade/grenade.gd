# entities/grenade/grenade.gd — thrown grenade: physics arc, timed fuse, AoE damage + VFX.
class_name Grenade
extends RigidBody3D

signal exploded

# Cached VFX scene — reuse existing blast_explosion.
const _EXPLOSION_SCENE: PackedScene = preload("res://entities/vfx/blast_explosion.tscn")
const _SHOCKWAVE_SCENE: PackedScene = preload("res://entities/vfx/shockwave_ring.tscn")

## Tuning params injected by GrenadeThrowController before add_child.
@export var data: GrenadeData

## Collision layer: world(1) + target(4). Layer: none (grenade doesn't need to be hit).
## Exclude player layer(2) so the grenade never collides with the thrower.

var _fuse_elapsed: float = 0.0
var _armed: bool = false
var _exploded: bool = false


func _ready() -> void:
	# Exclude player layer from collision mask (layer 2 = bit 1).
	# Grenade collides with world(1) and targets(4) only.
	collision_mask = 0b1001
	collision_layer = 0b0000
	_armed = true


func _physics_process(delta: float) -> void:
	if not _armed or _exploded:
		return
	_fuse_elapsed += delta
	if data != null and _fuse_elapsed >= data.fuse_time:
		_explode()
	elif data == null and _fuse_elapsed >= 1.5:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_armed = false

	var origin: Vector3 = global_position
	var radius: float = 5.0
	var dmg: int = 60
	if data != null:
		radius = data.blast_radius
		dmg = data.damage

	_apply_aoe_damage(origin, radius, dmg)
	_spawn_vfx(origin)
	exploded.emit()
	queue_free()


func _apply_aoe_damage(origin: Vector3, radius: float, dmg: int) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin)
	# Query only target layer (bit 3 = layer 4).
	params.collision_mask = 0b1000
	var results: Array[Dictionary] = space.intersect_shape(params, 32)
	for hit: Dictionary in results:
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		if not collider is Node:
			continue
		var node: Node = collider as Node
		if node.has_method("apply_damage"):
			# SEAM: duck-typed apply_damage seam (godot-fps-enemy-combat / player contract).
			@warning_ignore("unsafe_method_access")
			node.apply_damage(dmg, DamageType.Kind.PHYSICAL)


func _spawn_vfx(origin: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	# Find surviving VfxRoot (pattern from vfx_router.gd).
	var vfx_root: Node = scene_root.find_child("VfxRoot", true, false)
	var parent: Node = vfx_root if vfx_root != null else scene_root

	var blast: Node3D = _EXPLOSION_SCENE.instantiate() as Node3D
	parent.add_child(blast)
	blast.global_position = origin

	var shockwave: Node3D = _SHOCKWAVE_SCENE.instantiate() as Node3D
	parent.add_child(shockwave)
	shockwave.global_position = origin
