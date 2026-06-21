# entities/vfx/vfx_one_shot.gd — one-shot fire-and-free particle burst: emits once, frees on finish.
class_name VfxOneShot
extends Node3D

@onready var _particles: GPUParticles3D = $Particles


func _ready() -> void:
	_particles.one_shot = true
	_particles.local_coords = false
	if not _particles.finished.is_connected(_on_finished):
		_particles.finished.connect(_on_finished)
	_particles.restart()
	_particles.emitting = true


func _on_finished() -> void:
	queue_free()
