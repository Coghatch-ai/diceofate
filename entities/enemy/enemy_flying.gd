# entities/enemy/enemy_flying.gd — Stinger: hovering melee dive-bomber.
# Overrides move_along_path/stop (no gravity — holds altitude) and perform_attack (dive tween).
# Inherits full killable contract verbatim: on_hit/died/score_value from Enemy.
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")

## Target hover altitude above the navmesh floor (metres).
@export var hover_height: float = 3.0
## Vertical bob amplitude (metres, peak-to-peak = 2x).
@export var bob_amplitude: float = 0.4
## Bob oscillation frequency (radians/sec).
@export var bob_speed: float = 2.0
## XZ tracking speed while hovering (m/s). Separate from move_speed used by base FSM.
@export var hover_track_speed: float = 2.0
## Duration of the dive lunge to the player (seconds).
@export var dive_time: float = 0.85
## Duration of the return rise back to hover height (seconds).
@export var rise_time: float = 1.1

# Accumulated time for bob sine — never reset so bob is continuous.
var _bob_time: float = 0.0
# Guard: prevents re-entering perform_attack while a dive tween is running.
var _diving: bool = false
# Y of the ground at spawn; hover_height is offset from this.
var _floor_y: float = 0.0
# Active dive tween — kept so _on_dive_impact can chain the rise phase.
var _dive_tween: Tween = null


func _ready() -> void:
	super._ready()
	score_value = 3
	_apply_stinger_tint()
	# Defer hover lift: _ready() fires on add_child() BEFORE the wave manager sets
	# global_position. Capturing _floor_y here would lock it to origin (0,0,0).
	# call_deferred runs after the current frame, by which time global_position is real.
	_init_hover.call_deferred()


func _init_hover() -> void:
	_floor_y = global_position.y
	global_position.y = _floor_y + hover_height


func _apply_stinger_tint() -> void:
	var mesh_root: Node3D = $Mesh
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ART_STYLE.ENEMY_STINGER_MID
			mat.emission_enabled = true
			mat.emission = ART_STYLE.ENEMY_STINGER_LIGHT
			mat.emission_energy_multiplier = 0.4
			mi.set_surface_override_material(0, mat)


## Override: clamp destination Y to floor level so the nav agent operates on the flat navmesh.
## Chase/patrol states pass the player/waypoint world position (including their Y); flying enemies
## hover above the navmesh, so the raw Y makes the agent query an off-mesh point and
## is_navigation_finished() returns true immediately (unreachable target). Clamping to _floor_y
## keeps the path query on the walkable surface; altitude is handled by the Y-spring in
## move_along_path independently.
func set_destination(point: Vector3) -> void:
	var floor_point: Vector3 = Vector3(point.x, _floor_y, point.z)
	super.set_destination(floor_point)


## Override: hold altitude + bob + XZ-track player via navmesh. NO gravity, NO super call.
## During a dive tween, skip all physics movement — the tween owns global_position.
func move_along_path(_speed: float, delta: float) -> void:
	if _diving:
		return
	_bob_time += delta
	var target_y: float = _floor_y + hover_height + sin(_bob_time * bob_speed) * bob_amplitude

	var xz_vel: Vector3 = Vector3.ZERO
	if not _nav.is_navigation_finished():
		var next: Vector3 = _nav.get_next_path_position()
		var xz_dir: Vector3 = next - global_position
		xz_dir.y = 0.0
		if xz_dir.length_squared() > 0.0001:
			xz_dir = xz_dir.normalized()
			xz_vel = xz_dir * hover_track_speed
			var look_target: Vector3 = global_position + xz_dir
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)

	# Y spring: proportional pull toward target_y — floaty feel, not rigid snap.
	var y_vel: float = (target_y - global_position.y) * 8.0
	velocity = Vector3(xz_vel.x, y_vel, xz_vel.z)
	move_and_slide()


## Override: hold hover/bob in place (zero XZ). NO gravity, NO super call.
## During a dive tween, skip all physics movement — the tween owns global_position.
func stop(delta: float) -> void:
	if _diving:
		return
	_bob_time += delta
	var target_y: float = _floor_y + hover_height + sin(_bob_time * bob_speed) * bob_amplitude
	velocity = Vector3(0.0, (target_y - global_position.y) * 8.0, 0.0)
	move_and_slide()


## Override: block nav-velocity callbacks during dive so the nav server can't push velocity
## that fights the tween. Base class connects this in _ready(); virtual dispatch routes here.
func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	if _diving:
		return
	velocity = safe_velocity
	move_and_slide()


## Override: LOS-gated dive-bomb. Two-phase tween: dive → impact callback → rise.
func perform_attack() -> void:
	if _diving:
		return
	if not can_see_target():
		return
	var t: Node3D = target()
	if t == null:
		return
	_diving = true

	var dive_dest: Vector3 = t.global_position + Vector3(0.0, 0.9, 0.0)

	_dive_tween = create_tween()
	_dive_tween.tween_property(self, "global_position", dive_dest, dive_time).set_trans(
		Tween.TRANS_SINE
	)
	_dive_tween.tween_callback(_on_dive_impact)


func _on_dive_impact() -> void:
	if not is_instance_valid(self):
		return
	touched_player.emit(self)
	bumped_player.emit(self)
	if not is_instance_valid(self):
		return
	# Build rise phase now, using current XZ position captured post-dive.
	var return_pos: Vector3 = Vector3(global_position.x, _floor_y + hover_height, global_position.z)
	var rise_tween: Tween = create_tween()
	rise_tween.tween_property(self, "global_position", return_pos, rise_time).set_trans(
		Tween.TRANS_SINE
	)
	rise_tween.tween_callback(func() -> void: _diving = false)
