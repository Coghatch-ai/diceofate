# tools/gen_textures_specs.gd — texture spec data for gen_textures.gd.
# Add a texture here; gen_textures.gd picks it up automatically on next run.
class_name GenTexturesSpecs
extends RefCounted


## Returns all texture specs. Each entry:
## { "name": String, "size": int, "kind": String, "seed": int, "palette": PackedColorArray }
## Kinds: planks, plaster, fabric, tiles, concrete, concrete_wall, steel, hazard.
static func get_specs() -> Array[Dictionary]:
	# var not const: PackedColorArray()/Color() are not constant expressions in GDScript,
	# so a const Array[Dictionary] of palettes will not compile.
	var specs: Array[Dictionary] = [
		{
			"name": "wood_floor",
			"size": 32,
			"kind": "planks",
			"seed": 1001,
			# dark→mid_dark→mid mortar rows; WOOD_DARKEST is the mortar colour (last entry).
			"palette":
			PackedColorArray(
				[
					ArtStyle.WOOD_DARK,
					ArtStyle.WOOD_MID_DARK,
					ArtStyle.WOOD_MID,
					ArtStyle.WOOD_DARKEST,
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
					ArtStyle.WALL_PLASTER_LIGHT,
					ArtStyle.WALL_PLASTER_MID,
					ArtStyle.WALL_PLASTER_DARK,
				]
			),
		},
		{
			"name": "fabric_weave",
			"size": 32,
			"kind": "fabric",
			"seed": 3003,
			# mid first (warp thread), light second (weft thread), dark unused by fabric kind.
			"palette":
			PackedColorArray(
				[
					ArtStyle.FABRIC_BLUEGREY_MID,
					ArtStyle.FABRIC_BLUEGREY_LIGHT,
					ArtStyle.FABRIC_BLUEGREY_DARK,
				]
			),
		},
		{
			"name": "tile_floor",
			"size": 32,
			"kind": "tiles",
			"seed": 4004,
			# mid→light→dark tiles; TILE_GROUT is the grout colour (last entry).
			"palette":
			PackedColorArray(
				[
					ArtStyle.TILE_MID,
					ArtStyle.TILE_LIGHT,
					ArtStyle.TILE_DARK,
					ArtStyle.TILE_GROUT,
				]
			),
		},
		{
			# Firing yard — worn concrete floor. Ramp darkest→dark→mid.
			# uv1_scale so 1 tile ≈ 2 m (one grid cell). Faint expansion-joint grid at cell scale.
			"name": "concrete_floor",
			"size": 32,
			"kind": "concrete",
			"seed": 5005,
			# darkest (base) → dark → mid; last entry is the joint/seam colour.
			"palette":
			PackedColorArray(
				[
					ArtStyle.CONCRETE_DARKEST,
					ArtStyle.CONCRETE_DARK,
					ArtStyle.CONCRETE_MID,
					ArtStyle.CONCRETE_DARKEST,
				]
			),
		},
		{
			# Firing yard — concrete wall panels. Ramp dark→mid→light, subtle vertical seams.
			"name": "concrete_wall",
			"size": 32,
			"kind": "concrete_wall",
			"seed": 6006,
			# dark (base) → mid → light; last entry is the panel seam colour.
			"palette":
			PackedColorArray(
				[
					ArtStyle.CONCRETE_DARK,
					ArtStyle.CONCRETE_MID,
					ArtStyle.CONCRETE_LIGHT,
					ArtStyle.CONCRETE_DARKEST,
				]
			),
		},
		{
			# Firing yard — brushed steel deck (platforms, ramps).
			# Horizontal brushed striations + corner bolt dots.
			"name": "steel_panel",
			"size": 32,
			"kind": "steel",
			"seed": 7007,
			# dark (base) → mid → light.
			"palette":
			PackedColorArray(
				[
					ArtStyle.STEEL_DARK,
					ArtStyle.STEEL_MID,
					ArtStyle.STEEL_LIGHT,
				]
			),
		},
		{
			# Firing yard — hazard stripe slab (id-1 zone). Diagonal amber/dark bands.
			"name": "hazard_stripe",
			"size": 32,
			"kind": "hazard",
			"seed": 8008,
			# amber (stripe) then dark (stripe shadow).
			"palette":
			PackedColorArray(
				[
					ArtStyle.HAZARD_AMBER,
					ArtStyle.HAZARD_STRIPE_DARK,
				]
			),
		},
		{
			# Scorch / blood decal: dark radial smudge with alpha falloff. Used by DecalPool.
			# Replace with sourced art later; placeholder is intentionally near-black centre.
			"name": "scorch_decal",
			"size": 64,
			"kind": "scorch",
			"seed": 9009,
			# center_dark (near-black scorch core), mid_colour (charcoal edge).
			"palette":
			PackedColorArray(
				[
					Color(0.08, 0.07, 0.06),
					Color(0.20, 0.18, 0.16),
				]
			),
		},
	]
	return specs
