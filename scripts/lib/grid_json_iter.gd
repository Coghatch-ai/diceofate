# scripts/lib/grid_json_iter.gd — shared JSON grid iteration helpers for level builders.
class_name GridJsonIter
extends RefCounted


## Filter grid["items"] array by id, extracting x/y grid coords and computing world positions.
## Returns Array[GridCell] of matching cells (cx, cy, wx, wz world coords).
static func iter_items_by_id(
	grid: Dictionary, target_id: int, cell_x: float, cell_z: float
) -> Array[GridCell]:
	var results: Array[GridCell] = []
	# SEAM: JSON.parse_string returns Variant; unsafe_cast required for strict mode.
	@warning_ignore("unsafe_cast")
	var raw_items: Array = grid["items"] as Array

	for entry: Variant in raw_items:
		@warning_ignore("unsafe_cast")
		var item: Dictionary = entry as Dictionary
		@warning_ignore("unsafe_cast")
		var item_id: int = int(item["id"] as float)
		if item_id != target_id:
			continue
		@warning_ignore("unsafe_cast")
		var cx: int = int(item["x"] as float)
		@warning_ignore("unsafe_cast")
		var cy: int = int(item["y"] as float)
		var wx: float = float(cx) * cell_x + cell_x * 0.5
		var wz: float = float(cy) * cell_z + cell_z * 0.5
		results.append(GridCell.new(cx, cy, wx, wz))

	return results


## Data-only struct for grid cell (grid coords + world coords).
class GridCell:
	var cx: int
	var cy: int
	var wx: float
	var wz: float

	func _init(p_cx: int, p_cy: int, p_wx: float, p_wz: float) -> void:
		cx = p_cx
		cy = p_cy
		wx = p_wx
		wz = p_wz
