# entities/arena/lane_def.gd — a named flow corridor in an ArenaLayout.
class_name LaneDef
extends Resource

## Unique lane identifier (matches ArenaPiece.lane_id).
@export var id: int = 0
## Human-readable lane name (e.g. "left", "centre", "right").
@export var label: String = ""
## World-space waypoints that define the lane centre-line (ordered).
@export var waypoints: Array[Vector3] = []
