# entities/enemy/enemy.gd — CharacterBody3D enemy: nav + perception, driven by StateMachine.
class_name Enemy
extends Damageable

## Emitted just before queue_free() so RoomController can react (C1).
signal died(enemy: Enemy)
## Emitted when the enemy reaches attack_range of the player (C2).
signal touched_player(enemy: Enemy)
## Emitted alongside touched_player — carries self for directional knockback.
signal bumped_player(enemy: Enemy)

const _STUN_DURATION: float = 0.4
const _KNOCKBACK_SPEED: float = 14.0
const _BURN_AURA_SCENE: PackedScene = preload("res://entities/vfx/burn_aura_vfx.tscn")
const _DEFAULT_HIT_SPARK: PackedScene = preload("res://entities/vfx/hit_burst.tscn")

@export var move_speed: float = 3.5
@export var patrol_speed: float = 1.75
@export var detect_range: float = 12.0
@export var attack_range: float = 1.8
@export var escape_range: float = 16.0
@export var attack_cooldown: float = 0.8
## Non-uniform scale multiplier applied to the mesh during the attack lunge telegraph.
@export var lunge_scale: Vector3 = Vector3(1.3, 0.7, 1.3)
## Duration of each half of the lunge tween (seconds).
@export_range(0.05, 1.0, 0.01) var lunge_duration: float = 0.1
@export var patrol_wait: float = 1.0
## Archetype: when set, seeds stats+tint+behaviours in _ready(); null = use manual exports.
@export var archetype: EnemyArchetype
## Hits to kill. Tank = 3. Overridden by archetype.max_health when archetype set.
@export var health: int = 2
# score_value inherited from Damageable (default 1). Overridden by archetype.score_value.
## Player push speed (m/s) on contact. 0 = disabled. Read from archetype.push_strength.
@export_range(0.0, 30.0, 0.5) var push_strength: float = 6.0
## Max simultaneous pursuers (0 = unlimited). Shared static count in PursueState.
@export_range(0, 20, 1) var pursue_cap: int = 0
## Speed of cap-blocked enemies (fraction of move_speed); blocked enemies still advance.
@export_range(0.1, 1.0, 0.05) var blocked_advance_speed: float = 0.6
## Waypoint NodePaths (set in the level scene); resolved to Marker3D refs in _ready().
@export var patrol_waypoint_paths: Array[NodePath] = []
var patrol_waypoints: Array[Marker3D] = []
var _saved_overrides: Dictionary = {}  # MeshInstance3D → Material|null; hit-flash restore.
var _hit_flash_tween: Tween  # Tracked so _flash_and_die can kill before free.
var _flash_mats: Array[StandardMaterial3D] = []  # Held so flash_mat outlives the Tween.
var _stun_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _base_move_speed: float = 0.0  # Captured once; slow/restore never drifts.

# SEAM: ProjectSettings.get_setting() returns Variant; physics gravity is always float.
@warning_ignore("unsafe_call_argument")
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _base_scale: Vector3 = Vector3.ONE
var _burn_aura: BurnAuraVfx

@onready var attack_timer: Timer = $AttackTimer
@onready var patrol_wait_timer: Timer = $PatrolWaitTimer
## Public nav agent — states read nav.distance_to_target() for debug trace.
@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var _eye: RayCast3D = $EyeRay
@onready var _mesh_instance: Node3D = $Mesh
@onready var _death_sfx: AudioStreamPlayer = $DeathSfx
@onready var _touch_reset_sfx: AudioStreamPlayer = $TouchResetSfx
@onready var _ambient_sfx: AudioStreamPlayer3D = $EnemyAmbientSfx
@onready var _health_comp: HealthComponent = $HealthComponent
@onready var _abilities: Node = $Abilities
@onready var _status_receiver: StatusReceiver = $StatusReceiver
@onready var _state_machine: EnemyStateMachine = $StateMachine


