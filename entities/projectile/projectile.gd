# entities/projectile/projectile.gd - travels along local -Z, despawns on max_range or body hit.
# Magnetism: each physics frame checks for the nearest node in group "magnet" within
# pull_radius; bends heading toward it at pull_strength deg/frame (clamped so it can still miss).
class_name Projectile
extends Area3D

## Emitted on body contact: target body, surface normal, world hit position.
signal hit(target: Node3D, normal: Vector3, hit_pos: Vector3)

@export var speed: float = 30.0
@export var max_range: float = 100.0
## Radius (metres) within which a magnetic enemy bends this projectile toward itself.
@export var pull_radius: float = 4.0
## Max degrees of heading correction per physics frame toward the nearest magnet.
@export var pull_strength: float = 4.0

## Stamped by Gun._fire() after add_child. Setter tints the mesh immediately.
## Null = use bare on_hit() fallback path; mesh keeps scene-default material.
var cast_data: CastData:
	set(value):
		cast_data = value
		if value != null:
			_tint_mesh(value.bullet_color)
## World position of the instigator at fire time; forwarded to GameContext for knockback.
var instigator_pos: Vector3 = Vector3.ZERO

var _travelled: float = 0.0
# Previous-frame world position — used as ray origin so the full travel step is covered.
var _prev_position: Vector3 = Vector3.ZERO

@onready var _hit_sfx: AudioStreamPlayer = $HitSfx


func _ready() -> void:
	_prev_position = global_position
	# CONNECT_ONE_SHOT: Area3D can fire body_entered multiple times in the same physics frame
	# before a deferred queue_free() removes the node; one-shot prevents double-hit handling.
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	_prev_position = global_position
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
	var ray_hit: Dictionary = _raycast_hit(body)
	# SEAM: result values from physics API are Variant; cast guarded in _raycast_hit.
	@warning_ignore("unsafe_cast")
	var normal: Vector3 = ray_hit["normal"] as Vector3
	@warning_ignore("unsafe_cast")
	var hit_position: Vector3 = ray_hit["position"] as Vector3
	# Report the impact (signals up), then despawn.
	hit.emit(body, normal, hit_position)
	if cast_data != null and cast_data.resolver != null:
		# Cast path: build context, resolve targets, apply each effect.
		var ctx := GameContext.new()
		ctx.instigator = self
		ctx.target = body
		ctx.hit_pos = hit_position
		ctx.hit_normal = normal
		ctx.instigator_pos = instigator_pos
		ctx.space = get_world_3d().direct_space_state
		var targets: Array[Node] = cast_data.resolver.resolve(ctx)
		for t: Node in targets:
			for eff: Effect in cast_data.effects:
				eff.apply(t, ctx)
	else:
		# Fallback: bare duck-typed on_hit() — no regression for non-cast weapons.
		# SEAM: duck-typed hit notification — any body exposing on_hit() reacts (godot-composition rule).
		# Targets implement on_hit() to take damage; world geometry does not — method guard required.
		if body.has_method("on_hit"):
			# SEAM: method proven present by has_method check above; type not known at compile time.
			@warning_ignore("unsafe_method_access")
			body.on_hit()
	_play_hit_sfx()
	queue_free()


## Cast a ray from the previous-frame position to the current position, covering the full travel
## step so thick colliders are not missed. Returns a Dictionary with "normal" (Vector3) and
## "position" (Vector3). Falls back to negated travel direction + projectile position on miss.
## collision_mask matches the projectile's own mask so ignored layers don't hijack normal lookup.
func _raycast_hit(body: Node3D) -> Dictionary:
	var travel_dir: Vector3 = -global_transform.basis.z
	var fallback_normal: Vector3 = -travel_dir
	var fallback_pos: Vector3 = global_position
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# Cast from previous-frame position to current position — covers the full travel step.
	var query := PhysicsRayQueryParameters3D.create(_prev_position, global_position)
	# Match the projectile's collision mask so ignored layers don't produce false hits.
	query.collision_mask = collision_mask
	# Exclude the projectile's own RID (belt-and-suspenders; it is an Area3D).
	query.exclude = [get_rid()]
	# Allow detecting from inside thick colliders (e.g. large static bodies).
	query.hit_from_inside = true
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return {"normal": fallback_normal, "position": fallback_pos}
	# Verify the ray hit the triggering body (not a coincident shape on a different layer).
	# SEAM: result["collider"] is Variant from physics API; checked by identity before use.
	@warning_ignore("unsafe_cast")
	var hit_body: Node3D = result["collider"] as Node3D
	if hit_body == null or hit_body != body:
		return {"normal": fallback_normal, "position": fallback_pos}
	# SEAM: result keys are Variant from physics API; known to be Vector3 per Godot docs.
	@warning_ignore("unsafe_cast")
	var hit_normal: Vector3 = result["normal"] as Vector3
	@warning_ignore("unsafe_cast")
	var hit_pos: Vector3 = result["position"] as Vector3
	return {"normal": hit_normal, "position": hit_pos}


## Tint the projectile mesh to bullet_color on cast_data stamp.
## Walks all MeshInstance3D descendants, make-unique each material so instances don't share.
func _tint_mesh(color: Color) -> void:
	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for node: Node in meshes:
		if not node is MeshInstance3D:
			continue
		var mi: MeshInstance3D = node as MeshInstance3D
		# Get active material (surface override or mesh default) and duplicate it.
		var src: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if src == null:
			continue
		var mat: StandardMaterial3D = src.duplicate() as StandardMaterial3D
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mi.set_surface_override_material(0, mat)


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
