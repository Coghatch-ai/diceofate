# entities/components/repulsion_zone/repulsion_zone.gd — pushes CharacterBody3D bodies away.
class_name RepulsionZone
extends Area3D

signal body_repulsed(body: CharacterBody3D)

## Strength of the push force (units per second at the repulsion radius boundary).
@export var strength: float = 12.0
## Radius within which repulsion is active; should match the CollisionShape3D sphere radius.
@export var radius: float = 4.0


func _physics_process(delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		if body is CharacterBody3D:
			_repulse(body as CharacterBody3D, delta)


func _repulse(body: CharacterBody3D, delta: float) -> void:
	var away: Vector3 = body.global_position - global_position
	# Ignore vertical component so the push is horizontal only.
	away.y = 0.0
	var dist: float = away.length()
	if dist < 0.01:
		# Exactly on top — push in an arbitrary direction.
		away = Vector3.RIGHT
		dist = 1.0
	# Scale force: stronger when closer (inverse distance within radius).
	var t: float = clampf(1.0 - dist / radius, 0.0, 1.0)
	var push: Vector3 = away.normalized() * strength * t * delta
	body.velocity.x += push.x
	body.velocity.z += push.z
	emit_signal("body_repulsed", body)
