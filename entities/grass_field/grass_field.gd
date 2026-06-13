# entities/grass_field/grass_field.gd — fills a MultiMesh with billboard grass blades.
class_name GrassField
extends Node3D

@export var blade_count: int = 500
@export var spawn_radius: float = 10.0
@export var blade_width: float = 0.15
@export var blade_height: float = 0.6
@export var spawn_seed: int = 42

@onready var _multi: MultiMeshInstance3D = $MultiMeshInstance3D


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blade_count
	mm.mesh = _build_quad()
	_multi.multimesh = mm
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed
	for i: int in blade_count:
		var x: float = rng.randf_range(-spawn_radius, spawn_radius)
		var z: float = rng.randf_range(-spawn_radius, spawn_radius)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0.0, z)))


func _build_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(blade_width, blade_height)
	# Pivot at bottom: shift the quad up by half its height so it sits on y=0.
	q.center_offset = Vector3(0.0, blade_height * 0.5, 0.0)
	return q
