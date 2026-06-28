# entities/boss/boss.gd — Boss CharacterBody3D: data-driven attack-component loop.
# Attack set is ordered Array[PackedScene] of BossAttack components from BossData.attacks.
# Color-phase schedule + optional timer cycle remain unchanged.
# Volley data fields kept on BossData for forward-compat; volley attack is parked (no component).
class_name Boss
extends Damageable

signal died(boss: Boss)
signal touched_player(boss: Boss)
## color_index = new phase index. albedo/emission from BossColorPhase.
signal color_changed(color_index: int, albedo: Color, emission: Color)

enum Phase { IDLE, TELEGRAPH, EXECUTING, RECOVER, DEAD }

const _TELEGRAPH_SCALE: Vector3 = Vector3(1.15, 0.85, 1.15)

@export var data: BossData
@export var hit_flash_color: Color = Color(1.0, 0.15, 0.15, 1.0)
@export_range(1, 500, 1) var health: int = 8
# score_value inherited from Damageable; _ready() sets it from data.score_value.
# Runtime state
var _phase: Phase = Phase.IDLE
var _phase_timer: float = 0.0
var _attack_index: int = 0
# Bound BossAttack node for the current mechanic slot.
var _current_attack: BossAttack = null
var _in_phase2: bool = false
var _saved_overrides: Dictionary = {}
var _base_scale: Vector3 = Vector3.ONE
# Color-phase state
var _color_phase_index: int = -1
var _display_color_index: int = 0
var _phase_hp_remaining: int = 0
var _color_phases_active: bool = false
var _prev_total_hp: int = -1
var _color_cycle_timer: Timer
# SEAM: ProjectSettings.get_setting() returns Variant; explicit float conversion needed.
@warning_ignore("unsafe_call_argument")
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@onready var _health_comp: HealthComponent = $HealthComponent
@onready var _mesh_node: Node3D = $Mesh
@onready var _death_sfx: AudioStreamPlayer = $DeathSfx
@onready var _attacks_node: Node = $Attacks


func _ready() -> void:
	if data != null:
		health = data.max_health
		score_value = data.score_value
		if not is_equal_approx(data.body_scale, 1.0):
			_mesh_node.scale = Vector3.ONE * data.body_scale
			var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col != null:
				col.scale = Vector3.ONE * data.body_scale
				col.position.y = col.position.y * data.body_scale
		if data.color_phases.is_empty():
			if not data.resistances.is_empty():
				_health_comp.resistances = data.resistances
		else:
			var total_hp: int = 0
			for cp: BossColorPhase in data.color_phases:
				total_hp += cp.phase_hp
			health = total_hp
			_color_phases_active = true
		# Instance attack components.
		for scene: PackedScene in data.attacks:
			var atk: Node = scene.instantiate()
			_attacks_node.add_child(atk)
			if atk.has_method("bind"):
				# SEAM: BossAttack.bind(boss) contract — proven by PackedScene from data.attacks.
				@warning_ignore("unsafe_method_access")
				atk.bind(self)
	_health_comp.max_health = health
	_health_comp.reset()
	_prev_total_hp = health
	_health_comp.died.connect(_on_health_comp_died)
	_health_comp.health_changed.connect(_on_health_comp_changed)
	_base_scale = _mesh_node.scale
	_phase = Phase.IDLE
	_phase_timer = BossMechanics.idle_duration(data, _in_phase2)
	if _color_phases_active:
		_display_color_index = 0
		_enter_color_phase(0)
		var interval: float = data.color_cycle_interval if data != null else 0.0
		_color_cycle_timer = BossMechanics.make_cycle_timer(self, interval, _on_color_cycle_timeout)


# ── Physics ────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _phase == Phase.DEAD:
		return
	_phase_timer -= delta
	match _phase:
		Phase.IDLE:
			_tick_idle(delta)
		Phase.TELEGRAPH:
			_tick_telegraph(delta)
		Phase.EXECUTING:
			_tick_executing(delta)
		Phase.RECOVER:
			_tick_recover(delta)


# ── Color-phase system ─────────────────────────────────────────────────────────
func _enter_color_phase(index: int) -> void:
	if data == null or data.color_phases.is_empty():
		return
	_color_phase_index = index
	var cp: BossColorPhase = data.color_phases[index]
	_phase_hp_remaining = cp.phase_hp
	_health_comp.resistances = BossMechanics.build_phase_resistances(cp.damage_type)
	var target_scale: Vector3 = Vector3.ONE * cp.body_scale
	_base_scale = target_scale
	if index == 0:
		_mesh_node.scale = target_scale
		var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			col.scale = target_scale
	else:
		if is_inside_tree():
			var tw: Tween = create_tween()
			tw.tween_property(_mesh_node, "scale", target_scale, 0.35)
			var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col != null:
				tw.parallel().tween_property(col, "scale", target_scale, 0.35)
		else:
			_mesh_node.scale = target_scale
	color_changed.emit(index, cp.albedo, cp.emission)


