# tools/lib/target_acquisition.gd — reusable target-acquisition config + stateless acquire() helper.
# First consumer: TurretController. Later: enemy shooter migration (2nd consumer).
class_name TargetAcquisitionConfig
extends Resource

## Selection rule constants — only NEAREST implemented in v1; MOST_CENTRED reserved.
enum SelectionRule { NEAREST = 0, MOST_CENTRED = 1 }

@export_group("Targeting")
## Group name queried for candidates (e.g. "enemies").
@export var target_group: String = "enemies"
## Half-angle of the acquisition cone in degrees. 180° = full 360° sphere (no directional bias).
## The turret rotate-to-aim behaviour makes this moot for coverage — keep 180 for omnidirectional.
@export_range(1.0, 180.0, 1.0) var arc_half_angle_deg: float = 180.0
## Maximum acquisition range in metres.
@export_range(1.0, 200.0, 0.5) var max_range: float = 30.0
## When true a clear line-of-sight (PhysicsRayQueryParameters3D mask=1) is required.
@export var los_required: bool = true
## How to pick among in-arc, in-range, line-of-sight candidates.
@export var selection_rule: SelectionRule = SelectionRule.NEAREST
## Seconds between re-acquisition cycles. 0 = re-acquire every fire cycle.
@export_range(0.0, 10.0, 0.1) var reacquire_interval: float = 0.0


## Stateless acquire: returns the best Node3D in `cfg`'s arc/range/LOS relative to `origin`,
## or null when no valid candidate exists.
##
## Arc math mirrors radar_minimap.gd _world_to_radar():
##   rotate (dx, dz) by -origin.global_rotation.y → rx/rz in player-local space.
##   global_rotation.y = world-space yaw — mandatory when origin is a child node
##   (e.g. the turret Muzzle Marker3D) whose local rotation.y is always 0.
##   "behind" = positive rz (radar's forward-negative convention, behind = +rz).
##   In-arc: abs(atan2(rx, rz_behind)) <= deg_to_rad(arc_half_angle_deg).
##
## LOS mirrors enemy.gd can_see_target(): PhysicsRayQueryParameters3D mask=1 (world layer),
## from origin.global_position to candidate.global_position; hit == null → clear.
static func acquire(origin: Node3D, cfg: TargetAcquisitionConfig) -> Node3D:
	var candidates: Array[Node] = origin.get_tree().get_nodes_in_group(cfg.target_group)
	if candidates.is_empty():
		return null

	# Use global_rotation.y (world-space yaw) so the arc tracks the player body's
	# actual facing even when origin is a child node with local rotation.y == 0.
	var yaw: float = origin.global_rotation.y
	var cos_y: float = cos(-yaw)
	var sin_y: float = sin(-yaw)
	var half_rad: float = deg_to_rad(cfg.arc_half_angle_deg)
	var max_range_sq: float = cfg.max_range * cfg.max_range
	var origin_pos: Vector3 = origin.global_position

	var best: Node3D = null
	var best_dist_sq: float = INF
	var best_angle: float = INF  # for MOST_CENTRED (reserved, not used in v1)

	var space: PhysicsDirectSpaceState3D = origin.get_world_3d().direct_space_state

	for node: Node in candidates:
		if not node is Node3D:
			continue
		if not is_instance_valid(node):
			continue
		# SEAM: node confirmed Node3D above.
		@warning_ignore("unsafe_cast")
		var candidate: Node3D = node as Node3D

		var diff: Vector3 = candidate.global_position - origin_pos
		var dist_sq: float = diff.length_squared()
		if dist_sq > max_range_sq:
			continue

		# Yaw-relative arc test — same rotation as radar_minimap._world_to_radar().
		var dx: float = diff.x
		var dz: float = diff.z
		var rx: float = dx * cos_y - dz * sin_y
		var rz: float = dx * sin_y + dz * cos_y
		# "behind" in radar convention: positive rz means behind the player.
		# atan2(rx, rz) gives angle from the rear axis; abs <= half_rad = in cone.
		var angle: float = abs(atan2(rx, rz))
		if angle > half_rad:
			continue

		# LOS gate via direct space ray (mask=1, world layer).
		if cfg.los_required:
			var query := PhysicsRayQueryParameters3D.create(
				origin_pos, candidate.global_position, 1
			)
			query.hit_back_faces = false
			var result: Dictionary = space.intersect_ray(query)
			# Hit something that is NOT the candidate → occluded.
			if not result.is_empty():
				var collider: Object = result.get("collider", null)
				if collider != candidate:
					continue

		# Selection.
		if cfg.selection_rule == SelectionRule.NEAREST:
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = candidate
		else:
			# MOST_CENTRED — reserved; fall back to nearest for now.
			if angle < best_angle:
				best_angle = angle
				best = candidate

	return best
