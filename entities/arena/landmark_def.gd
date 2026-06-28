# entities/arena/landmark_def.gd — a named sub-region landmark in an ArenaLayout.
class_name LandmarkDef
extends Resource

## Unique landmark identifier.
@export var id: int = 0
## Human-readable name used for orientation (e.g. "red_box", "bridge", "pit").
@export var label: String = ""
## World-space centre of this region (used by the audit for sightline + density checks).
@export var centre: Vector3 = Vector3.ZERO
## Greybox colour for this region (distinct per landmark for visual orientation).
@export var colour: Color = Color(0.5, 0.5, 0.5)
## Approximate radius in metres (used by audit proximity checks).
@export_range(0.5, 50.0, 0.5) var radius: float = 5.0
