# entities/camera_rig/camera_rig.gd — orthographic fixed-angle rig: smooth follow + Q/E yaw.
class_name CameraRig
extends Node3D

@export var target: Node3D = null
@export var follow_speed: float = 8.0
@export var rotation_speed_degrees: float = 90.0
@export var allow_full_rotation: bool = true
@export var min_yaw_degrees: float = -45.0
@export var max_yaw_degrees: float = 45.0


func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Exponential smoothing follow
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, weight)


func get_yaw_radians() -> float:
	return deg_to_rad(rotation_degrees.y)