func _advance_color_phase() -> void:
	var next: int = _color_phase_index + 1
	if data == null or next >= data.color_phases.size():
		_phase = Phase.DEAD
		if _color_cycle_timer != null and not _color_cycle_timer.is_stopped():
			_color_cycle_timer.stop()
		_explode()
	else:
		_enter_color_phase(next)
		_display_color_index = next


## Cycle displayed vulnerability color without consuming an HP chunk.
func _on_color_cycle_timeout() -> void:
	if _phase == Phase.DEAD or not _color_phases_active:
		return
	if data == null or data.color_phases.is_empty():
		return
	_display_color_index = (_display_color_index + 1) % data.color_phases.size()
	var cp: BossColorPhase = data.color_phases[_display_color_index]
	_health_comp.resistances = BossMechanics.build_phase_resistances(cp.damage_type)
	color_changed.emit(_display_color_index, cp.albedo, cp.emission)


func _explode() -> void:
	var radius: float = data.explode_radius if data != null else 8.0
	var dmg: int = data.explode_damage if data != null else 60
	var impulse: float = data.explode_knockback if data != null else 20.0
	var p: Node3D = _player() if is_inside_tree() else null
	if p != null and radius > 0.0:
		var dist: float = global_position.distance_to(p.global_position)
		if dist <= radius:
			if p.has_method("apply_damage"):
				# SEAM: duck-typed apply_damage.
				@warning_ignore("unsafe_method_access")
				p.apply_damage(dmg)
			if p.has_method("apply_knockback"):
				# SEAM: duck-typed apply_knockback(hitter_pos, speed_override).
				@warning_ignore("unsafe_method_access")
				p.apply_knockback(global_position, impulse)
	if is_inside_tree():
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			if data != null and data.explode_vfx_scene != null:
				var ring: Node3D = data.explode_vfx_scene.instantiate() as Node3D
				scene_root.add_child(ring)
				ring.global_position = global_position
			if data != null and data.explode_burst_scene != null:
				var burst: Node3D = data.explode_burst_scene.instantiate() as Node3D
				scene_root.add_child(burst)
				burst.global_position = global_position
	_play_death_sfx()
	died.emit(self)
	queue_free()


# ── Perception helpers ─────────────────────────────────────────────────────────
func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _face_player() -> void:
	var p: Node3D = _player()
	if p == null:
		return
	var look_target: Vector3 = p.global_position
	look_target.y = global_position.y
	if look_target.distance_squared_to(global_position) > 0.001:
		look_at(look_target, Vector3.UP)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


## Drive XZ toward the player during idle/recover at idle_move_speed.
## Always-moving contract: velocity.x/z are never zeroed here.
func _drive_idle_movement(_delta: float) -> void:
	var speed: float = data.idle_move_speed if data != null else 2.5
	if is_equal_approx(speed, 0.0):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var p: Node3D = _player()
	if p == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir: Vector3 = p.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		_face_player()
		velocity.x = dir.normalized().x * speed
		velocity.z = dir.normalized().z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Slow drift toward player during telegraph — keeps presence without dash.
func _drive_telegraph_drift(_delta: float) -> void:
	var speed: float = data.telegraph_drift_speed if data != null else 1.0
	if is_equal_approx(speed, 0.0):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var p: Node3D = _player()
	if p == null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir: Vector3 = p.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		velocity.x = dir.normalized().x * speed
		velocity.z = dir.normalized().z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0


# ── Phase ticks ───────────────────────────────────────────────────────────────
func _tick_idle(delta: float) -> void:
	_apply_gravity(delta)
	_drive_idle_movement(delta)
	move_and_slide()
	if _phase_timer <= 0.0:
		_enter_telegraph()


func _tick_telegraph(delta: float) -> void:
	_apply_gravity(delta)
	_face_player()
	_drive_telegraph_drift(delta)
	move_and_slide()
	if _phase_timer <= 0.0:
		_enter_executing()


func _tick_executing(delta: float) -> void:
	_apply_gravity(delta)
	if _current_attack != null:
		var done: bool = _current_attack.tick(delta)
		move_and_slide()
		if done:
			_enter_recover()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_enter_recover()


func _tick_recover(delta: float) -> void:
	_apply_gravity(delta)
	_drive_idle_movement(delta)
	move_and_slide()
	if _phase_timer <= 0.0:
		_advance_attack()
		_mesh_node.scale = _base_scale
		_phase = Phase.IDLE
		_phase_timer = BossMechanics.idle_duration(data, _in_phase2)


# ── Phase entry ────────────────────────────────────────────────────────────────
func _enter_telegraph() -> void:
	_pick_next_attack()
	var tel_dur: float = (
		_current_attack.telegraph_duration()
		if _current_attack != null
		else BossMechanics.telegraph_duration(data)
	)
	_phase = Phase.TELEGRAPH
	_phase_timer = tel_dur
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_mesh_node, "scale", _TELEGRAPH_SCALE * _base_scale, 0.15)
	tw.chain().tween_property(_mesh_node, "scale", _base_scale, 0.1)


