# tools/gen_models.gd — headless procedural low-poly .glb generator (prototype placeholders).
## Run:  $GODOT --headless --path . --script tools/gen_models.gd
##  then: $GODOT --headless --path . --import
## Reusable: add a spec to _props and re-run. Output: assets/models/<name>.glb.
@tool
extends SceneTree

# A small consistent wood/neutral palette shared across the placeholder props.
const WOOD_DARK: Color = Color(0.36, 0.24, 0.14, 1.0)
const WOOD_MID: Color = Color(0.52, 0.36, 0.22, 1.0)
const WOOD_LIGHT: Color = Color(0.62, 0.46, 0.30, 1.0)
const METAL_GREY: Color = Color(0.55, 0.55, 0.58, 1.0)
const SHADE_CREAM: Color = Color(0.90, 0.86, 0.74, 1.0)
const LEAF_GREEN: Color = Color(0.30, 0.50, 0.25, 1.0)

# _props is a var (not const): Vector3/Color are not constant expressions in GDScript.
# Adding a prop = adding an entry here; a new primitive kind = one match case in _build_part.
var _props: Array[Dictionary] = [
	{
		# desk — thin top slab + 4 leg boxes (~1.2 x 0.75 x 0.7).
		"name": "desk",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(1.2, 0.05, 0.7),
				"pos": Vector3(0.0, 0.725, 0.0),
				"color": WOOD_LIGHT,
			},
			{
				"shape": "box",
				"size": Vector3(0.06, 0.7, 0.06),
				"pos": Vector3(-0.54, 0.35, -0.30),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.06, 0.7, 0.06),
				"pos": Vector3(0.54, 0.35, -0.30),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.06, 0.7, 0.06),
				"pos": Vector3(-0.54, 0.35, 0.30),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.06, 0.7, 0.06),
				"pos": Vector3(0.54, 0.35, 0.30),
				"color": WOOD_MID,
			},
		],
	},
	{
		# nightstand — body box + a thin drawer-front box on the front (+z) face (~0.7 x 0.6 x 0.7).
		"name": "nightstand",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.7, 0.6, 0.7),
				"pos": Vector3(0.0, 0.3, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.6, 0.4, 0.03),
				"pos": Vector3(0.0, 0.32, 0.35),
				"color": WOOD_LIGHT,
			},
		],
	},
	{
		# wardrobe — body box + 2 door-panel boxes on the front (+z) face (~1.5 x 2 x 3).
		"name": "wardrobe",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(1.5, 2.0, 3.0),
				"pos": Vector3(0.0, 1.0, 0.0),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.7, 1.9, 0.04),
				"pos": Vector3(-0.36, 1.0, 1.5),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.7, 1.9, 0.04),
				"pos": Vector3(0.36, 1.0, 1.5),
				"color": WOOD_MID,
			},
		],
	},
	{
		# single_bed — frame box + mattress box + headboard box (~1.05 x 0.70 x 2.05).
		# Authored at real-world proportions so it instances at uniform scale ~(1,1,1).
		# Frame bottom sits at Y=0 (frame pos.y 0.15 - size.y 0.30/2 = 0).
		# Headboard at -Z so a 0-deg placement reads head-at-top when bed runs along Z.
		"name": "single_bed",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(1.05, 0.30, 2.05),
				"pos": Vector3(0.0, 0.15, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(1.0, 0.22, 1.85),
				"pos": Vector3(0.0, 0.41, 0.05),
				"color": SHADE_CREAM,
			},
			{
				"shape": "box",
				"size": Vector3(1.05, 0.55, 0.08),
				"pos": Vector3(0.0, 0.40, -1.0),
				"color": WOOD_DARK,
			},
		],
	},
	{
		# counter — base-counter unit: cabinet body + worktop slab (~0.66 x 0.9 x 3.0 m).
		# Long axis runs along Z; matches the 2-cell group (rows 3-4, 3.0 m span).
		# Base at Y=0 (body pos.y 0.425 - size.y 0.85/2 = 0) → floor_y_offset = 0.0.
		"name": "counter",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.60, 0.85, 2.9),
				"pos": Vector3(0.0, 0.425, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.66, 0.06, 3.0),
				"pos": Vector3(0.0, 0.88, 0.0),
				"color": SHADE_CREAM,
			},
		],
	},
	{
		# stove — freestanding cooker: body + cooktop + back control strip (~0.6 x 1.05 x 0.6 m).
		# Base at Y=0 (body pos.y 0.425 - size.y 0.85/2 = 0) → floor_y_offset = 0.0.
		"name": "stove",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.60, 0.85, 0.60),
				"pos": Vector3(0.0, 0.425, 0.0),
				"color": METAL_GREY,
			},
			{
				"shape": "box",
				"size": Vector3(0.62, 0.04, 0.62),
				"pos": Vector3(0.0, 0.87, 0.0),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.60, 0.20, 0.05),
				"pos": Vector3(0.0, 1.0, -0.30),
				"color": METAL_GREY,
			},
		],
	},
	{
		# lamp — cylinder base + thin cylinder pole + cone shade.
		"name": "lamp",
		"parts":
		[
			{
				"shape": "cylinder",
				"size": Vector3(0.30, 0.04, 0.30),
				"pos": Vector3(0.0, 0.02, 0.0),
				"color": METAL_GREY,
			},
			{
				"shape": "cylinder",
				"size": Vector3(0.04, 1.0, 0.04),
				"pos": Vector3(0.0, 0.54, 0.0),
				"color": METAL_GREY,
			},
			{
				"shape": "cone",
				"size": Vector3(0.40, 0.30, 0.40),
				"pos": Vector3(0.0, 1.19, 0.0),
				"color": SHADE_CREAM,
			},
		],
	},
	{
		# couch — two-seat sofa: seat base + backrest + 2 armrests (~0.9 x 0.8 x 2.0 m).
		# Long axis runs along Z; faces +X (backrest at -X side). Native Y-min = 0.0.
		"name": "couch",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.90, 0.40, 2.0),
				"pos": Vector3(0.0, 0.20, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.25, 0.45, 2.0),
				"pos": Vector3(-0.32, 0.55, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.90, 0.50, 0.20),
				"pos": Vector3(0.0, 0.45, 0.90),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.90, 0.50, 0.20),
				"pos": Vector3(0.0, 0.45, -0.90),
				"color": WOOD_DARK,
			},
		],
	},
	{
		# tv — flat screen TV on a low media stand (~1.4 m wide x 0.4 m deep x 1.0 m tall).
		# Long axis runs along Z; screen faces +X. Native Y-min = 0.0.
		"name": "tv",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.40, 0.45, 1.4),
				"pos": Vector3(0.0, 0.225, 0.0),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.06, 0.55, 1.2),
				"pos": Vector3(0.20, 0.78, 0.0),
				"color": METAL_GREY,
			},
		],
	},
	{
		# plant — potted plant: terracotta pot box + cone foliage (~0.4 x 1.0 m total).
		# Native Y-min = 0.0 (pot bottom at y=0).
		"name": "plant",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.35, 0.30, 0.35),
				"pos": Vector3(0.0, 0.15, 0.0),
				"color": WOOD_DARK,
			},
			{
				"shape": "cone",
				"size": Vector3(0.55, 0.70, 0.55),
				"pos": Vector3(0.0, 0.65, 0.0),
				"color": LEAF_GREEN,
			},
		],
	},
	{
		# chair — seat slab + 4 legs + backrest (~0.45 x 0.90 x 0.45 m). Native Y-min = 0.
		"name": "chair",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.43, 0.05, 0.43),
				"pos": Vector3(0.0, 0.475, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(0.04, 0.45, 0.04),
				"pos": Vector3(-0.19, 0.225, -0.19),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.04, 0.45, 0.04),
				"pos": Vector3(0.19, 0.225, -0.19),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.04, 0.45, 0.04),
				"pos": Vector3(-0.19, 0.225, 0.19),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.04, 0.45, 0.04),
				"pos": Vector3(0.19, 0.225, 0.19),
				"color": WOOD_DARK,
			},
			{
				"shape": "box",
				"size": Vector3(0.43, 0.35, 0.04),
				"pos": Vector3(0.0, 0.675, -0.215),
				"color": WOOD_MID,
			},
		],
	},
	{
		# bathtub — freestanding tub: outer shell + recessed inner basin (~0.80 x 0.60 x 1.7 m).
		# Long axis runs along Z (fits the 3-cell wall span at Z). Native Y-min = 0.0.
		# Instanced at uniform scale (1,1,1); leaves floor either side of its 1.7 m span — correct.
		"name": "bathtub",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.80, 0.60, 1.7),
				"pos": Vector3(0.0, 0.30, 0.0),
				"color": SHADE_CREAM,
			},
			{
				"shape": "box",
				"size": Vector3(0.64, 0.10, 1.5),
				"pos": Vector3(0.0, 0.58, 0.0),
				"color": METAL_GREY,
			},
		],
	},
	{
		# toilet — bowl/base + cistern/tank (~0.40 x 0.80 x 0.73 m overall).
		# Tank at -Z (backs against the wall). Native Y-min = 0.0.
		"name": "toilet",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(0.40, 0.40, 0.55),
				"pos": Vector3(0.0, 0.20, 0.05),
				"color": SHADE_CREAM,
			},
			{
				"shape": "box",
				"size": Vector3(0.40, 0.45, 0.18),
				"pos": Vector3(0.0, 0.45, -0.26),
				"color": SHADE_CREAM,
			},
		],
	},
	{
		# sink_vanity — vanity cabinet + basin top (~1.0 x 0.90 x 0.50 m).
		# Wide axis runs along X. Native Y-min = 0.0.
		"name": "sink_vanity",
		"parts":
		[
			{
				"shape": "box",
				"size": Vector3(1.0, 0.80, 0.50),
				"pos": Vector3(0.0, 0.40, 0.0),
				"color": WOOD_MID,
			},
			{
				"shape": "box",
				"size": Vector3(1.06, 0.10, 0.56),
				"pos": Vector3(0.0, 0.85, 0.0),
				"color": SHADE_CREAM,
			},
		],
	},
]


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	if not _ensure_output_dir():
		return
	var made: int = 0
	for spec: Dictionary in _props:
		# SEAM: spec values are heterogeneous Variants stored in the spec Dictionary.
		@warning_ignore("unsafe_cast")
		var prop_name: String = spec["name"] as String
		var scene_root: Node3D = _build_prop(spec)
		if _export_glb(prop_name, scene_root):
			made += 1
		scene_root.free()
	print("gen_models: generated ", made, "/", _props.size(), " model(s) into assets/models/.")


