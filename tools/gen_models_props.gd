# tools/gen_models_props.gd — furniture + bathroom prop specs for gen_models.gd.
# Arena/enemy/weapon/pickup specs live in gen_models_props_arena.gd.
# Add a prop here; gen_models.gd picks it up automatically on next run.
class_name GenModelsProps
extends RefCounted


## Returns all prop specs (furniture + arena merged).
## Each entry: {name, parts:[{shape, size, pos, color}]}.
static func get_props() -> Array[Dictionary]:
	var props: Array[Dictionary] = [
		{
			# desk — top slab + 2 side-panel legs (~1.2 x 0.75 x 0.7 m). Y-min = 0.
			"name": "desk",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(1.2, 0.05, 0.7),
					"pos": Vector3(0.0, 0.725, 0.0),
					"color": ArtStyle.WOOD_LIGHT,
				},
				{
					"shape": "box",
					"size": Vector3(0.06, 0.7, 0.64),
					"pos": Vector3(-0.54, 0.35, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.06, 0.7, 0.64),
					"pos": Vector3(0.54, 0.35, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
			],
		},
		{
			# nightstand — body + drawer-front (~0.7 x 0.6 x 0.7 m). Y-min = 0.
			"name": "nightstand",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.7, 0.6, 0.7),
					"pos": Vector3(0.0, 0.3, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.6, 0.4, 0.03),
					"pos": Vector3(0.0, 0.32, 0.35),
					"color": ArtStyle.WOOD_LIGHT,
				},
			],
		},
		{
			# wardrobe — body + 2 door panels (~1.5 x 2.0 x 3.0 m). Y-min = 0.
			"name": "wardrobe",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(1.5, 2.0, 3.0),
					"pos": Vector3(0.0, 1.0, 0.0),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.7, 1.9, 0.04),
					"pos": Vector3(-0.36, 1.0, 1.5),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.7, 1.9, 0.04),
					"pos": Vector3(0.36, 1.0, 1.5),
					"color": ArtStyle.WOOD_MID,
				},
			],
		},
		{
			# single_bed — frame + mattress + headboard (~1.05 x 0.70 x 2.05 m). Y-min = 0.
			"name": "single_bed",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(1.05, 0.30, 2.05),
					"pos": Vector3(0.0, 0.15, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(1.0, 0.22, 1.85),
					"pos": Vector3(0.0, 0.41, 0.05),
					"color": ArtStyle.SHADE_CREAM,
				},
				{
					"shape": "box",
					"size": Vector3(1.05, 0.55, 0.08),
					"pos": Vector3(0.0, 0.40, -1.0),
					"color": ArtStyle.WOOD_DARK,
				},
			],
		},
		{
			# counter — cabinet body + worktop slab (~0.66 x 0.9 x 3.0 m). Y-min = 0.
			"name": "counter",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.60, 0.85, 2.9),
					"pos": Vector3(0.0, 0.425, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.66, 0.06, 3.0),
					"pos": Vector3(0.0, 0.88, 0.0),
					"color": ArtStyle.SHADE_CREAM,
				},
			],
		},
		{
			# stove — body + cooktop + control strip (~0.6 x 1.05 x 0.6 m). Y-min = 0.
			"name": "stove",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.60, 0.85, 0.60),
					"pos": Vector3(0.0, 0.425, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
				{
					"shape": "box",
					"size": Vector3(0.62, 0.04, 0.62),
					"pos": Vector3(0.0, 0.87, 0.0),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.60, 0.20, 0.05),
					"pos": Vector3(0.0, 1.0, -0.30),
					"color": ArtStyle.METAL_GREY,
				},
			],
		},
		{
			# lamp — base + pole + cone shade (~0.3 x 1.2 m). Y-min = 0.
			"name": "lamp",
			"parts":
			[
				{
					"shape": "cylinder",
					"size": Vector3(0.30, 0.04, 0.30),
					"pos": Vector3(0.0, 0.02, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
				{
					"shape": "cylinder",
					"size": Vector3(0.04, 1.0, 0.04),
					"pos": Vector3(0.0, 0.54, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
				{
					"shape": "cone",
					"size": Vector3(0.40, 0.30, 0.40),
					"pos": Vector3(0.0, 1.19, 0.0),
					"color": ArtStyle.SHADE_CREAM,
				},
			],
		},
		{
			# couch — seat base + backrest + 2 armrests (~0.9 x 0.8 x 2.0 m). Y-min = 0.
			"name": "couch",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.90, 0.40, 2.0),
					"pos": Vector3(0.0, 0.20, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.25, 0.45, 2.0),
					"pos": Vector3(-0.32, 0.55, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.90, 0.50, 0.20),
					"pos": Vector3(0.0, 0.45, 0.90),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.90, 0.50, 0.20),
					"pos": Vector3(0.0, 0.45, -0.90),
					"color": ArtStyle.WOOD_DARK,
				},
			],
		},
		{
			"name": "tv",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.40, 0.45, 1.4),
					"pos": Vector3(0.0, 0.225, 0.0),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.06, 0.55, 1.2),
					"pos": Vector3(0.20, 0.78, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
			],
		},
		{
			"name": "plant",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.35, 0.30, 0.35),
					"pos": Vector3(0.0, 0.15, 0.0),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "cone",
					"size": Vector3(0.55, 0.70, 0.55),
					"pos": Vector3(0.0, 0.65, 0.0),
					"color": ArtStyle.LEAF_GREEN,
				},
			],
		},
		{
			# chair — seat slab + leg block + backrest (~0.45 x 0.90 x 0.45 m). Y-min = 0.
			"name": "chair",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.43, 0.05, 0.43),
					"pos": Vector3(0.0, 0.475, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.37, 0.45, 0.37),
					"pos": Vector3(0.0, 0.225, 0.0),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.43, 0.35, 0.04),
					"pos": Vector3(0.0, 0.675, -0.215),
					"color": ArtStyle.WOOD_MID,
				},
			],
		},
		{
			"name": "bathtub",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.80, 0.60, 1.7),
					"pos": Vector3(0.0, 0.30, 0.0),
					"color": ArtStyle.SHADE_CREAM,
				},
				{
					"shape": "box",
					"size": Vector3(0.64, 0.10, 1.5),
					"pos": Vector3(0.0, 0.58, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
			],
		},
		{
			"name": "toilet",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.40, 0.40, 0.55),
					"pos": Vector3(0.0, 0.20, 0.05),
					"color": ArtStyle.SHADE_CREAM,
				},
				{
					"shape": "box",
					"size": Vector3(0.40, 0.45, 0.18),
					"pos": Vector3(0.0, 0.45, -0.26),
					"color": ArtStyle.SHADE_CREAM,
				},
			],
		},
		{
			"name": "sink_vanity",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(1.0, 0.80, 0.50),
					"pos": Vector3(0.0, 0.40, 0.0),
					"color": ArtStyle.WOOD_MID,
				},
				{
					"shape": "box",
					"size": Vector3(1.06, 0.10, 0.56),
					"pos": Vector3(0.0, 0.85, 0.0),
					"color": ArtStyle.SHADE_CREAM,
				},
			],
		},
		{
			# rifle_placeholder — stock + body/receiver + long barrel + foregrip.
			# Proportions: ~0.05 x 0.14 x 0.56 m, clearly longer than pistol.
			# Swap for a sourced .glb when asset-advisor delivers the real model.
			"name": "rifle_placeholder",
			"parts":
			[
				{
					# stock (butt)
					"shape": "box",
					"size": Vector3(0.05, 0.09, 0.14),
					"pos": Vector3(0.0, 0.07, 0.21),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					# body / receiver
					"shape": "box",
					"size": Vector3(0.044, 0.055, 0.24),
					"pos": Vector3(0.0, 0.09, 0.0),
					"color": ArtStyle.METAL_GREY,
				},
				{
					# foregrip / handguard
					"shape": "box",
					"size": Vector3(0.036, 0.036, 0.14),
					"pos": Vector3(0.0, 0.072, -0.16),
					"color": ArtStyle.WOOD_MID,
				},
				{
					# barrel (long, thin cylinder)
					"shape": "cylinder",
					"size": Vector3(0.016, 0.22, 0.016),
					"pos": Vector3(0.0, 0.09, -0.23),
					"color": ArtStyle.METAL_GREY,
				},
				{
					# pistol-grip
					"shape": "box",
					"size": Vector3(0.04, 0.09, 0.05),
					"pos": Vector3(0.0, 0.035, 0.06),
					"color": ArtStyle.WOOD_DARK,
				},
			],
		},
		{
			# pistol_placeholder — grip block + slide + barrel stub.
			# Proportions: ~0.14 x 0.13 x 0.24 m held at arm's length.
			# Swap for a sourced .glb when asset-advisor delivers the real model.
			"name": "pistol_placeholder",
			"parts":
			[
				{
					# grip
					"shape": "box",
					"size": Vector3(0.04, 0.10, 0.06),
					"pos": Vector3(0.0, 0.05, 0.04),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					# slide / upper receiver
					"shape": "box",
					"size": Vector3(0.035, 0.04, 0.18),
					"pos": Vector3(0.0, 0.115, -0.04),
					"color": ArtStyle.METAL_GREY,
				},
				{
					# barrel stub
					"shape": "cylinder",
					"size": Vector3(0.018, 0.06, 0.018),
					"pos": Vector3(0.0, 0.115, -0.145),
					"color": ArtStyle.METAL_GREY,
				},
			],
		},
		{
			# shoulder_turret — compact housing box + short barrel cylinder pointing +Z (rear).
			# Mounted on player upper-back; scale ~0.12 x 0.10 x 0.10 m housing.
			# STEEL_MID body + HAZARD_AMBER barrel so it reads as "powered device" at a glance.
			# Swap for a sourced .glb when asset-advisor delivers the real model.
			"name": "shoulder_turret",
			"parts":
			[
				{
					# main housing box
					"shape": "box",
					"size": Vector3(0.12, 0.10, 0.10),
					"pos": Vector3(0.0, 0.05, 0.0),
					"color": ArtStyle.STEEL_MID,
				},
				{
					# top sensor/dome block
					"shape": "box",
					"size": Vector3(0.06, 0.04, 0.06),
					"pos": Vector3(0.0, 0.12, 0.0),
					"color": ArtStyle.STEEL_DARK,
				},
				{
					# barrel cylinder pointing +Z (rear-firing direction)
					"shape": "cylinder",
					"size": Vector3(0.028, 0.08, 0.028),
					"pos": Vector3(0.0, 0.05, 0.09),
					"color": ArtStyle.HAZARD_AMBER,
				},
			],
		},
	]
	var arena: Array[Dictionary] = GenModelsPropsArena.get_props()
	props.append_array(arena)
	return props
