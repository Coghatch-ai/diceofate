# tools/gen_textures.gd — headless procedural pixel-art texture generator (prototype placeholders).
## Run:  $GODOT --headless --path . --script tools/gen_textures.gd
##  then: $GODOT --headless --path . --import
## Reusable: add a spec to SPECS and re-run. Output: assets/textures/<name>.png (+ .import).
## Seamless + opaque.
@tool
extends SceneTree

const IMPORT_TEMPLATE: String = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://gen_%s"

[deps]

source_file="res://assets/textures/%s.png"
dest_files=["res://.godot/imported/%s.png.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

# SPECS is a var, not a const: PackedColorArray()/Color() are not constant expressions in
# GDScript, so a const Array[Dictionary] of palettes will not compile. One entry per texture
# — adding a texture = adding an entry here.
var _specs: Array[Dictionary] = [
	{
		"name": "wood_floor",
		"size": 32,
		"kind": "planks",
		"seed": 1001,
		"palette":
		PackedColorArray(
			[
				Color(0.36, 0.24, 0.14, 1.0),
				Color(0.45, 0.30, 0.18, 1.0),
				Color(0.52, 0.36, 0.22, 1.0),
				Color(0.28, 0.18, 0.10, 1.0),
			]
		),
	},
	{
		"name": "plaster_wall",
		"size": 32,
		"kind": "plaster",
		"seed": 2002,
		"palette":
		PackedColorArray(
			[
				Color(0.90, 0.87, 0.80, 1.0),
				Color(0.83, 0.79, 0.71, 1.0),
				Color(0.74, 0.70, 0.62, 1.0),
			]
		),
	},
	{
		"name": "fabric_weave",
		"size": 32,
		"kind": "fabric",
		"seed": 3003,
		"palette":
		PackedColorArray(
			[
				Color(0.20, 0.30, 0.42, 1.0),
				Color(0.26, 0.38, 0.50, 1.0),
				Color(0.16, 0.24, 0.34, 1.0),
			]
		),
	},
	{
		"name": "tile_floor",
		"size": 32,
		"kind": "tiles",
		"seed": 4004,
		"palette":
		PackedColorArray(
			[
				Color(0.62, 0.64, 0.66, 1.0),
				Color(0.70, 0.72, 0.74, 1.0),
				Color(0.54, 0.56, 0.58, 1.0),
				Color(0.30, 0.31, 0.33, 1.0),
			]
		),
	},
]


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var made: int = 0
	for spec: Dictionary in _specs:
		# SEAM: spec values are heterogeneous Variants stored in the spec Dictionary.
		@warning_ignore("unsafe_cast")
		var spec_name: String = spec["name"] as String
		var image: Image = _generate(spec)
		if _save(spec_name, image):
			made += 1
	print(
		"gen_textures: generated ", made, "/", _specs.size(), " texture(s) into assets/textures/."
	)


func _generate(spec: Dictionary) -> Image:
	# SEAM: spec values are heterogeneous Variants stored in the spec Dictionary.
	@warning_ignore("unsafe_cast")
	var size: int = spec["size"] as int
	@warning_ignore("unsafe_cast")
	var kind: String = spec["kind"] as String
	@warning_ignore("unsafe_cast")
	var seed_value: int = spec["seed"] as int
	@warning_ignore("unsafe_cast")
	var palette: PackedColorArray = spec["palette"] as PackedColorArray
	@warning_ignore("unsafe_cast")
	var spec_name: String = spec["name"] as String
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)

	match kind:
		"planks":
			_draw_planks(image, size, seed_value, palette)
		"plaster":
			_draw_plaster(image, size, seed_value, palette)
		"fabric":
			_draw_fabric(image, size, seed_value, palette)
		"tiles":
			_draw_tiles(image, size, seed_value, palette)
		_:
			push_error("gen_textures: unknown kind '%s' for '%s'" % [kind, spec_name])
			image.fill(Color(1.0, 0.0, 1.0, 1.0))
	return image


## Horizontal plank bands with per-band tint, 1px mortar lines, faint grain streaks.
func _draw_planks(image: Image, size: int, seed_value: int, palette: PackedColorArray) -> void:
	var band_height: int = 8
	var mortar: Color = palette[palette.size() - 1]
	for y: int in range(size):
		# @warning_ignore: integer division is intended — band index from the row.
		@warning_ignore("integer_division")
		var band: int = y / band_height
		var is_mortar: bool = (y % band_height) == 0
		var base: Color = palette[band % (palette.size() - 1)]
		# Per-band tint shift, deterministic per band so re-runs match.
		var band_shift: float = _periodic_hash(0, band, size, seed_value) * 0.12 - 0.06
		for x: int in range(size):
			if is_mortar:
				image.set_pixel(x, y, mortar)
				continue
			# Faint horizontal grain from periodic noise, periodic over the width.
			var grain: float = _periodic_hash(x, band * 7, size, seed_value + 5) * 0.10 - 0.05
			var shade: float = 1.0 + band_shift + grain
			image.set_pixel(x, y, _opaque(_scaled(base, shade)))


