# entities/hud/radar_minimap.gd — circular radar HUD; player fixed at centre, enemies rotate
# by player yaw so "down" = behind. Reads all behaviour from MinimapConfig (.tres).
class_name RadarMinimap
extends Control

## Swap to a different .tres to retune without code changes.
@export var config: MinimapConfig

## Injected by main.gd after level load (same pattern as crosshair/ammo wiring).
var _player: Node3D = null


func _ready() -> void:
	if config == null:
		push_error("RadarMinimap: config not assigned")
		return
	var sz: float = config.radar_size
	custom_minimum_size = Vector2(sz, sz)
	size = Vector2(sz, sz)
	set_process(true)


func set_player(player: Node3D) -> void:
	_player = player


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if config == null:
		return
	var radius: float = config.radar_size * 0.5
	var centre: Vector2 = Vector2(radius, radius)

	# Background fill.
	draw_circle(centre, radius, config.background_color)

	# Ring border — draw_arc approximation using many-sided polygon.
	_draw_ring(centre, radius, config.ring_color, config.ring_width)

	if _player == null:
		return

	var player_pos: Vector3 = _player.global_position
	# Player yaw: rotation.y in Godot FPS = rotation around Y axis.
	# We rotate blip offsets by -yaw so "up" on radar = player forward.
	var yaw: float = _player.rotation.y

	# Tracked group blips.
	for entry: MinimapTrackedGroup in config.tracked_groups:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(entry.group_name)
		for node: Node in nodes:
			if not node is Node3D:
				continue
			# SEAM: node is confirmed Node3D above; cast safe.
			@warning_ignore("unsafe_cast")
			var node3d: Node3D = node as Node3D
			if not is_instance_valid(node3d):
				continue
			var blip_pos: Vector2 = _world_to_radar(node3d.global_position, player_pos, yaw, radius)
			if blip_pos == Vector2.ZERO and not config.clamp_to_edge:
				continue
			draw_circle(centre + blip_pos, entry.blip_radius, entry.blip_color)

	# Player blip at centre.
	draw_circle(centre, config.player_radius, config.player_color)

	# Facing tick (points up = forward in radar space).
	if config.show_facing_tick:
		var tick_end: Vector2 = centre + Vector2(0.0, -config.facing_tick_length)
		draw_line(centre, tick_end, config.player_color, 2.0)


## Convert a world-space position to radar-local 2D offset.
## Returns Vector2.ZERO (sentinel) when out of range AND clamp_to_edge is false.
func _world_to_radar(
	world_pos: Vector3, player_pos: Vector3, yaw: float, radar_radius: float
) -> Vector2:
	var dx: float = world_pos.x - player_pos.x
	var dz: float = world_pos.z - player_pos.z

	# Rotate by -yaw so player forward (−Z in Godot) maps to "up" (−Y) on screen.
	var cos_y: float = cos(-yaw)
	var sin_y: float = sin(-yaw)
	var rx: float = dx * cos_y - dz * sin_y
	var rz: float = dx * sin_y + dz * cos_y

	# Scale: world detection_range maps to radar_radius pixels.
	var px_scale: float = radar_radius / config.detection_range
	var sx: float = rx * px_scale
	# rz negative = forward = up on screen (screen Y grows down).
	var sy: float = rz * px_scale

	var dist_px: float = sqrt(sx * sx + sy * sy)
	if dist_px > radar_radius:
		if not config.clamp_to_edge:
			# Sentinel: caller skips this blip.
			return Vector2.ZERO
		# Clamp to ring edge.
		var norm: float = radar_radius / dist_px
		sx *= norm
		sy *= norm

	return Vector2(sx, sy)


## Draw a ring border using a thin annulus of triangles (draw_arc unavailable on Control).
func _draw_ring(centre: Vector2, radius: float, color: Color, width: float) -> void:
	var inner: float = radius - width
	var steps: int = 64
	for i: int in range(steps):
		var a0: float = (float(i) / float(steps)) * TAU
		var a1: float = (float(i + 1) / float(steps)) * TAU
		var p0_out: Vector2 = centre + Vector2(cos(a0), sin(a0)) * radius
		var p1_out: Vector2 = centre + Vector2(cos(a1), sin(a1)) * radius
		var p0_in: Vector2 = centre + Vector2(cos(a0), sin(a0)) * inner
		var p1_in: Vector2 = centre + Vector2(cos(a1), sin(a1)) * inner
		var quad: PackedVector2Array = PackedVector2Array([p0_in, p0_out, p1_out, p1_in])
		draw_colored_polygon(quad, color)
