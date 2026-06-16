# entities/enemy/enemy.gd — CharacterBody3D enemy: nav + perception, driven by StateMachine.
class_name Enemy
extends CharacterBody3D

## Emitted just before queue_free() so WaveManager can react (C1).
signal died(enemy: Enemy)
## Emitted when the enemy reaches attack_range of the player (C2).
signal touched_player(enemy: Enemy)

@export var move_speed: float = 3.5
@export var patrol_speed: float = 1.75
@export var detect_range: float = 12.0
@export var attack_range: float = 1.8
@export var escape_range: float = 16.0
@export var attack_cooldown: float = 0.8
@export var patrol_wait: float = 1.0
## Waypoint NodePaths (set in the level scene); resolved to Marker3D refs in _ready().
@export var patrol_waypoint_paths: Array[NodePath] = []
var patrol_waypoints: Array[Marker3D] = []

# SEAM: ProjectSettings.get_setting() returns Variant; physics gravity is always float.
@warning_ignore("unsafe_call_argument")
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
# Base scale saved on ready for telegraph reset.
var _base_scale: Vector3 = Vector3.ONE

@onready var attack_timer: Timer = $AttackTimer
@onready var patrol_wait_timer: Timer = $PatrolWaitTimer
@onready var _nav: NavigationAgent3D = $NavigationAgent3D
@onready var _eye: RayCast3D = $EyeRay
@onready var _mesh_instance: Node3D = $Mesh
@onready var _death_sfx: AudioStreamPlayer = $DeathSfx
@onready var _touch_reset_sfx: AudioStreamPlayer = $TouchResetSfx
@onready var _ambient_sfx: AudioStreamPlayer3D = $EnemyAmbientSfx


func _ready() -> void:
	_base_scale = _mesh_instance.scale
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	patrol_wait_timer.wait_time = patrol_wait
	patrol_wait_timer.one_shot = true
	_nav.velocity_computed.connect(_on_nav_velocity_computed)
	_ambient_sfx.play()
	# Resolve NodePath exports to typed Marker3D refs (typed Array[Marker3D] can't be
	# stored as NodePaths in hand-authored .tscn; we resolve here at runtime).
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
	# Ray hits player → unobstructed line of sight. Hits anything else → wall blocks.
	return _eye.is_colliding() and _eye.get_collider() == t


# ── Navigation (called by states) ─────────────────────────────────────────────
func set_destination(point: Vector3) -> void:
	_nav.target_position = point


func navigation_finished() -> bool:
	return _nav.is_navigation_finished()


## Drive one frame toward current nav target at speed. Gravity + move_and_slide run here.
func move_along_path(speed: float, delta: float) -> void:
	var desired: Vector3 = Vector3.ZERO
	if not _nav.is_navigation_finished():
		var next: Vector3 = _nav.get_next_path_position()
		desired = (next - global_position)
		desired.y = 0.0
		desired = desired.normalized() * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	desired.y = velocity.y
	_nav.velocity = desired


func stop(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()


# ── Attack telegraph (called by AttackState) ──────────────────────────────────
## Harmless scale-lunge telegraph + touch signal. Emits touched_player(self) each attack (C2).
func perform_attack() -> void:
	print("Enemy attack telegraph!")
	_touch_reset_sfx.play()
	touched_player.emit(self)
	var tw: Tween = create_tween()
	tw.tween_property(_mesh_instance, "scale", _base_scale * Vector3(1.3, 0.7, 1.3), 0.1)
	tw.tween_property(_mesh_instance, "scale", _base_scale, 0.1)


# ── Shootability ──────────────────────────────────────────────────────────────
## Called by the projectile via duck-typed on_hit() — same contract as target.gd.
func on_hit() -> void:
	_play_death_sfx()
	died.emit(self)
	_flash_and_die()


## Make materials unique, flash white (albedo + emission) on all mesh parts, then free.
func _flash_and_die() -> void:
	# Collect every MeshInstance3D under the mesh wrapper (kitbash has one per part).
	var mesh_nodes: Array[MeshInstance3D] = []
	for child: Node in _mesh_instance.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			mesh_nodes.append(child as MeshInstance3D)
	if mesh_nodes.is_empty():
		queue_free()
		return
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
	tw.set_parallel(false)
	tw.tween_callback(queue_free)


# Reparent death sfx to scene root so it survives queue_free() on this node.
func _play_death_sfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_ambient_sfx.stop()
	_death_sfx.reparent(scene_root)
	_death_sfx.finished.connect(_death_sfx.queue_free)
	_death_sfx.play()
