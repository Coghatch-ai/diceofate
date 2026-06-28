# entities/arena/arena_layout.gd — typed data resources for arena blockout layouts.
class_name ArenaLayout
extends Resource

## Piece type: geometry role of a cover element.
enum PieceType {
	BOX_FULL_COVER = 0,
	BOX_HALF_COVER = 1,
	RAMP = 2,
	PLATFORM = 3,
	DROPDOWN = 4,
	WALL_PARTITION = 5,
	SOFT_COVER = 6,
}

## Cover class: height × material hardness.
enum CoverClass {
	HALF_HARD = 0,
	HALF_SOFT = 1,
	FULL_HARD = 2,
	FULL_SOFT = 3,
}

## Arena footprint in metres (X = width, Y = depth).
@export var footprint_m: Vector2 = Vector2(30.0, 30.0)
## Y coordinate of the ground floor.
@export var floor_y: float = 0.0
## Whether the builder should emit perimeter walls.
@export var perimeter_walls: bool = true
## Cover and geometry pieces.
@export var pieces: Array[ArenaPiece] = []
## World-space spawn positions (player + enemy markers).
@export var spawn_markers: Array[Vector3] = []
## Axis-aligned bounding boxes for fall-hazard zones.
@export var fall_zones: Array[AABB] = []
## Lane corridors defining the flow topology.
@export var lanes: Array[LaneDef] = []
## Landmark sub-regions for orientation and colour coding.
@export var landmarks: Array[LandmarkDef] = []
