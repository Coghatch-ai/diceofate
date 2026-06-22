# tools/gen_models_props_arena.gd — arena prop specs: enemies, weapons, pickups, barrels/crates.
class_name GenModelsPropsArena
extends RefCounted


## Returns arena prop specs. Each entry: {name, parts:[{shape,size,pos,color}]}.
static func get_props() -> Array[Dictionary]:
	var props: Array[Dictionary] = [
		{
			# barrel_rusted — body cylinder + steel cap rings (~0.5 m diam x 1.0 m). Y-min = 0.
			"name": "barrel_rusted",
			"parts":
			[
				{
					"shape": "cylinder",
					"size": Vector3(0.50, 0.90, 0.50),
					"pos": Vector3(0.0, 0.45, 0.0),
					"color": ArtStyle.RUST_MID,
				},
				{
					"shape": "cylinder",
					"size": Vector3(0.52, 0.06, 0.52),
					"pos": Vector3(0.0, 0.93, 0.0),
					"color": ArtStyle.STEEL_DARK,
				},
				{
					"shape": "cylinder",
					"size": Vector3(0.52, 0.06, 0.52),
					"pos": Vector3(0.0, 0.03, 0.0),
					"color": ArtStyle.STEEL_DARK,
				},
			],
		},
		{
			# crate_metal — metal shipping crate: body + top/base cap bands (~0.8x0.8x0.8 m). Y-min=0.
			"name": "crate_metal",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.80, 0.80, 0.80),
					"pos": Vector3(0.0, 0.40, 0.0),
					"color": ArtStyle.STEEL_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.82, 0.05, 0.82),
					"pos": Vector3(0.0, 0.79, 0.0),
					"color": ArtStyle.RUST_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.82, 0.05, 0.82),
					"pos": Vector3(0.0, 0.025, 0.0),
					"color": ArtStyle.STEEL_DARK,
				},
			],
		},
		{
			# enemy_grunt — humanoid box kitbash (~0.7W x 1.77H x 0.4D). Y-min=0. Faces -Z.
			"name": "enemy_grunt",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.34, 0.34, 0.34),
					"pos": Vector3(0.0, 1.60, 0.0),
					"color": ArtStyle.ENEMY_ARMOR_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.50, 0.60, 0.30),
					"pos": Vector3(0.0, 1.15, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.30, 0.20, 0.32),
					"pos": Vector3(0.0, 1.25, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_LIGHT,
				},
				{
					"shape": "box",
					"size": Vector3(0.14, 0.55, 0.16),
					"pos": Vector3(-0.32, 1.12, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.14, 0.55, 0.16),
					"pos": Vector3(0.32, 1.12, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.16, 0.16, 0.18),
					"pos": Vector3(-0.32, 0.80, 0.0),
					"color": ArtStyle.ENEMY_ARMOR_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.16, 0.16, 0.18),
					"pos": Vector3(0.32, 0.80, 0.0),
					"color": ArtStyle.ENEMY_ARMOR_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.18, 0.70, 0.20),
					"pos": Vector3(-0.13, 0.42, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.18, 0.70, 0.20),
					"pos": Vector3(0.13, 0.42, 0.0),
					"color": ArtStyle.ENEMY_CRIMSON_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.20, 0.10, 0.28),
					"pos": Vector3(-0.13, 0.05, 0.0),
					"color": ArtStyle.ENEMY_ARMOR_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.20, 0.10, 0.28),
					"pos": Vector3(0.13, 0.05, 0.0),
					"color": ArtStyle.ENEMY_ARMOR_DARK,
				},
			],
		},
		{
			# hammer — FPS view-model. Cyl handle + box head + claw. Head -Z.
			"name": "hammer",
			"parts":
			[
				{
					"shape": "cylinder",
					"size": Vector3(0.025, 0.28, 0.025),
					"pos": Vector3(0.0, 0.0, -0.01),
					"color": ArtStyle.WOOD_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.08, 0.06, 0.12),
					"pos": Vector3(0.0, 0.0, -0.16),
					"color": ArtStyle.STEEL_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.04, 0.03, 0.05),
					"pos": Vector3(0.0, 0.0, -0.065),
					"color": ArtStyle.STEEL_DARK,
				},
			],
		},
		{
			# knife — FPS view-model. Blade face+spine+guard+handle. Blade -Z.
			"name": "knife",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.015, 0.005, 0.18),
					"pos": Vector3(0.0, 0.002, -0.09),
					"color": ArtStyle.STEEL_LIGHT,
				},
				{
					"shape": "box",
					"size": Vector3(0.006, 0.009, 0.18),
					"pos": Vector3(0.0, -0.001, -0.09),
					"color": ArtStyle.STEEL_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.042, 0.014, 0.007),
					"pos": Vector3(0.0, 0.0, 0.0),
					"color": ArtStyle.STEEL_DARK,
				},
				{
					"shape": "box",
					"size": Vector3(0.018, 0.018, 0.10),
					"pos": Vector3(0.0, 0.0, 0.055),
					"color": ArtStyle.WOOD_DARK,
				},
			],
		},
		{
			# pickup_ammo — small brass/olive ammo crate (~0.4x0.4x0.4 m). Y-min=0.
			"name": "pickup_ammo",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.40, 0.40, 0.40),
					"pos": Vector3(0.0, 0.20, 0.0),
					"color": ArtStyle.PICKUP_AMMO_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.42, 0.05, 0.42),
					"pos": Vector3(0.0, 0.39, 0.0),
					"color": ArtStyle.PICKUP_AMMO_LIGHT,
				},
				{
					"shape": "box",
					"size": Vector3(0.42, 0.05, 0.42),
					"pos": Vector3(0.0, 0.025, 0.0),
					"color": ArtStyle.PICKUP_AMMO_DARK,
				},
			],
		},
		{
			# pickup_health — small green health crate (~0.4x0.4x0.4 m). Y-min=0.
			"name": "pickup_health",
			"parts":
			[
				{
					"shape": "box",
					"size": Vector3(0.40, 0.40, 0.40),
					"pos": Vector3(0.0, 0.20, 0.0),
					"color": ArtStyle.PICKUP_HEALTH_MID,
				},
				{
					"shape": "box",
					"size": Vector3(0.42, 0.05, 0.42),
					"pos": Vector3(0.0, 0.39, 0.0),
					"color": ArtStyle.PICKUP_HEALTH_LIGHT,
				},
				{
					"shape": "box",
					"size": Vector3(0.42, 0.05, 0.42),
					"pos": Vector3(0.0, 0.025, 0.0),
					"color": ArtStyle.PICKUP_HEALTH_DARK,
				},
			],
		},
	]
	return props
