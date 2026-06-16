# scripts/firing_yard_hazards.gd — hazards phase: HazardFloor, Crusher, FallZone.
class_name FiringYardHazards


static func add_hazard_floor(scene_root: Node3D) -> void:
	const HF_SIZE: Vector3 = Vector3(8.0, 0.5, 4.0)
	const HF_POS: Vector3 = Vector3(14.0, 0.25, 4.0)
	const HF_COLOR: Color = Color(0.878, 0.376, 0.125, 1.0)
	const HF_TRIGGER_H: float = 0.3
	const HF_TRIGGER_Y: float = HF_TRIGGER_H * 0.5
	FiringYardNodes.vis_mesh(scene_root, "HazardFloorMesh", HF_SIZE, HF_POS, HF_COLOR)

	FiringYardNodes.build_trigger(
		scene_root,
		"HazardFloor",
		Vector3(HF_SIZE.x, HF_TRIGGER_H, HF_SIZE.z),
		Vector3(HF_POS.x, HF_TRIGGER_Y, HF_POS.z)
	)
	print("build_firing_yard: HazardFloor added at ", HF_POS)


static func add_crusher(scene_root: Node3D) -> void:
	const CRUSHER_SIZE: Vector3 = Vector3(2.0, 2.0, 2.0)
	const CRUSHER_START: Vector3 = Vector3(8.0, 1.0, 16.0)
	const CRUSHER_COLOR: Color = Color(0.78, 0.18, 0.08, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = CRUSHER_COLOR
	var body: StaticBody3D = FiringYardNodes.build_box_body(
		scene_root, "Crusher", CRUSHER_SIZE, Vector3.ZERO, mat
	)
	body.position = CRUSHER_START

	var area: Area3D = Area3D.new()
	area.name = "CrusherHit"
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 2
	body.add_child(area)
	area.owner = scene_root
	var acs: CollisionShape3D = CollisionShape3D.new()
	acs.name = "CrusherHitShape"
	var hit_shape: BoxShape3D = BoxShape3D.new()
	hit_shape.size = CRUSHER_SIZE
	acs.shape = hit_shape
	area.add_child(acs)
	acs.owner = scene_root
	print("build_firing_yard: Crusher added at ", CRUSHER_START)


static func add_fall_zone(
	scene_root: Node3D, fall_w: float, fall_d: float, fall_center_y: float
) -> void:
	FiringYardNodes.build_trigger(
		scene_root, "FallZone", Vector3(fall_w, 2.0, fall_d), Vector3(24.0, fall_center_y, 16.0)
	)
	print("build_firing_yard: FallZone added at y=", fall_center_y)