func _ready() -> void:
	# Apply archetype stats when set (overrides manual exports).
	if archetype != null:
		health = archetype.max_health
		score_value = archetype.score_value
		move_speed = archetype.move_speed
		patrol_speed = archetype.patrol_speed
		detect_range = archetype.detect_range
		attack_range = archetype.attack_range
		escape_range = archetype.escape_range
		attack_cooldown = archetype.attack_cooldown
		push_strength = archetype.push_strength
		# Model swap before _apply_tint so tint targets the final mesh.
		if archetype.model != null:
			for child: Node in _mesh_instance.get_children():
				child.queue_free()
			_mesh_instance.add_child(archetype.model.instantiate())
		if archetype.tint_color != Color.WHITE:
			_apply_tint(archetype.tint_color)
		for scene: PackedScene in archetype.behaviours:
			var beh: Node = scene.instantiate()
			_abilities.add_child(beh)
			# SEAM: duck-typed bind — EnemyBehaviour base defines this seam.
			if beh.has_method("bind"):
				@warning_ignore("unsafe_method_access")
				beh.bind(self)
	add_to_group("enemies")
	# Child _ready() runs before parent (bottom-up); override max_health then reset.
	_health_comp.max_health = health
	if archetype != null and not archetype.resistances.is_empty():
		_health_comp.resistances = archetype.resistances
	_health_comp.reset()
	_health_comp.died.connect(_on_health_comp_died)
	_health_comp.health_changed.connect(_on_health_comp_changed)
	_base_scale = _mesh_instance.scale
	_base_move_speed = move_speed
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	patrol_wait_timer.wait_time = patrol_wait
	patrol_wait_timer.one_shot = true
	nav.velocity_computed.connect(_on_nav_velocity_computed)
	bumped_player.connect(_on_bumped_player)
	_status_receiver.slow_changed.connect(_on_slow_changed)
	_status_receiver.shock_started.connect(_on_shock_started)
	_status_receiver.shock_ended.connect(_on_shock_ended)
	_status_receiver.burn_started.connect(_on_burn_started)
	_status_receiver.burn_ended.connect(_on_burn_ended)
	_ambient_sfx.play()
	# Resolve NodePath exports to typed Marker3D refs (typed array can't store NodePaths in .tscn).
	for np: NodePath in patrol_waypoint_paths:
		var marker: Node = get_node(np)
		if marker is Marker3D:
			patrol_waypoints.append(marker as Marker3D)
		else:
			push_warning("Enemy: patrol waypoint '%s' is not a Marker3D" % np)


# ── Perception (called by states) ─────────────────────────────────────────────
func target() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func distance_to_target() -> float:
	var t: Node3D = target()
	if t == null:
		return INF
	return global_position.distance_to(t.global_position)


func can_see_target() -> bool:
	var t: Node3D = target()
	if t == null:
		return false
	_eye.target_position = _eye.to_local(t.global_position)
	_eye.force_raycast_update()
	return _eye.is_colliding() and _eye.get_collider() == t


# ── Navigation (called by states) ─────────────────────────────────────────────
func set_destination(point: Vector3) -> void:
	var dest: Vector3 = point
	for child: Node in _abilities.get_children():
		if child.has_method("pre_set_destination"):
			# SEAM: duck-typed — EnemyBehaviour.pre_set_destination (e.g. FlyingMovement clamps Y).
			@warning_ignore("unsafe_method_access")
			dest = child.pre_set_destination(dest)
			break
	nav.target_position = dest


func navigation_finished() -> bool:
	return nav.is_navigation_finished()


## Drive one frame toward current nav target at speed. Gravity + move_and_slide run here.
## Delegates to movement-role behaviour when one is bound (wants_nav_velocity == true).
func move_along_path(speed: float, delta: float) -> void:
	# Delegate to movement-role behaviour if present.
	for child: Node in _abilities.get_children():
		if child.has_method("wants_nav_velocity"):
			# SEAM: duck-typed wants_nav_velocity — EnemyBehaviour base defines this seam.
			@warning_ignore("unsafe_method_access")
			if child.wants_nav_velocity():
				@warning_ignore("unsafe_method_access")
				child.drive_move(speed, delta)
				return
	# Default: gravity-nav walk.
	var desired: Vector3 = Vector3.ZERO
	if not nav.is_navigation_finished():
		var next: Vector3 = nav.get_next_path_position()
		desired = (next - global_position)
		desired.y = 0.0
		if desired.length_squared() > 0.0001:
			desired = desired.normalized() * speed
			# Rotate body to face movement direction.
			var look_target: Vector3 = global_position + desired
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	desired.y = velocity.y
	nav.velocity = desired


