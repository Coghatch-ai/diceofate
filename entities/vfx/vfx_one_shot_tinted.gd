# entities/vfx/vfx_one_shot_tinted.gd — VfxOneShot variant: accepts runtime tint via set_tint().
# set_tint() must be called immediately after instantiate() before add_child so _ready sees it.
class_name VfxOneShotTinted
extends Node3D

var _pending_tint: Color = Color.WHITE
var _tint_set: bool = false
@onready var _particles: GPUParticles3D = $Particles


func _ready() -> void:
	_particles.one_shot = true
	_particles.local_coords = false
	if not _particles.finished.is_connected(_on_finished):
		_particles.finished.connect(_on_finished)
	if _tint_set:
		_apply_tint()
	_particles.restart()
	_particles.emitting = true


## Call immediately after instantiate() to set burst color before _ready fires.
func set_tint(tint: Color) -> void:
	_pending_tint = tint
	_tint_set = true
	if is_node_ready() and _particles != null:
		_apply_tint()


func _apply_tint() -> void:
	var mat: ParticleProcessMaterial = _particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	var unique_mat: ParticleProcessMaterial = mat.duplicate() as ParticleProcessMaterial
	_particles.process_material = unique_mat
	var grad: GradientTexture1D = unique_mat.color_ramp as GradientTexture1D
	if grad == null:
		return
	var unique_grad: GradientTexture1D = grad.duplicate() as GradientTexture1D
	unique_mat.color_ramp = unique_grad
	var g: Gradient = unique_grad.gradient
	if g == null:
		return
	var unique_g: Gradient = g.duplicate() as Gradient
	unique_grad.gradient = unique_g
	for i: int in unique_g.get_point_count():
		var c: Color = unique_g.get_color(i)
		var tinted: Color = Color(
			_pending_tint.r * c.r, _pending_tint.g * c.g, _pending_tint.b * c.b, c.a
		)
		unique_g.set_color(i, tinted)


func _on_finished() -> void:
	queue_free()
