# entities/weapon/gun.gd — firing component: spawns projectiles from a Muzzle, timer-gated.
# Per-bullet-type ammo gated via BulletAmmoTracker child node.
class_name Gun
extends Node3D

signal fired
signal hit_confirmed
signal kill_confirmed
## Emitted when the active bullet type changes (slice-2 select-then-LMB).
signal active_bullet_changed(index: int)
## Emitted with world position + surface normal on any projectile hit — consumed by VfxRouter.
signal vfx_impact(pos: Vector3, normal: Vector3)
## Emitted with world position on a confirmed non-fatal enemy hit — consumed by VfxRouter.
signal vfx_hit_burst(pos: Vector3)
## Emitted with world position when a kill is confirmed — consumed by VfxRouter.
signal vfx_kill(pos: Vector3, normal: Vector3)
## Emitted at blast impact when cast uses a RadiusTargetResolver — consumed by VfxRouter.
signal vfx_blast(pos: Vector3)
## Emitted on any hit with the active cast index (0=electric,1=fire,2=ice,3=poison,4=kinetic).
## VfxRouter uses this to pick the per-element impact scene.
signal vfx_element_impact(pos: Vector3, normal: Vector3, cast_index: int)
signal out_of_ammo

const _VM_REST_POS := Vector3(0.12, -0.12, -0.25)
const _VM_REST_ROT := Vector3.ZERO
const _VM_DIP_POS := Vector3(0.12, -0.32, -0.20)
const _VM_DIP_ROT := Vector3(25.0, 0.0, 0.0)

@export var projectile_scene: PackedScene
## NodePath to the view-model Node3D holding the mesh, Muzzle and MuzzleFlash.
@export var view_model_path: NodePath = ^"PistolViewModel"
## Feel/firing tunables loaded from a WeaponData resource.
## When set, _ready() copies its values into the fields below, overriding scene defaults.
@export var weapon_data: WeaponData
@export var fire_rate: float = 0.2
## Cone half-angle (degrees) for hip-fire spread.
@export var spread_hip: float = 2.5
## Cone half-angle (degrees) for ADS spread.
@export var spread_ads: float = 0.3
## Spread multiplier when crouched (stacks with ADS; 1.0 = no effect).
@export var crouch_spread_mult: float = 0.5
## Pitch impulse (radians) added to player recoil per shot — read by player via export.
@export var recoil_pitch: float = 0.08
## Max yaw jitter (radians) per shot — read by player via export.
@export var recoil_yaw: float = 0.03
## Optional cast payload stamped onto each spawned projectile at fire time.
@export var cast_data: CastData
## Ordered list of bullet cast types (Q=0, E=1, R=2, T=3, Y=4).
@export var bullet_casts: Array[CastData] = []

var _aiming: bool = false
## Index of the currently active bullet in bullet_casts.
var _active_cast: int = 0
var _crouched: bool = false
var _swapping: bool = false
var _swap_tween: Tween
var _flash_tween: Tween

var _muzzle: Marker3D
var _muzzle_flash: OmniLight3D
var _view_model: Node3D
var _sprint_sway: SprintSway
var _firing: bool = false
var _last_hit_pos: Vector3 = Vector3.ZERO
var _last_hit_normal: Vector3 = Vector3.UP

@onready var _cooldown: Timer = $Cooldown
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx
@onready var _empty_sfx: AudioStreamPlayer = $EmptySfx
## Per-bullet-type ammo tracker — must be added as child named BulletAmmoTracker.
@onready var _tracker: BulletAmmoTracker = $BulletAmmoTracker


func _ready() -> void:
	# Apply feel tunables from WeaponData resource when provided.
	if weapon_data != null:
		fire_rate = weapon_data.fire_rate
		spread_hip = weapon_data.spread_hip
		spread_ads = weapon_data.spread_ads
		crouch_spread_mult = weapon_data.crouch_spread_mult
		recoil_pitch = weapon_data.recoil_pitch
		recoil_yaw = weapon_data.recoil_yaw
	_view_model = get_node(view_model_path) as Node3D
	if _view_model == null:
		push_error("Gun: view_model_path '%s' not found or not Node3D" % view_model_path)
		return
	for child: Node in get_children():
		if child is Node3D and child.name.ends_with("ViewModel") and child != _view_model:
			(child as Node3D).visible = false
	_sprint_sway = _view_model.get_node_or_null(^"SprintSway") as SprintSway
	var muzzle_root: Node3D = _sprint_sway if _sprint_sway != null else _view_model
	_muzzle = muzzle_root.get_node_or_null(^"Muzzle") as Marker3D
	if _muzzle == null:
		push_error("Gun: Muzzle not found under view-model '%s'" % view_model_path)
		return
	_muzzle_flash = _muzzle.get_node_or_null(^"MuzzleFlash") as OmniLight3D
	if _muzzle_flash == null:
		push_error("Gun: MuzzleFlash not found under Muzzle")
		return
	_muzzle_flash.shadow_enabled = false
	_cooldown.one_shot = true
	_cooldown.wait_time = fire_rate
	_cooldown.timeout.connect(_on_cooldown_done)
	# Init tracker pools from bullet_casts.
	if not bullet_casts.is_empty():
		_tracker.casts = bullet_casts
		_tracker.init_pools()
		# Emit initial ammo state for all slots.
		for i: int in range(bullet_casts.size()):
			_tracker.ammo_changed.emit(i, _tracker.get_ammo(i), _tracker.get_max(i))


