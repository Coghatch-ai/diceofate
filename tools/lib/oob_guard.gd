# tools/lib/oob_guard.gd — static helper: add an out-of-bounds ceiling Area3D to a level.
# Reusable across any GridMap-based level: call add_oob_guard() in the level builder,
# then connect OobGuard.body_entered to the level's existing fall/respawn handler in _ready().
class_name OobGuard
extends RefCounted

## Height above wall tops where the OOB sensor sits (metres).
## Just above wall-top so standing on a wall enters the sensor,
## yet well above the jump apex from any intended walkable surface.
const GUARD_MARGIN: float = 0.3
## Sensor slab thickness (metres).
const GUARD_THICKNESS: float = 0.5


## Add an "OobGuard" Area3D to `scene_root` covering the full arena footprint at height
## wall_height + GUARD_MARGIN.  One volume catches all wall tops — no per-wall setup.
##
## Parameters:
##   scene_root   — the level Node3D the builder is populating
##   arena_width  — world X extent  (e.g. GRID_W * CELL_X)
##   arena_depth  — world Z extent  (e.g. GRID_H * CELL_Z)
##   wall_height  — wall top in world Y  (e.g. 3.5 m)
##   player_mask  — collision mask for the player body (default 2 = layer 2)
##
## Returns the created Area3D so the caller can connect body_entered.
static func add_oob_guard(
	scene_root: Node3D,
	arena_width: float,
	arena_depth: float,
	wall_height: float,
	player_mask: int = 2,
) -> Area3D:
	var trigger_y: float = wall_height + GUARD_MARGIN + GUARD_THICKNESS * 0.5
	var area: Area3D = Area3D.new()
	area.name = "OobGuard"
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = player_mask
	scene_root.add_child(area)
	area.owner = scene_root.owner if scene_root.owner != null else scene_root
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(arena_width, GUARD_THICKNESS, arena_depth)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "OobGuardShape"
	col.shape = box
	col.position = Vector3(arena_width * 0.5, trigger_y, arena_depth * 0.5)
	area.add_child(col)
	col.owner = scene_root.owner if scene_root.owner != null else scene_root
	return area