func stop(delta: float) -> void:
	# Delegate to movement-role behaviour if present.
	for child: Node in _abilities.get_children():
		if child.has_method("wants_nav_velocity"):
			# SEAM: duck-typed wants_nav_velocity — EnemyBehaviour base defines this seam.
			@warning_ignore("unsafe_method_access")
			if child.wants_nav_velocity():
				@warning_ignore("unsafe_method_access")
				child.drive_stop(delta)
				return
	# Default: zero XZ + gravity.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _physics_process(delta: float) -> void:
	if _stun_timer <= 0.0:
		return
	_stun_timer -= delta
	# Decay knockback linearly to zero over the stun window.
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, _KNOCKBACK_SPEED * delta)
	velocity = _knockback_velocity
	move_and_slide()


func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	# Skip nav drive during knockback stun — _physics_process owns velocity then.
	if _stun_timer > 0.0:
		return
	# Skip if a movement-role behaviour blocks nav velocity (e.g. FlyingMovement during dive).
	for child: Node in _abilities.get_children():
		if child.has_method("blocks_nav_velocity"):
			# SEAM: duck-typed blocks_nav_velocity — EnemyBehaviour base defines this seam.
			@warning_ignore("unsafe_method_access")
			if child.blocks_nav_velocity():
				return
	velocity = safe_velocity
	move_and_slide()


## Push enemy away from hitter_pos. Stun window blocks nav for _STUN_DURATION.
## Duck-typed from player.gd — no shared type needed (godot-composition).
func apply_knockback(hitter_pos: Vector3) -> void:
	var dir: Vector3 = global_position - hitter_pos
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -global_transform.basis.z
	_knockback_velocity = dir.normalized() * _KNOCKBACK_SPEED
	_stun_timer = _STUN_DURATION


## bumped_player → shove the player; duck-typed, push_strength=0 disables.
func _on_bumped_player(_enemy: Enemy) -> void:
	if push_strength <= 0.0:
		return
	var t: Node3D = target()
	if t == null or not t.has_method("apply_knockback"):
		return
	# SEAM: duck-typed — Player.apply_knockback(hitter_pos, speed_override).
	@warning_ignore("unsafe_method_access")
	t.apply_knockback(global_position, push_strength)


# ── Attack telegraph (called by AttackState) ──────────────────────────────────
## Harmless scale-lunge telegraph + touch signal. Emits touched_player(self) each attack (C2).
## Delegates to first EnemyBehaviour with do_attack(); else default lunge + touched_player.
## NOTE: touched_player can trigger a synchronous level-load → guard with is_instance_valid.
func perform_attack() -> void:
	for child: Node in _abilities.get_children():
		if child.has_method("do_attack"):
			# SEAM: duck-typed do_attack — EnemyBehaviour base defines this seam.
			@warning_ignore("unsafe_method_access")
			child.do_attack()
			return
	# Guard: SFX may already be freed from a previous attack cycle (reparent-and-free pattern).
	if is_instance_valid(_touch_reset_sfx):
		var scene_root: Node = get_tree().current_scene
		if scene_root != null and _touch_reset_sfx.get_parent() == self:
			_touch_reset_sfx.reparent(scene_root)
			if not _touch_reset_sfx.finished.is_connected(_touch_reset_sfx.queue_free):
				_touch_reset_sfx.finished.connect(_touch_reset_sfx.queue_free)
		_touch_reset_sfx.play()
	touched_player.emit(self)
	bumped_player.emit(self)
	# Guard: signal handler may have freed this enemy (level advance/life-loss path).
	if not is_instance_valid(self):
		return
	var tw: Tween = create_tween()
	tw.tween_property(_mesh_instance, "scale", _base_scale * lunge_scale, lunge_duration)
	tw.tween_property(_mesh_instance, "scale", _base_scale, lunge_duration)


