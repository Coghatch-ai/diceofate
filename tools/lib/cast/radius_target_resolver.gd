# tools/lib/cast/radius_target_resolver.gd — AoE resolver: all enemies within radius of hit point.
# Uses sphere intersect_shape against the enemy collision layer (layer 4 = bit 3 = value 8).
# ctx.space must be filled (Projectile does this via get_world_3d().direct_space_state).
# Fallback when space is null: group-based distance check against "enemies" group —
# allows headless smoke tests to assert multi-target behaviour without a physics world.
class_name RadiusTargetResolver
extends TargetResolver

## Enemy collision layer bitmask (layer 4 = bit 3 = 8). Matches enemy.tscn collision_layer.
const ENEMY_LAYER: int = 8

## Blast radius in metres. Default 3.0.
@export var radius: float = 3.0


func resolve(ctx: GameContext) -> Array[Node]:
	if ctx.space != null:
		return _resolve_physics(ctx)
	return _resolve_group_fallback(ctx)


## Primary path: sphere intersect_shape via PhysicsDirectSpaceState3D.
## Returns all unique PhysicsBody3D nodes within radius of ctx.hit_pos that expose apply_damage.
func _resolve_physics(ctx: GameContext) -> Array[Node]:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, ctx.hit_pos)
	query.collision_mask = ENEMY_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits: Array[Dictionary] = ctx.space.intersect_shape(query, 32)
	var out: Array[Node] = []
	var seen: Dictionary = {}
	for hit: Dictionary in hits:
		# SEAM: result["collider"] is Variant from physics API; guarded before use.
		@warning_ignore("unsafe_cast")
		var body: Node = hit["collider"] as Node
		if body == null:
			continue
		if seen.has(body):
			continue
		if not body.has_method("apply_damage"):
			continue
		seen[body] = true
		out.append(body)
	return out


## Fallback path: group distance check — used when space is null (headless smoke, no physics world).
## Walks the "enemies" group, returns nodes within radius that expose apply_damage.
func _resolve_group_fallback(ctx: GameContext) -> Array[Node]:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return []
	var out: Array[Node] = []
	var seen: Dictionary = {}
	for node: Node in scene_tree.get_nodes_in_group("enemies"):
		if seen.has(node):
			continue
		if not node.has_method("apply_damage"):
			continue
		if not node is Node3D:
			continue
		# SEAM: node proven Node3D by is check above.
		@warning_ignore("unsafe_cast")
		var n3d: Node3D = node as Node3D
		var dist: float = ctx.hit_pos.distance_to(n3d.global_position)
		if dist <= radius:
			seen[node] = true
			out.append(node)
	return out
