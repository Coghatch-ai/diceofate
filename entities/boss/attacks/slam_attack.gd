# entities/boss/attacks/slam_attack.gd — scale-pulse tell + growing floor ring + AoE + shockwave.
# Timing/visual driven by BossData (slam_inner_telegraph, slam_telegraph_scale, slam_vfx_scene).
# No magic literals in slam logic.
class_name SlamAttack
extends BossAttack

# Injected Boss ref.
var _boss: Boss = null
# Accumulator driving the inner wind-up wait.
var _accum: float = 0.0
# Guard: AoE fires exactly once per activation.
var _detonated: bool = false
# Warning ring node parented to scene root during telegraph; freed at detonation.
var _warning_ring: MeshInstance3D = null


func bind(boss: Node) -> void:
	_boss = boss as Boss


func telegraph_duration() -> float:
	if _boss == null or _boss.data == null:
		return 0.8
	return _boss.data.telegraph_duration


func start() -> void:
	_accum = 0.0
	_detonated = false
	_warning_ring = null
	if _boss == null:
		return
	var data: BossData = _boss.data
	if data == null:
		return
	var inner_t: float = data.slam_inner_telegraph
	var tel_scale: Vector3 = data.slam_telegraph_scale
	# ── Scale-pulse wind-up on the boss mesh ───────────────────────────────────
	var mesh_node: Node3D = _boss.get_node_or_null("Mesh") as Node3D
	if mesh_node != null:
		var base_s: Vector3 = mesh_node.scale
		var target_s: Vector3 = Vector3(
			base_s.x * tel_scale.x, base_s.y * tel_scale.y, base_s.z * tel_scale.z
		)
		var tw: Tween = _boss.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mesh_node, "scale", target_s, inner_t * 0.6)
		tw.chain().tween_property(mesh_node, "scale", base_s, inner_t * 0.4)
	# ── Spawn floor warning ring (grows to slam_radius over inner_telegraph) ───
	# Use a code-built MeshInstance3D torus so we own its lifetime and tween fully.
	# Freed explicitly at detonation — does NOT auto-free like ShockwaveRing.
	var scene_root: Node = _boss.get_tree().current_scene
	if scene_root != null:
		_warning_ring = _build_warning_ring(data.slam_radius, inner_t, scene_root)


func _build_warning_ring(target_radius: float, duration: float, parent: Node) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.25
	torus.rings = 8
	torus.ring_segments = 24
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.mesh = torus
	ring.set_surface_override_material(0, mat)
	# Start scale = tiny (radius 0.5) and grow to slam_radius over the inner telegraph window.
	ring.scale = Vector3.ONE * 0.5
	parent.add_child(ring)
	ring.global_position = Vector3(
		_boss.global_position.x, _boss.global_position.y - 0.05, _boss.global_position.z
	)
	# Grow the ring to the AoE radius so the player can see the danger zone filling up.
	var tw: Tween = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * target_radius, duration)
	# Pulse albedo alpha: 0.3 → 1.0 over the wind-up to ramp urgency.
	tw.tween_property(mat, "albedo_color", Color(1.0, 0.3, 0.1, 1.0), duration * 0.8)
	return ring


func tick(delta: float) -> bool:
	if _boss == null:
		return true
	# Halt XZ during inner wind-up (gravity still applied by boss.gd).
	_boss.velocity.x = 0.0
	_boss.velocity.z = 0.0
	_accum += delta
	var inner_t: float = _boss.data.slam_inner_telegraph if _boss.data != null else 0.5
	if not _detonated and _accum >= inner_t:
		_detonated = true
		_detonate()
		return true
	return false


func recover_duration() -> float:
	if _boss == null or _boss.data == null:
		return 1.0
	return _boss.data.recover_duration


func _detonate() -> void:
	if _boss == null:
		return
	# Free the growing warning ring — replaced by the fast impact shockwave.
	if is_instance_valid(_warning_ring):
		_warning_ring.queue_free()
		_warning_ring = null
	var data: BossData = _boss.data
	var radius: float = data.slam_radius if data != null else 6.0
	var dmg: int = data.slam_damage if data != null else 40
	# AoE damage to player.
	var p: Node3D = _boss.get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		var dist: float = _boss.global_position.distance_to(p.global_position)
		if dist <= radius:
			if p.has_method("apply_damage"):
				# SEAM: duck-typed apply_damage.
				@warning_ignore("unsafe_method_access")
				p.apply_damage(dmg)
	# Spawn detonation shockwave ring (fast burst at impact point).
	var scene_root: Node = _boss.get_tree().current_scene
	if scene_root == null:
		return
	if data != null and data.slam_vfx_scene != null:
		var ring: Node3D = data.slam_vfx_scene.instantiate() as Node3D
		scene_root.add_child(ring)
		ring.global_position = Vector3(
			_boss.global_position.x, _boss.global_position.y - 0.05, _boss.global_position.z
		)
