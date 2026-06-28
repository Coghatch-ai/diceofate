# entities/arena/arena_piece.gd — single cover/geometry element in an ArenaLayout.
class_name ArenaPiece
extends Resource

## Geometry role of this piece.
@export var type: ArenaLayout.PieceType = ArenaLayout.PieceType.BOX_FULL_COVER
## World-space centre position (X/Y/Z). Builder sets node.position — never Transform3D.
@export var pos: Vector3 = Vector3.ZERO
## Rotation around the Y axis in radians.
@export_range(-3.15, 3.15, 0.01) var rot_y: float = 0.0
## Bounding box size in metres.
@export var size: Vector3 = Vector3(2.0, 2.0, 2.0)
## Cover height/material class (HALF_HARD, HALF_SOFT, FULL_HARD, FULL_SOFT).
@export var cover_class: ArenaLayout.CoverClass = ArenaLayout.CoverClass.FULL_HARD
## Which lane this piece belongs to (-1 = no lane).
@export var lane_id: int = -1