## Ensure assets/models/ exists before writing. Returns true on success.
func _ensure_output_dir() -> bool:
	var dir_path: String = ProjectSettings.globalize_path("res://assets/models")
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("gen_models: cannot create output dir '%s': %d" % [dir_path, err])
		return false
	return true


## Build the composite prop as a Node3D root with one MeshInstance3D per part.
func _build_prop(spec: Dictionary) -> Node3D:
	# SEAM: spec values are heterogeneous Variants stored in the spec Dictionary.
	@warning_ignore("unsafe_cast")
	var prop_name: String = spec["name"] as String
	@warning_ignore("unsafe_cast")
	var parts: Array = spec["parts"] as Array
	var scene_root: Node3D = Node3D.new()
	scene_root.name = _pascal_case(prop_name)
	for part: Variant in parts:
		# SEAM: each part is a heterogeneous Variant Dictionary from the spec.
		@warning_ignore("unsafe_cast")
		var part_dict: Dictionary = part as Dictionary
		var mesh_instance: MeshInstance3D = _build_part(part_dict, prop_name)
		if mesh_instance != null:
			scene_root.add_child(mesh_instance)
	return scene_root


## Build one primitive part as a MeshInstance3D, or null for an unknown shape.
func _build_part(part: Dictionary, prop_name: String) -> MeshInstance3D:
	# SEAM: part values are heterogeneous Variants stored in the part Dictionary.
	@warning_ignore("unsafe_cast")
	var shape: String = part["shape"] as String
	@warning_ignore("unsafe_cast")
	var part_size: Vector3 = part["size"] as Vector3
	@warning_ignore("unsafe_cast")
	var pos: Vector3 = part["pos"] as Vector3
	@warning_ignore("unsafe_cast")
	var color: Color = part["color"] as Color

	var mesh: Mesh = _make_mesh(shape, part_size, prop_name)
	if mesh == null:
		return null

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance


