# tools/lib/enemy/boss_mechanics.gd — static helpers for Boss data accessors + volley firing.
# Extracted from boss.gd to keep it under 500 lines (godot-code-rules).
class_name BossMechanics


# ── Data accessors (fallbacks when data == null) ───────────────────────────────
static func idle_duration(data: BossData, in_phase2: bool) -> float:
	var base: float = data.idle_duration if data != null else 1.2
	return base * (data.phase2_cadence_mult if (in_phase2 and data != null) else 1.0)


static func telegraph_duration(data: BossData) -> float:
	return data.telegraph_duration if data != null else 0.8


static func recover_duration(data: BossData) -> float:
	return data.recover_duration if data != null else 1.0


static func charge_speed(data: BossData) -> float:
	return data.charge_speed if data != null else 18.0


static func charge_duration(data: BossData) -> float:
	return data.charge_duration if data != null else 0.5


static func volley_count(data: BossData) -> int:
	return data.volley_count if data != null else 5


static func volley_interval(data: BossData) -> float:
	return data.volley_shot_interval if data != null else 0.15


# ── Volley firing ─────────────────────────────────────────────────────────────
## Fire one volley shot from boss position. boss_transform = boss.global_transform.
## on_hit_callable = boss._on_volley_hit (typed callable for signal wiring).
static func fire_volley_shot(
	shot_index: int,
	data: BossData,
	boss_transform: Transform3D,
	scene_root: Node,
	on_hit_callable: Callable
) -> void:
	if data == null or data.volley_projectile_scene == null:
		return
	if scene_root == null:
		return
	var projectile := data.volley_projectile_scene.instantiate() as Projectile
	scene_root.add_child(projectile)
	projectile.top_level = true
	var count: int = volley_count(data)
	var half_spread: float = deg_to_rad(data.volley_spread_deg)
	var spread_step: float = 0.0
	if count > 1:
		spread_step = (half_spread * 2.0) / float(count - 1)
	var angle_offset: float = -half_spread + spread_step * float(shot_index)
	var spread_basis: Basis = boss_transform.basis
	spread_basis = spread_basis.rotated(Vector3.UP, angle_offset)
	var muzzle_pos: Vector3 = boss_transform.origin + Vector3(0.0, 1.2, 0.0)
	projectile.global_transform = Transform3D(spread_basis, muzzle_pos)
	projectile.hit.connect(on_hit_callable)


# ── Resistance builder ─────────────────────────────────────────────────────────
## Build a resistances dict: active_type = 1.0, all others = 0.0 (immune).
static func build_phase_resistances(active_type: DamageType.Kind) -> Dictionary:
	var res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		res[kind_int] = 0.0
	res[int(active_type)] = 1.0
	return res


# ── Mesh + SFX helpers ────────────────────────────────────────────────────────
## Collect all MeshInstance3D descendants under mesh_root.
static func collect_mesh_nodes(mesh_root: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
	return out


## Reparent SFX to scene root and play (so tail survives queue_free of owner).
static func play_death_sfx(sfx: AudioStreamPlayer, scene_root: Node) -> void:
	if not is_instance_valid(sfx) or scene_root == null:
		return
	sfx.reparent(scene_root)
	if not sfx.finished.is_connected(sfx.queue_free):
		sfx.finished.connect(sfx.queue_free)
	sfx.play()


## Create and start a repeating Timer under parent. Returns null when interval <= 0.
static func make_cycle_timer(parent: Node, interval: float, callback: Callable) -> Timer:
	if interval <= 0.0:
		return null
	var t: Timer = Timer.new()
	t.wait_time = interval
	t.one_shot = false
	parent.add_child(t)
	t.timeout.connect(callback)
	t.start()
	return t
