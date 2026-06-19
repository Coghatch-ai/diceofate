# entities/vfx/scorch_decal_pool.gd — round-robin pool of 8 Decal nodes for impact/death scorches.
# Decal nodes are Forward+/Mobile only; this project uses Forward+ (project.godot config/features).
class_name ScorchDecalPool
extends Node3D

# Preload the generated scorch texture. Path matches gen_textures output.
const _SCORCH_TEX: Texture2D = preload("res://assets/textures/scorch_decal.png")

## Pool size — capped to keep deferred-pass cost bounded.
@export var pool_size: int = 8
## Seconds for a decal to fully fade from opaque to transparent before recycling.
@export var fade_duration: float = 10.0
## Decal extents (half-size in each axis). Y controls projection depth downward.
@export var decal_extents: Vector3 = Vector3(0.6, 0.5, 0.6)
## Opacity at placement (0–1). Art-director tunable.
@export var peak_albedo_mix: float = 0.85

var _decals: Array[Decal] = []
var _index: int = 0
var _tweens: Array[Tween] = []


func _ready() -> void:
	_tweens.resize(pool_size)
	for i: int in range(pool_size):
		var d: Decal = Decal.new()
		d.texture_albedo = _SCORCH_TEX
		d.size = decal_extents * 2.0
		d.modulate = Color(1.0, 1.0, 1.0, 0.0)
		d.visible = false
		add_child(d)
		_decals.append(d)


## Place the next pooled decal at world position, oriented to project downward.
## Normal is the surface normal at the hit point (default Vector3.UP for floor hits).
func place(world_pos: Vector3, surface_normal: Vector3 = Vector3.UP) -> void:
	var d: Decal = _decals[_index]

	# Cancel any running fade tween on this slot before reusing it.
	if _tweens[_index] != null and _tweens[_index].is_valid():
		_tweens[_index].kill()

	# Orient: Decal projects along its -Y local axis; align to surface normal.
	var surface_basis: Basis = Basis.looking_at(-surface_normal, Vector3.FORWARD)
	d.global_transform = Transform3D(surface_basis, world_pos)
	d.size = decal_extents * 2.0
	d.modulate = Color(1.0, 1.0, 1.0, peak_albedo_mix)
	d.visible = true

	# Fade alpha to 0 over fade_duration, then hide (recycle on next place()).
	var t: Tween = create_tween()
	t.tween_property(d, "modulate:a", 0.0, fade_duration)
	t.tween_callback(d.hide)
	_tweens[_index] = t

	_index = (_index + 1) % pool_size
