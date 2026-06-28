# tools/check_scene_node_clash.gd — headless detector: finds editor "node name clash" bugs.
# For each instanced sub-scene node in a .tscn, compares editor-added child names against
# the names defined INSIDE that sub-scene. Reports every collision.
# Usage: $GODOT --headless --path . --script tools/check_scene_node_clash.gd -- [scene.tscn ...]
# If no args given, scans levels/*.tscn.
# Exit 0 = clean; exit 1 = clashes found.
extends SceneTree

const DEFAULT_PATTERNS: Array[String] = ["res://levels/*.tscn"]

var _clashes: int = 0


func _init() -> void:
	var targets: Array[String] = _resolve_targets()
	for path: String in targets:
		_check_scene(path)
	if _clashes == 0:
		print("CLASH-CHECK: OK — all scenes clean")
		quit(0)
	else:
		print("CLASH-CHECK: FAIL — %d clash(es) found" % _clashes)
		quit(1)


func _resolve_targets() -> Array[String]:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: Array[String] = []
	if args.size() > 0:
		for a: String in args:
			if a.begins_with("res://"):
				out.append(a)
			else:
				out.append("res://" + a)
		return out
	# Default: scan levels/
	var dir: DirAccess = DirAccess.open("res://levels")
	if dir == null:
		push_error("CLASH-CHECK: cannot open res://levels/")
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tscn"):
			out.append("res://levels/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return out


# Parse a .tscn text file into a minimal node-tree representation.
# Returns Array of Dictionaries:
#   { name, parent, is_instance, instance_path, type }
func _parse_tscn_nodes(path: String) -> Array[Dictionary]:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		push_error("CLASH-CHECK: cannot open %s" % path)
		return []
	var text: String = fa.get_as_text()
	fa.close()

	var nodes: Array[Dictionary] = []
	# Match [node ...] header lines.
	var re: RegEx = RegEx.new()
	# Matches the full [node ...] line.
	re.compile("\\[node ([^\\]]+)\\]")
	var attr_re: RegEx = RegEx.new()
	attr_re.compile('(\\w+)=("(?:[^"\\\\]|\\\\.)*"|[^ \\]]+)')

	var lines: PackedStringArray = text.split("\n")
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i].strip_edges()
		var m: RegExMatch = re.search(line)
		if m != null:
			var attrs_str: String = m.get_string(1)
			var attrs: Dictionary = {}
			var am: RegExMatch = attr_re.search(attrs_str)
			while am != null:
				var key: String = am.get_string(1)
				var val: String = am.get_string(2).strip_edges().trim_prefix('"').trim_suffix('"')
				attrs[key] = val
				am = attr_re.search(attrs_str, am.get_end())

			# Collect instance= and type= from subsequent property lines until next [block].
			var instance_path: String = ""
			var j: int = i + 1
			while j < lines.size():
				var pline: String = lines[j].strip_edges()
				if pline.begins_with("["):
					break
				if pline.begins_with("instance = ExtResource("):
					# extract the id string
					var id_re: RegEx = RegEx.new()
					id_re.compile('ExtResource\\("([^"]+)"\\)')
					var id_m: RegExMatch = id_re.search(pline)
					if id_m != null:
						instance_path = id_m.get_string(1)
				j += 1

			var node_name: String = attrs.get("name", "")
			var node_parent: String = attrs.get("parent", "")
			var node_type: String = attrs.get("type", "")
			# instance= can appear inline in the [node] header too
			var inline_instance: String = attrs.get("instance", "")
			if inline_instance != "":
				# strip ExtResource("X") wrapper
				var idr: RegEx = RegEx.new()
				idr.compile('ExtResource\\("([^"]+)"\\)')
				var idm: RegExMatch = idr.search(inline_instance)
				if idm != null:
					instance_path = idm.get_string(1)

			(
				nodes
				. append(
					{
						name = node_name,
						parent = node_parent,
						type = node_type,
						instance_res_id = instance_path,
					}
				)
			)
		i += 1
	return nodes