func _enter_executing() -> void:
	_phase = Phase.EXECUTING
	if _current_attack != null:
		_current_attack.start()


func _enter_recover() -> void:
	var rec_dur: float = (
		_current_attack.recover_duration()
		if _current_attack != null
		else BossMechanics.recover_duration(data)
	)
	_phase = Phase.RECOVER
	_phase_timer = rec_dur


# ── Attack-component selection ─────────────────────────────────────────────────
## Pick the attack node at _attack_index (does NOT advance the index yet).
func _pick_next_attack() -> void:
	var children: Array[Node] = _attacks_node.get_children()
	if children.is_empty():
		_current_attack = null
		return
	var idx: int = _attack_index % children.size()
	var node: Node = children[idx]
	if node is BossAttack:
		_current_attack = node as BossAttack
	else:
		_current_attack = null


## Advance the round-robin index AFTER recover completes.
func _advance_attack() -> void:
	var children: Array[Node] = _attacks_node.get_children()
	if children.is_empty():
		return
	_attack_index = (_attack_index + 1) % children.size()


# ── Shootability seam (godot-fps-enemy-combat contract) ───────────────────────
func on_hit() -> void:
	var hc: HealthComponent = _get_health_comp()
	if hc != null:
		hc.apply_damage(1)


func apply_damage(amount: int, type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
	var hc: HealthComponent = _get_health_comp()
	if hc != null:
		hc.apply_damage(amount, type)


func _get_health_comp() -> HealthComponent:
	if _health_comp != null:
		return _health_comp
	return get_node_or_null("HealthComponent") as HealthComponent


# ── HealthComponent callbacks ─────────────────────────────────────────────────
func _on_health_comp_changed(current: int, max_hp: int) -> void:
	if _color_phases_active and _color_phase_index >= 0 and _prev_total_hp >= 0:
		var delta: int = _prev_total_hp - current
		if delta > 0:
			_phase_hp_remaining -= delta
			if _phase_hp_remaining <= 0:
				var overflow: int = -_phase_hp_remaining
				_prev_total_hp = current + overflow
				_health_comp.heal(overflow)
				_advance_color_phase()
				return
	_prev_total_hp = current
	if current > 0:
		_flash_hit()
	if not _in_phase2 and data != null and data.phase2_hp_fraction > 0.0:
		var frac: float = float(current) / float(max_hp)
		if frac <= data.phase2_hp_fraction:
			_in_phase2 = true


func _on_health_comp_died() -> void:
	if _color_phases_active:
		if _phase != Phase.DEAD:
			_phase = Phase.DEAD
			_explode()
		return
	_phase = Phase.DEAD
	_play_death_sfx()
	died.emit(self)
	_flash_and_die()


# ── Visual feedback ────────────────────────────────────────────────────────────
func _flash_hit() -> void:
	var mesh_nodes: Array[MeshInstance3D] = BossMechanics.collect_mesh_nodes(_mesh_node)
	if mesh_nodes.is_empty():
		return
	_saved_overrides.clear()
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for mi: MeshInstance3D in mesh_nodes:
		_saved_overrides[mi] = mi.get_surface_override_material(0)
		var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var hit_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, hit_mat)
		hit_mat.emission_enabled = true
		tw.tween_property(hit_mat, "albedo_color", hit_flash_color, 0.06)
		tw.tween_property(hit_mat, "emission", hit_flash_color, 0.06)
	tw.set_parallel(false)
	tw.tween_callback(_restore_materials)


func _restore_materials() -> void:
	for key: Variant in _saved_overrides.keys():
		if not key is MeshInstance3D:
			continue
		# SEAM: key/value are MeshInstance3D / Material by construction (_flash_hit).
		@warning_ignore("unsafe_cast")
		var mi: MeshInstance3D = key as MeshInstance3D
		@warning_ignore("unsafe_cast")
		mi.set_surface_override_material(0, _saved_overrides[key] as Material)
	_saved_overrides.clear()


func _flash_and_die() -> void:
	var mesh_nodes: Array[MeshInstance3D] = BossMechanics.collect_mesh_nodes(_mesh_node)
	if mesh_nodes.is_empty():
		queue_free()
		return
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for mi: MeshInstance3D in mesh_nodes:
		var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var flash_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, flash_mat)
		flash_mat.emission_enabled = true
		tw.tween_property(flash_mat, "albedo_color", Color.WHITE, 0.08)
		tw.tween_property(flash_mat, "emission", Color.WHITE, 0.08)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


func _play_death_sfx() -> void:
	BossMechanics.play_death_sfx(_death_sfx, get_tree().current_scene)


## Emit touched_player(self) — called by BossAttack components (e.g. ChargeAttack) on contact.
## Declared here (not just on the emitter) so the public signal contract is visible on Boss.
func notify_touched_player() -> void:
	touched_player.emit(self)
