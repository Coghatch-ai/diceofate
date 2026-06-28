# entities/vfx/acid_decal_pool.gd — round-robin pool of acid crater Decal nodes.
# Reuses the same pooling + placement contract as ScorchDecalPool (godot-decal-vfx).
# Placeholder: uses scorch_decal.png tinted acid-green; replace with a dedicated
# corrosion/pit mask asset when available (no art request filed — placeholder is intentional).
class_name AcidDecalPool
extends Node3D

## Placeholder mask — same as scorch; art can swap for a corrosion/pit texture later.
const _ACID_TEX: Texture2D = preload("res://assets/textures/scorch_decal.png")

## Pool size — bounds clustered-element budget (512-slot Forward+ limit).
@export_range(1, 64) var pool_size: int = 8
## Seconds for a crater decal to fully fade before the slot recycles.
@export var fade_duration: float = 20.0
## Decal extents (half-size). Larger than scorch to read as a "hole/crater".
@export var decal_extents: Vector3 = Vector3(0.8, 0.6, 0.8)
## Peak opacity at placement (0–1).
@export var peak_albedo_mix: float = 0.9
## Acid-green tint applied via Decal.modulate (premult-safe; alpha fades over fade_duration).
@export var acid_color: Color = Color(0.35, 0.9, 0.15, 1.0)

var _decals: Array[Decal] = []
var _index: int = 0
var _tweens: Array[Tween] = []


func _ready() -> void:
	if pool_size <= 0:
		pool_size = 1
	_tweens.resize(pool_size)
	for i: int in range(pool_size):
		var d: Decal = Decal.new()
		d.texture_albedo = _ACID_TEX
		d.size = decal_extents * 2.0
		# Start invisible; acid_color.a will be driven by peak_albedo_mix on place().
		d.modulate = Color(acid_color.r, acid_color.g, acid_color.b, 0.0)
		d.visible = false
		add_child(d)
		_decals.append(d)


## Place the next pooled acid crater decal at world_pos, oriented to surface_normal.
## Decal projects along local -Y → Y column of basis = surface_normal.
## Degenerate fix: seed tangent with RIGHT when normal is near ±Y (floor/ceiling).
func place(world_pos: Vector3, surface_normal: Vector3 = Vector3.UP) -> void:
	var d: Decal = _decals[_index]

	# Kill any running fade on this slot before reuse.
	if _tweens[_index] != null and _tweens[_index].is_valid():
		_tweens[_index].kill()

	# Build right-handed basis: Y = surface_normal (Decal projection axis).
	var up_hint: Vector3 = (
		Vector3.RIGHT if absf(surface_normal.dot(Vector3.UP)) > 0.9 else Vector3.UP
	)
	var right: Vector3 = surface_normal.cross(up_hint).normalized()
	var forward: Vector3 = right.cross(surface_normal).normalized()
	var surface_basis := Basis(right, surface_normal, forward)
	d.global_transform = Transform3D(surface_basis, world_pos)
	d.size = decal_extents * 2.0
	d.modulate = Color(acid_color.r, acid_color.g, acid_color.b, peak_albedo_mix)
	d.visible = true

	# Fade alpha to 0 over fade_duration, then hide (slot recycled on next place()).
	var t: Tween = create_tween()
	t.tween_property(d, "modulate:a", 0.0, fade_duration)
	t.tween_callback(d.hide)
	_tweens[_index] = t

	_index = (_index + 1) % pool_size