## Flat base + low-amplitude periodic noise, quantized to palette shades for a banded look.
func _draw_plaster(image: Image, size: int, seed_value: int, palette: PackedColorArray) -> void:
	var base: Color = palette[0]
	for y: int in range(size):
		for x: int in range(size):
			# Two periodic octaves keep the noise wrapping at the tile edges.
			var n1: float = _periodic_hash(x, y, size, seed_value)
			var n2: float = _periodic_hash(x * 2, y * 2, size, seed_value + 11)
			var shade: float = 1.0 + ((n1 + n2) * 0.5 - 0.5) * 0.12
			var c: Color = _scaled(base, shade)
			image.set_pixel(x, y, _opaque(_quantize(c, palette)))


## 2px warp/weft weave from thread parity, plus subtle periodic noise.
func _draw_fabric(image: Image, size: int, seed_value: int, palette: PackedColorArray) -> void:
	var thread: int = 2
	for y: int in range(size):
		for x: int in range(size):
			# Thread parity over 2px cells alternates the two weave tints.
			# @warning_ignore: integer division is intended — thread cell indices.
			@warning_ignore("integer_division")
			var parity: int = ((x / thread) + (y / thread)) % 2
			var base: Color = palette[parity]
			var n: float = _periodic_hash(x, y, size, seed_value) * 0.08 - 0.04
			image.set_pixel(x, y, _opaque(_scaled(base, 1.0 + n)))


## Cell grid with 1px grout lines and a small per-cell tint from a per-cell hash.
func _draw_tiles(image: Image, size: int, seed_value: int, palette: PackedColorArray) -> void:
	var cell: int = 16
	var grout: Color = palette[palette.size() - 1]
	for y: int in range(size):
		for x: int in range(size):
			var on_grout: bool = (x % cell) == 0 or (y % cell) == 0
			if on_grout:
				image.set_pixel(x, y, grout)
				continue
			# @warning_ignore: integer division is intended — cell grid indices.
			@warning_ignore("integer_division")
			var cell_x: int = x / cell
			# @warning_ignore: integer division is intended — cell grid indices.
			@warning_ignore("integer_division")
			var cell_y: int = y / cell
			# Per-cell hash picks a base shade and a small tint, periodic over the grid.
			var h: float = _periodic_hash(cell_x, cell_y, size, seed_value)
			var base: Color = palette[int(h * float(palette.size() - 1))]
			var tint: float = 1.0 + (h - 0.5) * 0.10
			image.set_pixel(x, y, _opaque(_scaled(base, tint)))


## Deterministic integer hash in [0,1). x/y are wrapped to [0,size) BEFORE hashing so the
## value is identical at x and x+size (and likewise for y) — the key to seamless tiling.
func _periodic_hash(x: int, y: int, size: int, seed_value: int) -> float:
	var wx: int = ((x % size) + size) % size
	var wy: int = ((y % size) + size) % size
	var h: int = wx * 374761393 + wy * 668265263 + seed_value * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7FFFFFFF) / 2147483648.0


## Snap a color to the nearest palette entry by squared RGB distance (crisp banded look).
func _quantize(c: Color, palette: PackedColorArray) -> Color:
	var best: Color = palette[0]
	var best_dist: float = INF
	for entry: Color in palette:
		var dr: float = c.r - entry.r
		var dg: float = c.g - entry.g
		var db: float = c.b - entry.b
		var dist: float = dr * dr + dg * dg + db * db
		if dist < best_dist:
			best_dist = dist
			best = entry
	return best


## Multiply RGB by a scalar, clamped to [0,1]; alpha untouched.
func _scaled(c: Color, factor: float) -> Color:
	return Color(
		clampf(c.r * factor, 0.0, 1.0),
		clampf(c.g * factor, 0.0, 1.0),
		clampf(c.b * factor, 0.0, 1.0),
		c.a,
	)


## Force full opacity (surface textures must not render cut-out).
func _opaque(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 1.0)


## Save the PNG and write its pixel-art .import sidecar. Returns true on success.
func _save(texture_name: String, image: Image) -> bool:
	var png_path: String = "res://assets/textures/%s.png" % texture_name
	var save_err: Error = image.save_png(png_path)
	if save_err != OK:
		push_error("gen_textures: save_png failed for '%s': %d" % [texture_name, save_err])
		return false

	var import_path: String = "res://assets/textures/%s.png.import" % texture_name
	var sidecar: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	if sidecar == null:
		push_error("gen_textures: cannot open sidecar '%s'" % import_path)
		return false
	sidecar.store_string(IMPORT_TEMPLATE % [texture_name, texture_name, texture_name])
	sidecar.close()
	return true