## Called by the host on the shoot input. Returns true if a shot was fired.
func try_fire() -> bool:
	if _swapping:
		return false
	if not _cooldown.is_stopped():
		return false
	# Gate: check per-bullet-type ammo.
	if not bullet_casts.is_empty():
		if not _tracker.can_fire(_active_cast):
			out_of_ammo.emit()
			_empty_sfx.play()
			return false
	_fire()
	if not _fire_sfx.playing:
		_fire_sfx.play()
	_flash_pulse()
	_cooldown.start()
	fired.emit()
	# Consume ammo after confirmed fire.
	if not bullet_casts.is_empty():
		_tracker.consume(_active_cast)
	return true


## Called by the player on aim press/release to switch hip/ADS spread.
func set_aiming(aiming: bool) -> void:
	_aiming = aiming


## Called by the player each frame when crouch_amount crosses 0.5 threshold.
func set_crouched(crouched: bool) -> void:
	_crouched = crouched


## Lower the view-model out of sight (~0.12 s). Called by player before flip.
func play_holster() -> void:
	_swapping = true
	if _swap_tween:
		_swap_tween.kill()
	_swap_tween = create_tween().set_parallel(true)
	(
		_swap_tween
		. tween_property(_view_model, "position", _VM_DIP_POS, 0.12)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_swap_tween
		. tween_property(_view_model, "rotation_degrees", _VM_DIP_ROT, 0.12)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_SINE)
	)


## Raise the view-model to rest (~0.13 s). Emits swap_draw_finished when done.
func play_draw() -> void:
	_swapping = true
	if _swap_tween:
		_swap_tween.kill()
	_swap_tween = create_tween().set_parallel(true)
	(
		_swap_tween
		. tween_property(_view_model, "position", _VM_REST_POS, 0.13)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_swap_tween
		. tween_property(_view_model, "rotation_degrees", _VM_REST_ROT, 0.13)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)
	_swap_tween.chain().tween_callback(_on_draw_done)


func _on_draw_done() -> void:
	_swapping = false


## Relays sprint/walk state from player to SprintSway child each physics frame.
func update_sprint(
	is_sprinting: bool, is_moving: bool, velocity_factor: float, delta: float
) -> void:
	if _sprint_sway == null:
		return
	_sprint_sway.update_sprint(
		is_sprinting, is_moving, velocity_factor, _aiming, _firing, false, _swapping, delta
	)


## Selects the active bullet type by index into bullet_casts.
func set_active_bullet(index: int) -> void:
	if bullet_casts.is_empty() or index < 0 or index >= bullet_casts.size():
		return
	_active_cast = index
	cast_data = bullet_casts[index]
	active_bullet_changed.emit(index)


func _on_cooldown_done() -> void:
	_firing = false


func _fire() -> void:
	_firing = true
	if projectile_scene == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	scene_root.add_child(projectile)
	projectile.top_level = true
	var base_spread: float = spread_ads if _aiming else spread_hip
	var half_angle: float = deg_to_rad(base_spread * (crouch_spread_mult if _crouched else 1.0))
	var spread_basis: Basis = _muzzle.global_transform.basis
	if half_angle > 0.0:
		var rand_yaw: float = randf_range(-half_angle, half_angle)
		var rand_pitch: float = randf_range(-half_angle, half_angle)
		var yaw_axis: Vector3 = spread_basis.y.normalized()
		if yaw_axis.length_squared() > 0.0:
			spread_basis = spread_basis.rotated(yaw_axis, rand_yaw)
		var pitch_axis: Vector3 = spread_basis.x.normalized()
		if pitch_axis.length_squared() > 0.0:
			spread_basis = spread_basis.rotated(pitch_axis, rand_pitch)
	projectile.global_transform = Transform3D(spread_basis, _muzzle.global_position)
	projectile.cast_data = cast_data
	projectile.instigator_pos = _muzzle.global_position
	projectile.hit.connect(_on_projectile_hit)


func _flash_pulse() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_muzzle_flash.visible = true
	# Per-cast color + energy from CastData.muzzle_color / muzzle_energy (data-driven identity).
	# Null cast_data falls back to warm-white defaults.
	var flash_color: Color = Color(1.0, 0.7, 0.3)
	var flash_energy: float = 4.0
	if cast_data != null:
		flash_color = cast_data.muzzle_color
		flash_energy = cast_data.muzzle_energy
	_muzzle_flash.light_color = flash_color
	_muzzle_flash.light_energy = flash_energy
	_flash_tween = create_tween()
	_flash_tween.tween_property(_muzzle_flash, "light_energy", 0.0, 0.04)
	_flash_tween.tween_callback(_on_flash_done)


func _on_flash_done() -> void:
	_muzzle_flash.visible = false


func _on_projectile_hit(target: Node3D, normal: Vector3, hit_pos: Vector3) -> void:
	vfx_impact.emit(hit_pos, normal)
	vfx_element_impact.emit(hit_pos, normal, _active_cast)
	if cast_data != null and cast_data.resolver is RadiusTargetResolver:
		vfx_blast.emit(hit_pos)
	hit_confirmed.emit()
	if target.has_signal("died"):
		_last_hit_pos = hit_pos
		_last_hit_normal = normal
		vfx_hit_burst.emit(hit_pos)
		# SEAM: target proven to have `died` signal; guard against double-connect on multi-hit enemy.
		@warning_ignore("unsafe_method_access")
		if not target.is_connected("died", _on_target_died):
			target.connect("died", _on_target_died, CONNECT_ONE_SHOT)


func _on_target_died(_enemy: Node) -> void:
	kill_confirmed.emit()
	vfx_kill.emit(_last_hit_pos, _last_hit_normal)