# ── Shootability ──────────────────────────────────────────────────────────────
## Duck-typed hit seam (godot-fps-enemy-combat) — aliases apply_damage(1).
func on_hit() -> void:
	apply_damage(1)


## Apply typed damage via HealthComponent. ShieldComponent absorbs first; overflow to health.
func apply_damage(amount: int, type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
	var shield: ShieldComponent = get_node_or_null("ShieldComponent") as ShieldComponent
	var overflow: int = amount
	if shield != null:
		overflow = shield.absorb(amount)
	if overflow > 0:
		_health_comp.apply_damage(overflow, type)


# ── Status effect seams (called by StatusReceiver via duck-typed add_status_X) ────────────
func add_status_burn(dps: int, duration: float, type: DamageType.Kind) -> void:
	_status_receiver.add_status_burn(dps, duration, type)


func add_status_slow(factor: float, duration: float) -> void:
	_status_receiver.add_status_slow(factor, duration)


func add_status_shock(stun_duration: float) -> void:
	_status_receiver.add_status_shock(stun_duration)


func _on_slow_changed(factor: float) -> void:
	move_speed = _base_move_speed * factor


func _on_shock_started() -> void:
	_stun_timer = INF


func _on_shock_ended() -> void:
	_stun_timer = 0.0
	_knockback_velocity = Vector3.ZERO


## StatusReceiver.burn_started → attach looping burn/poison aura VFX.
func _on_burn_started(is_poison: bool) -> void:
	if is_instance_valid(_burn_aura):
		_burn_aura.extinguish()
	_burn_aura = _BURN_AURA_SCENE.instantiate() as BurnAuraVfx
	_burn_aura.is_poison = is_poison
	add_child(_burn_aura)


## StatusReceiver.burn_ended → extinguish and clear aura.
func _on_burn_ended() -> void:
	if is_instance_valid(_burn_aura):
		_burn_aura.extinguish()
	_burn_aura = null


## HealthComponent.health_changed → non-fatal hit flash (current > 0: died fires only at 0).
func _on_health_comp_changed(current: int, _max: int) -> void:
	if current > 0:
		_flash_hit()


## HealthComponent.died → death sequence (mirrors old fatal branch of apply_damage).
func _on_health_comp_died() -> void:
	# Transition FSM before dying so PursueState.exit() releases the pursue-cap slot.
	if _state_machine != null:
		_state_machine.transition_to("PatrolState")
	_play_death_sfx()
	died.emit(self)
	_flash_and_die()


## Brief non-fatal hit flash: archetype-driven color+duration, spark VFX, optional hitstop.
func _flash_hit() -> void:
	var mesh_nodes: Array[MeshInstance3D] = []
	for child: Node in _mesh_instance.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			mesh_nodes.append(child as MeshInstance3D)
	if mesh_nodes.is_empty():
		return
	# Read per-archetype feedback params; fall back to safe defaults when no archetype set.
	var flash_color: Color = Color(1.0, 0.1, 0.1, 1.0)
	var flash_dur: float = 0.05
	var hitstop: float = 0.0
	var spark_scene: PackedScene = _DEFAULT_HIT_SPARK
	if archetype != null:
		flash_color = archetype.hit_flash_color
		flash_dur = archetype.hit_flash_duration
		hitstop = archetype.hitstop_seconds
		if archetype.hit_spark_scene != null:
			spark_scene = archetype.hit_spark_scene
	# Restore previous overrides FIRST so the RS never sees the old hit_mat as a dead
	# material RID. Only THEN kill the old tween (which releases the old hit_mat refs).
	# Wrong order (prior bug): clear saved → kill tween → hit_mat freed while still override.
	_restore_materials()
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	_saved_overrides.clear()
	_hit_flash_tween = create_tween()
	var tw: Tween = _hit_flash_tween
	tw.set_parallel(true)
	for mi: MeshInstance3D in mesh_nodes:
		# Save current override (may be the tint mat set by runner/tank _ready).
		_saved_overrides[mi] = mi.get_surface_override_material(0)
		var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var hit_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, hit_mat)
		hit_mat.emission_enabled = true
		tw.tween_property(hit_mat, "albedo_color", flash_color, flash_dur)
		tw.tween_property(hit_mat, "emission", flash_color, flash_dur)
	tw.set_parallel(false)
	# Restore saved overrides so runner/tank tint reappears after flash.
	tw.tween_callback(_restore_materials)
	# Spawn hit spark VFX at enemy world position (fire-and-free, under scene root).
	EnemyFlashHelper.spawn_hit_spark(
		get_tree().current_scene, spark_scene, global_position + Vector3(0.0, 0.9, 0.0)
	)
	# Optional hitstop: brief time_scale dip then restore.
	if hitstop > 0.0:
		EnemyFlashHelper.apply_hitstop(self, hitstop)


