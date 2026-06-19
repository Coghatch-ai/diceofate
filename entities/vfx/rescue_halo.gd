# entities/vfx/rescue_halo.gd — celebratory saved-NPC halo: green light pulse + rising particles.
class_name RescueHalo
extends Node3D

## Tunable exports — art-director pass can adjust without touching the scene.
@export var light_peak_energy: float = 6.0
@export var light_pulse_duration: float = 0.5
## Halo colour (default: ArtStyle.SAVED_GREEN_CORE = Color(0.18, 0.72, 0.28)).
@export var halo_color: Color = Color(0.18, 0.72, 0.28)

@onready var _particles: GPUParticles3D = $Particles
@onready var _light: OmniLight3D = $HaloLight


func _ready() -> void:
	_light.light_color = halo_color
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_particles.one_shot = true
	_particles.local_coords = false
	if not _particles.finished.is_connected(_on_particles_finished):
		_particles.finished.connect(_on_particles_finished)
	_particles.restart()
	_particles.emitting = true
	_pulse_light()


func _pulse_light() -> void:
	var t: Tween = create_tween()
	t.tween_property(_light, "light_energy", light_peak_energy, 0.08)
	t.tween_property(_light, "light_energy", 0.0, light_pulse_duration)


func _on_particles_finished() -> void:
	queue_free()
