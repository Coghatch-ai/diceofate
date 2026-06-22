# entities/vfx/burn_aura_vfx.gd — persistent looping burn/poison aura. Owner frees via extinguish().
class_name BurnAuraVfx
extends Node3D

## Set to true for poison (green tint); false for fire (orange-red).
@export var is_poison: bool = false

@onready var _emitter: GPUParticles3D = $Emitter
@onready var _glow: OmniLight3D = $GlowLight


func _ready() -> void:
	_emitter.one_shot = false
	_emitter.local_coords = true
	_glow.shadow_enabled = false
	if is_poison:
		_apply_poison_tint()
	_emitter.emitting = true


## Owner calls when status expires. Stops emission, fades glow, frees after particle tail.
func extinguish() -> void:
	_emitter.emitting = false
	create_tween().tween_property(_glow, "light_energy", 0.0, 0.3)
	get_tree().create_timer(_emitter.lifetime).timeout.connect(queue_free)


func _apply_poison_tint() -> void:
	var mat: ParticleProcessMaterial = _emitter.process_material as ParticleProcessMaterial
	if mat == null:
		return
	var unique_mat: ParticleProcessMaterial = mat.duplicate() as ParticleProcessMaterial
	_emitter.process_material = unique_mat
	_glow.light_color = Color(0.3, 1.0, 0.2)
