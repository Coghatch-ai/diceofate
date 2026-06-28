# tools/lib/resource_registry.gd — generic StringName-keyed Resource catalog over a .tres folder
class_name ResourceRegistry
extends Resource

## Generic dir-scan registry. Subclass per family: declare FOLDER + add typed accessor.
## Not an autoload — hold via @export or preload (godot-composition).

## Subclass declares its OWN const FOLDER — _folder() reads it via get_script_constant_map().
## Base fallback (empty) used only when subclass omits it.
const _BASE_FOLDER: String = ""

var _by_id: Dictionary[StringName, Resource] = {}
var _loaded: bool = false


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var folder: String = _folder()
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		push_error("ResourceRegistry: cannot open '%s'" % folder)
		return
	for file_name: String in dir.get_files():
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var res: Resource = ResourceLoader.load(folder.path_join(file_name))
		if res == null:
			continue
		var rid: StringName = _id_of(res)
		if rid == &"":
			push_error("ResourceRegistry: '%s' has empty id — skipped" % file_name)
			continue
		if _by_id.has(rid):
			push_error("ResourceRegistry: duplicate id '%s' in '%s'" % [rid, file_name])
			continue
		_by_id[rid] = res


## Reads the subclass's FOLDER const via get_script_constant_map().
func _folder() -> String:
	# SEAM: get_script() returns Variant; cast to GDScript to call constant_map.
	@warning_ignore("unsafe_cast")
	var script: GDScript = get_script() as GDScript
	var folder: String = script.get_script_constant_map().get("FOLDER", _BASE_FOLDER)
	return folder


## Pulls id off a scanned Resource via duck-typed get().
func _id_of(res: Resource) -> StringName:
	if not (&"id" in res):
		return &""
	# SEAM: duck-typed id field — Resource.get() returns Variant.
	@warning_ignore("unsafe_cast")
	return res.get(&"id") as StringName


## Fatal on missing id — typo must never silently yield null.
func get_by_id(id: StringName) -> Resource:
	_ensure_loaded()
	assert(_by_id.has(id), "ResourceRegistry: unknown id '%s'" % id)
	return _by_id[id]


func has_id(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)


func ids() -> Array[StringName]:
	_ensure_loaded()
	return _by_id.keys()