## Restore per-mesh overrides saved before the last hit flash.
func _restore_materials() -> void:
	for key: Variant in _saved_overrides.keys():
		if not key is MeshInstance3D:
			continue
		# SEAM: key=MeshInstance3D, value=Material|null, by construction (_flash_hit only writes).
		@warning_ignore("unsafe_cast")
		var mesh_inst: MeshInstance3D = key as MeshInstance3D
		@warning_ignore("unsafe_cast")
		mesh_inst.set_surface_override_material(0, _saved_overrides[key] as Material)
	_saved_overrides.clear()


## Make materials unique, flash white (albedo + emission) on all mesh parts, then free.
func _flash_and_die() -> void:
	# Restore first so RS visual instances point to tint/base mats (valid), then kill the
	# hit-flash tween (which releases old hit_mat refs). Wrong prior order was kill→restore:
	# the kill freed hit_mat while it was still the active RS override → null-material burst.
	_restore_materials()
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	# Collect every MeshInstance3D under the mesh wrapper (kitbash has one per part).
	var mesh_nodes: Array[MeshInstance3D] = []
	for child: Node in _mesh_instance.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			mesh_nodes.append(child as MeshInstance3D)
	if mesh_nodes.is_empty():
		queue_free()
		return
	_flash_mats.clear()
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	for mi: MeshInstance3D in mesh_nodes:
		var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		# Unique copy — prevents flashing all enemies sharing the same material resource.
		var flash_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, flash_mat)
		flash_mat.emission_enabled = true
		tw.tween_property(flash_mat, "albedo_color", Color.WHITE, 0.06)
		tw.tween_property(flash_mat, "emission", Color.WHITE, 0.06)
		# Hold ref in member array so flash_mat outlives the Tween until _die_and_clear_mats
		# unlinks the override from the RS — prevents null-material RID query at RS teardown.
		_flash_mats.append(flash_mat)
	tw.set_parallel(false)
	tw.tween_callback(_die_and_clear_mats)


## Clear surface overrides BEFORE queue_free so flash_mats are unlinked from RS visual
## instances before node teardown. Without this, flash_mat RIDs can be freed mid-render.
func _die_and_clear_mats() -> void:
	for child: Node in _mesh_instance.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			(child as MeshInstance3D).set_surface_override_material(0, null)
	_flash_mats.clear()
	queue_free()


## Apply flat albedo tint to all MeshInstance3D parts (archetype tint_color).
func _apply_tint(color: Color) -> void:
	for child: Node in _mesh_instance.find_children("*", "MeshInstance3D", true, false):
		if not child is MeshInstance3D:
			continue
		var mi: MeshInstance3D = child as MeshInstance3D
		var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
		if mat == null:
			continue
		var tint_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		tint_mat.albedo_color = color
		mi.set_surface_override_material(0, tint_mat)


func _play_death_sfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_ambient_sfx.stop()
	_death_sfx.reparent(scene_root)
	if not _death_sfx.finished.is_connected(_death_sfx.queue_free):
		_death_sfx.finished.connect(_death_sfx.queue_free)
	_death_sfx.play()