## Make a primitive Mesh from a shape name + size, or null for an unknown shape.
func _make_mesh(shape: String, part_size: Vector3, prop_name: String) -> Mesh:
	match shape:
		"box":
			var box: BoxMesh = BoxMesh.new()
			box.size = part_size
			return box
		"cylinder":
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = part_size.x * 0.5
			cylinder.bottom_radius = part_size.x * 0.5
			cylinder.height = part_size.y
			return cylinder
		"cone":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = part_size.x * 0.5
			cone.height = part_size.y
			return cone
		_:
			push_error("gen_models: unknown shape '%s' for '%s'" % [shape, prop_name])
			return null


## Export a built prop to res://assets/models/<name>.glb (binary glTF). Returns true on success.
func _export_glb(prop_name: String, scene_root: Node3D) -> bool:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var append_err: Error = doc.append_from_scene(scene_root, state)
	if append_err != OK:
		push_error("gen_models: append_from_scene failed for '%s': %d" % [prop_name, append_err])
		return false
	var out_path: String = "res://assets/models/%s.glb" % prop_name
	var write_err: Error = doc.write_to_filesystem(state, out_path)
	if write_err != OK:
		push_error("gen_models: write_to_filesystem failed for '%s': %d" % [prop_name, write_err])
		return false
	return true


## Convert a snake_case prop name to a PascalCase node name (desk -> Desk, my_prop -> MyProp).
func _pascal_case(text: String) -> String:
	var out: String = ""
	for chunk: String in text.split("_", false):
		if chunk.is_empty():
			continue
		out += chunk.substr(0, 1).to_upper() + chunk.substr(1)
	return out
