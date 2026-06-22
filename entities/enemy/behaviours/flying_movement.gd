# entities/enemy/behaviours/flying_movement.gd — FlyingMovement: hover/bob/no-gravity + dive attack.
# Movement-role behaviour extracted from enemy_flying.gd for trait-mixing.
class_name FlyingMovement
extends EnemyBehaviour

const ART_STYLE := preload("res://tools/art_style.gd")

@export_group("Hover")
## Target hover altitude above navmesh floor (metres).
@export_range(0.5, 20.0, 0.5) var hover_height: float = 3.0
## Vertical bob amplitude (metres, peak-to-peak = 2x).
@export_range(0.0, 2.0, 0.05) var bob_amplitude: float = 0.4
## Bob oscillation frequency (radians/sec).
@export_range(0.1, 10.0, 0.1) var bob_speed: float = 2.0
## XZ tracking speed while hovering (m/s).
@export_range(0.5, 20.0, 0.5) var hover_track_speed: float = 2.0

@export_group("Dive")
## Duration of dive lunge to player (seconds).
@export_range(0.2, 3.0, 0.05) var dive_time: float = 0.85
## Duration of rise back to hover height (seconds).
@export_range(0.2, 4.0, 0.05) var rise_time: float = 1.1

# Injected enemy ref.
var _enemy: Enemy = null
# Accumulated time for bob sine — never reset so bob is continuous.
var _bob_time: float = 0.0
# Guard: prevents re-entering do_attack while a dive tween runs.
var _diving: bool = false
# Y of the ground at spawn; hover_height is offset from this.
var _floor_y: float = 0.0


func bind(enemy: Node) -> void:
	_enemy = enemy as Enemy
	_apply_stinger_tint()
	# Defer hover lift: bind() fires in _ready() BEFORE wave manager sets global_position.
	_init_hover.call_deferred()


## Movement role: take over from default nav walk.
func wants_nav_velocity() -> bool:
	return true


## Block nav-velocity callbacks during dive so nav server can't fight the tween.
func blocks_nav_velocity() -> bool:
	return _diving


## Clamp destination Y to floor level so nav agent queries the flat walkable surface.
func pre_set_destination(point: Vector3) -> Vector3:
	return Vector3(point.x, _floor_y, point.z)


## Movement role: hold altitude + bob + XZ-track via navmesh. No gravity.
func drive_move(_speed: float, delta: float) -> void:
	if _enemy == null or _diving:
		return
	_bob_time += delta
	var target_y: float = _floor_y + hover_height + sin(_bob_time * bob_speed) * bob_amplitude
	var xz_vel: Vector3 = Vector3.ZERO
	# Access NavigationAgent3D via typed path on Enemy (public node).
	var nav: NavigationAgent3D = _enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav != null and not nav.is_navigation_finished():
		var next: Vector3 = nav.get_next_path_position()
		var xz_dir: Vector3 = next - _enemy.global_position
		xz_dir.y = 0.0
		if xz_dir.length_squared() > 0.0001:
			xz_dir = xz_dir.normalized()
			xz_vel = xz_dir * hover_track_speed
			var look_target: Vector3 = _enemy.global_position + xz_dir
			look_target.y = _enemy.global_position.y
			_enemy.look_at(look_target, Vector3.UP)
	var y_vel: float = (target_y - _enemy.global_position.y) * 8.0
	_enemy.velocity = Vector3(xz_vel.x, y_vel, xz_vel.z)
	_enemy.move_and_slide()


## Movement role: hold hover/bob in place (zero XZ). No gravity.
func drive_stop(delta: float) -> void:
	if _enemy == null or _diving:
		return
	_bob_time += delta
	var target_y: float = _floor_y + hover_height + sin(_bob_time * bob_speed) * bob_amplitude
	var y_vel: float = (target_y - _enemy.global_position.y) * 8.0
	_enemy.velocity = Vector3(0.0, y_vel, 0.0)
	_enemy.move_and_slide()


## Attack role: LOS-gated dive-bomb. Two-phase: dive → impact → rise.
func do_attack() -> void:
	if _enemy == null or _diving:
		return
	if not _enemy.can_see_target():
		return
	var t: Node3D = _enemy.target()
	if t == null:
		return
	_diving = true
	var dive_dest: Vector3 = t.global_position + Vector3(0.0, 0.9, 0.0)
	var dive_tween: Tween = _enemy.create_tween()
	dive_tween.tween_property(_enemy, "global_position", dive_dest, dive_time).set_trans(
		Tween.TRANS_SINE
	)
	dive_tween.tween_callback(_on_dive_impact)


func _on_dive_impact() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	_enemy.touched_player.emit(_enemy)
	_enemy.bumped_player.emit(_enemy)
	if not is_instance_valid(_enemy):
		return
	var return_pos: Vector3 = Vector3(
		_enemy.global_position.x, _floor_y + hover_height, _enemy.global_position.z
	)
	var rise_tween: Tween = _enemy.create_tween()
	rise_tween.tween_property(_enemy, "global_position", return_pos, rise_time).set_trans(
		Tween.TRANS_SINE
	)
	rise_tween.tween_callback(func() -> void: _diving = false)


func _init_hover() -> void:
	if _enemy == null:
		return
	_floor_y = _enemy.global_position.y
	_enemy.global_position.y = _floor_y + hover_height


func _apply_stinger_tint() -> void:
	if _enemy == null:
		return
	var mesh_root: Node3D = _enemy.get_node_or_null("Mesh") as Node3D
	if mesh_root == null:
		return
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ART_STYLE.ENEMY_STINGER_MID
			mat.emission_enabled = true
			mat.emission = ART_STYLE.ENEMY_STINGER_LIGHT
			mat.emission_energy_multiplier = 0.4
			mi.set_surface_override_material(0, mat)
