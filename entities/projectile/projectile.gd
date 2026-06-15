# entities/projectile/projectile.gd - travels along local -Z, despawns on max_range or body hit.
class_name Projectile
extends Area3D

signal hit(target: Node3D)

@export var speed: float = 30.0
@export var max_range: float = 100.0

var _travelled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Travel along local -Z (forward). top_level is set at spawn so this is world-space motion,
	# independent of whatever fired the projectile.
	var step: float = speed * delta
	global_position += -global_transform.basis.z * step
	_travelled += step
	if _travelled >= max_range:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	# Report the impact (signals up), then despawn.
	hit.emit(body)
	# SEAM: duck-typed hit notification — any body exposing on_hit() reacts (godot-composition rule).
	# Targets implement on_hit() to despawn; world geometry does not, so the method guard is needed.
	if body.has_method("on_hit"):
		# SEAM: method proven present by has_method check above; type not known at compile time.
		@warning_ignore("unsafe_method_access")
		body.on_hit()
	queue_free()
