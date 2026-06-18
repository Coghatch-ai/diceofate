# entities/projectile/projectile.gd - travels along local -Z, despawns on max_range or body hit.
# Magnetism: each physics frame checks for the nearest node in group "magnet" within
# pull_radius; bends heading toward it at pull_strength deg/frame (clamped so it can still miss).
class_name Projectile
extends Area3D

signal hit(target: Node3D)

@export var speed: float = 30.0
@export var max_range: float = 100.0
## Radius (metres) within which a magnetic enemy bends this projectile toward itself.
@export var pull_radius: float = 4.0
## Max degrees of heading correction per physics frame toward the nearest magnet.
@export var pull_strength: float = 4.0

var _travelled: float = 0.0

@onready var _hit_sfx: AudioStreamPlayer = $HitSfx


func _ready() -> void:
	# CONNECT_ONE_SHOT: Area3D can fire body_entered multiple times in the same physics frame
	# before a deferred queue_free() removes the node; one-shot prevents double-hit handling.
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_apply_magnet_steering()
	# Travel along local -Z (forward). top_level is set at spawn so this is world-space motion,
	# independent of whatever fired the projectile.
	var step: float = speed * delta
	global_position += -global_transform.basis.z * step
	_travelled += step
	if _travelled >= max_range:
		queue_free()


## Bend heading toward the nearest magnetic enemy within pull_radius.
## Rotates the projectile's basis so -Z curves toward the magnet; clamped to pull_strength
## degrees so the projectile can still miss if not aimed close enough.
## Target the capsule centre (y+0.9) not the root node floor position so attracted
## bullets actually intersect the collision shape instead of curving under it.
func _apply_magnet_steering() -> void:
	var nearest: Node3D = _find_nearest_magnet()
	if nearest == null:
		return
	var aim_pos: Vector3 = nearest.global_position + Vector3(0.0, 0.9, 0.0)
	var to_magnet: Vector3 = (aim_pos - global_position).normalized()
	var forward: Vector3 = -global_transform.basis.z
	# Angle between current heading and magnet direction.
	var angle: float = forward.angle_to(to_magnet)
	if angle < 0.001:
		return
	# Clamp correction to pull_strength degrees per frame.
	var max_angle: float = deg_to_rad(pull_strength)
	var t: float = minf(max_angle / angle, 1.0)
	var new_forward: Vector3 = forward.slerp(to_magnet, t).normalized()
	# Rebuild basis with corrected forward (-Z) keeping up roughly world-up.
	var new_basis: Basis = Basis.looking_at(-new_forward, Vector3.UP)
	global_transform = Transform3D(new_basis, global_position)


func _find_nearest_magnet() -> Node3D:
	var magnets: Array[Node] = get_tree().get_nodes_in_group("magnet")
	if magnets.is_empty():
		return null
	var nearest: Node3D = null
	var nearest_dist_sq: float = pull_radius * pull_radius
	for node: Node in magnets:
		if not node is Node3D:
			continue
		var magnet_node: Node3D = node as Node3D
		var dist_sq: float = global_position.distance_squared_to(magnet_node.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = magnet_node
	return nearest


func _on_body_entered(body: Node3D) -> void:
	# Report the impact (signals up), then despawn.
	hit.emit(body)
	# SEAM: duck-typed hit notification — any body exposing on_hit() reacts (godot-composition rule).
	# Targets implement on_hit() to take damage; world geometry does not — method guard required.
	if body.has_method("on_hit"):
		# SEAM: method proven present by has_method check above; type not known at compile time.
		@warning_ignore("unsafe_method_access")
		body.on_hit()
	_play_hit_sfx()
	queue_free()


# Reparent the one-shot player to the scene root so it survives queue_free() on this node.
func _play_hit_sfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_hit_sfx.reparent(scene_root)
	# AudioStreamPlayer is non-positional — position irrelevant; just play and auto-free on finish.
	# Guard: reparent can be called while connection already exists if body_entered fires twice.
	if not _hit_sfx.finished.is_connected(_hit_sfx.queue_free):
		_hit_sfx.finished.connect(_hit_sfx.queue_free)
	_hit_sfx.play()
