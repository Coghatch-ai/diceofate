# levels/shared_apartment_importer.gd — author-time GridMap importer for the shared apartment level.
## @tool script: set rebuild = true in the inspector to repopulate cells from
## levels/drawn/current.json, then save the scene. Never runs at runtime.
@tool
class_name SharedApartmentImporter
extends GridMap

## MeshLibrary item IDs — must match resources/apartment_tiles.meshlib.tres order.
const ITEM_WALL_KITCHEN: int = 0
const ITEM_WALL_TWIN: int = 1
const ITEM_WALL_MASTER: int = 2
const ITEM_WALL_HALL: int = 3
const ITEM_WALL_BATH: int = 4
const ITEM_WALL_DEFAULT: int = 5
const ITEM_WINDOW_SILL: int = 6

## Grid structure codes (levels/drawn/current.json).
const CODE_FLOOR: int = 0
const CODE_WALL: int = 1
const CODE_DOOR: int = 2
const CODE_WINDOW: int = 3
const CODE_ITEM: int = 4

## Room id → wall tile id mapping (room ids come from the grid JSON rooms list).
const ROOM_TILE: Dictionary = {
	10: ITEM_WALL_KITCHEN,
	20: ITEM_WALL_TWIN,
	30: ITEM_WALL_MASTER,
	40: ITEM_WALL_BATH,
	50: ITEM_WALL_HALL,
	60: ITEM_WALL_HALL,
}

## Set to true in the inspector to repopulate the GridMap from the grid JSON.
## Flip back to false before committing (it resets automatically after a rebuild).
@export var rebuild: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_build_from_grid()
			rebuild = false


func _build_from_grid() -> void:
	if mesh_library == null:
		push_error("SharedApartmentImporter: assign the MeshLibrary before rebuilding.")
		return

	var file: FileAccess = FileAccess.open("res://levels/drawn/current.json", FileAccess.READ)
	if file == null:
		push_error("SharedApartmentImporter: could not open levels/drawn/current.json")
		return

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("SharedApartmentImporter: JSON parse failed.")
		return

	# SEAM: JSON.parse_string returns untyped Variant; type checked above.
	@warning_ignore("unsafe_cast")
	var grid: Dictionary = parsed as Dictionary
	# SEAM: JSON array entries are untyped Variants from JSON.parse_string.
	@warning_ignore("unsafe_cast")
	var w: int = int(grid["width"] as float)
	@warning_ignore("unsafe_cast")
	var cells_raw: Array = grid["cells"] as Array
	@warning_ignore("unsafe_cast")
	var rooms_raw: Array = grid["rooms"] as Array

	# Build a flat room lookup: key = col * 10000 + row → room_id.
	var room_lookup: Dictionary = {}
	for entry: Variant in rooms_raw:
		# SEAM: JSON object entries are untyped Variants.
		@warning_ignore("unsafe_cast")
		var r: Dictionary = entry as Dictionary
		@warning_ignore("unsafe_cast")
		var rx: int = int(r["x"] as float)
		@warning_ignore("unsafe_cast")
		var ry: int = int(r["y"] as float)
		@warning_ignore("unsafe_cast")
		var rid: int = int(r["id"] as float)
		room_lookup[rx * 10000 + ry] = rid

	clear()

	for i: int in range(cells_raw.size()):
		@warning_ignore("unsafe_cast")
		var code: int = int(cells_raw[i] as float)
		if code == CODE_FLOOR or code == CODE_DOOR or code == CODE_ITEM:
			continue
		var col: int = i % w
		# Integer division is intentional: row index from flat array.
		@warning_ignore("integer_division")
		var row: int = i / w
		var item_id: int = _item_for(code, col, row, room_lookup)
		if item_id >= 0:
			set_cell_item(Vector3i(col, 0, row), item_id)

	print("SharedApartmentImporter: rebuilt ", get_used_cells().size(), " cells.")


func _item_for(code: int, col: int, row: int, room_lookup: Dictionary) -> int:
	if code == CODE_WINDOW:
		return ITEM_WINDOW_SILL
	if code == CODE_WALL:
		var key: int = col * 10000 + row
		if room_lookup.has(key):
			@warning_ignore("unsafe_cast")
			var room_id: int = int(room_lookup[key] as float)
			if ROOM_TILE.has(room_id):
				@warning_ignore("unsafe_cast")
				return int(ROOM_TILE[room_id] as float)
		return ITEM_WALL_DEFAULT
	return -1
