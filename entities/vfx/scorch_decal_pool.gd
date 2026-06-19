# entities/vfx/scorch_decal_pool.gd — round-robin pool of reused Decal nodes for impact scorches.
# Decal is Forward+/Mobile only; this project uses Forward+ (project.godot config/features).
# Each visible Decal is ONE clustered element sharing the 512-element budget with lights and
# reflection probes (NOT a deferred pass). Pooling bounds live count and avoids alloc churn.
class_name ScorchDecalPool
extends Node3D

const _SCORCH_TEX: Texture2D = preload("res://assets/textures/scorch_decal.png")

## Pool size — bounds clustered-element budget. Minimum 1 enforced in _ready().
@export_range(1, 64) var pool_size: int = 8
## Seconds for a decal to fully fade from opaque to transparent before recycling.
@export var fade_duration: float = 10.0
## Decal extents (half-size in each axis). Y controls projection depth along surface normal.
@export var decal_extents: Vector3 = Vector3(0.6, 0.5, 0.6)
## Opacity at placement (0–1). Art-director tunable.
@export var peak_albedo_mix: float = 0.85

var _decals: Array[Decal] = []
var _index: int = 0
var _tweens: Array[Tween] = []


func _ready() -> void:
	# Guard: pool_size<=0 would leave _decals empty and cause modulo-by-zero on first place().
	if pool_size <= 0:
		pool_size = 1
	_tweens.resize(pool_size)
	for i: int in range(pool_size):
		var d: Decal = Decal.new()
		d.texture_albedo = _SCORCH_TEX
		d.size = decal_extents * 2.0
		d.modulate = Color(1.0, 1.0, 1.0, 0.0)
		d.visible = false
		add_child(d)
		_decals.append(d)


## Place the next pooled decal at world position, oriented to the surface normal.
## Normal is the surface normal at the hit point (default Vector3.UP for floor hits).
## Decal projects along local -Y, so Y column of basis = surface_normal.
## Degenerate fix: when normal is near ±Y (floor/ceiling), seed tangent with RIGHT so
## cross products never collapse.
func place(world_pos: Vector3, surface_normal: Vector3 = Vector3.UP) -> void:
	var d: Decal = _decals[_index]

	# Cancel any running fade tween on this slot before reusing it.
	if _tweens[_index] != null and _tweens[_index].is_valid():
		_tweens[_index].kill()

	# Build a right-handed basis whose Y column = surface_normal (Decal projection axis).
	# Seed with RIGHT when normal is near ±Y to avoid degenerate cross products on floor/ceiling.
	var up_hint: Vector3 = (
		Vector3.RIGHT if absf(surface_normal.dot(Vector3.UP)) > 0.9 else Vector3.UP
	)
	var right: Vector3 = surface_normal.cross(up_hint).normalized()
	var forward: Vector3 = right.cross(surface_normal).normalized()
	# Columns: x=right, y=surface_normal, z=forward → det = right·(surface_normal×forward)
	# = right·right = 1 (right-handed, orthonormal).
	var surface_basis := Basis(right, surface_normal, forward)
	d.global_transform = Transform3D(surface_basis, world_pos)
	d.size = decal_extents * 2.0
	d.modulate = Color(1.0, 1.0, 1.0, peak_albedo_mix)
	d.visible = true

	# Fade alpha to 0 over fade_duration, then hide (slot recycled on next place()).
	var t: Tween = create_tween()
	t.tween_property(d, "modulate:a", 0.0, fade_duration)
	t.tween_callback(d.hide)
	_tweens[_index] = t

	_index = (_index + 1) % pool_size
