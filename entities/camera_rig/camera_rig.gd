extends Node3D

@export var target: Node3D = null
@export var follow_speed: float = 8.0

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Exponential smoothing follow
	var weight = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)