# Resolve ExtResource id -> path from a .tscn text.
func _parse_ext_resources(path: String) -> Dictionary:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {}
	var text: String = fa.get_as_text()
	fa.close()
	var out: Dictionary = {}
	# Two alternates: id-before-path and path-before-id attribute ordering.
	var pat_a: String = '\\[ext_resource[^\\]]*id="([^"]+)"[^\\]]*path="([^"]+)"[^\\]]*\\]'
	var pat_b: String = '\\[ext_resource[^\\]]*path="([^"]+)"[^\\]]*id="([^"]+)"[^\\]]*\\]'
	var re: RegEx = RegEx.new()
	re.compile(pat_a + "|" + pat_b)
	var results: Array[RegExMatch] = re.search_all(text)
	for rm: RegExMatch in results:
		var id1: String = rm.get_string(1)
		var p1: String = rm.get_string(2)
		var p2: String = rm.get_string(3)
		var id2: String = rm.get_string(4)
		if id1 != "" and p1 != "":
			out[id1] = p1
		elif id2 != "" and p2 != "":
			out[id2] = p2
	return out


# Get direct child node names defined inside a PackedScene (one level deep only).
func _get_packed_scene_child_names(scene_path: String) -> Array[String]:
	var out: Array[String] = []
	if not ResourceLoader.exists(scene_path):
		return out
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		return out
	var state: SceneState = ps.get_state()
	# node 0 = root; collect names of nodes whose parent index == 0
	for ni: int in range(state.get_node_count()):
		if state.get_node_path(ni) == ^".":
			continue  # skip root
		# Check if direct child of root: path has exactly one component
		var np: NodePath = state.get_node_path(ni)
		if np.get_name_count() == 1:
			out.append(np.get_name(0))
	return out


func _check_scene(scene_path: String) -> void:
	var ext_resources: Dictionary = _parse_ext_resources(scene_path)
	var nodes: Array[Dictionary] = _parse_tscn_nodes(scene_path)

	# Build map: parent_name -> [child names added in THIS scene]
	# An instanced node (has instance_res_id, parent != "") is a top-level instance child.
	# We need: for each node N that is itself an instance OR is a plain node,
	# find nodes whose parent == N.name and N is an instance.

	# First: collect which node names are instances (have instance_res_id) at root level.
	var instance_nodes: Dictionary = {}  # node_name -> resolved scene path
	for nd: Dictionary in nodes:
		var res_id: String = nd["instance_res_id"]
		if res_id != "":
			var res_path: String = ext_resources.get(res_id, "")
			if res_path != "" and res_path.ends_with(".tscn"):
				instance_nodes[nd["name"]] = res_path

	# For each instance node, find editor-added children (nodes with parent == instance_name).
	for inst_name: String in instance_nodes:
		var inst_scene_path: String = instance_nodes[inst_name]
		var internal_names: Array[String] = _get_packed_scene_child_names(inst_scene_path)
		if internal_names.is_empty():
			continue

		# Collect editor-added children under this instance.
		var added_children: Array[String] = []
		for nd: Dictionary in nodes:
			if nd["parent"] == inst_name:
				added_children.append(nd["name"])

		# Also handle parent="." sub-instances (root-level instances in pickup_health pattern):
		# pickup_health root IS the instance (parent="." means child of root).
		# For that pattern: the instance is the ROOT node (parent=".") and added children
		# have parent=".". Handled above since inst_name will match.

		for child_name: String in added_children:
			if child_name in internal_names:
				print(
					(
						"CLASH: %s — instance '%s' (from %s) already defines child '%s'"
						% [scene_path, inst_name, inst_scene_path, child_name]
					)
				)
				_clashes += 1

	# Special case: root node itself is an instance (inherited scene pattern like pickup_health).
	# The root [node] has instance= and parent="" (absent). Children have parent=".".
	# We already handle this above because inst_name will be the root node name,
	# and children with parent="." match parent == inst_name only if inst_name == ".".
	# Need separate handling: find nodes where the SCENE ROOT is an instance.
	for nd: Dictionary in nodes:
		var res_id: String = nd["instance_res_id"]
		if res_id != "" and nd["parent"] == "":
			# This IS the root instance (inherited scene).
			var inst_scene_path: String = ext_resources.get(res_id, "")
			if inst_scene_path == "" or not inst_scene_path.ends_with(".tscn"):
				continue
			var internal_names: Array[String] = _get_packed_scene_child_names(inst_scene_path)
			if internal_names.is_empty():
				continue
			var root_name: String = nd["name"]
			# Editor-added children have parent="."
			for child_nd: Dictionary in nodes:
				if child_nd["parent"] == ".":
					var child_name: String = child_nd["name"]
					if child_name in internal_names:
						print(
							(
								"CLASH: %s — root instance '%s' (from %s) already defines child '%s'"
								% [scene_path, root_name, inst_scene_path, child_name]
							)
						)
						_clashes += 1
