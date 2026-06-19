# entities/weapon/weapon.gd — firing component: spawns projectiles from a Muzzle, timer-gated.
class_name Weapon
extends Node3D

signal fired
signal hit_confirmed
signal kill_confirmed
## Emitted with world position when a projectile hits any body — consumed by VfxRouter.
signal vfx_impact(pos: Vector3)
## Emitted with world position on a confirmed non-fatal enemy hit — consumed by VfxRouter.
signal vfx_hit_burst(pos: Vector3)
## Emitted with world position when a kill is confirmed — consumed by VfxRouter.
signal vfx_kill(pos: Vector3)
signal ammo_changed(current: int, reserve: int)
signal out_of_ammo
signal reload_started(duration: float)
signal reload_finished
signal swap_draw_finished

const _VM_REST_POS := Vector3(0.12, -0.12, -0.25)
const _VM_REST_ROT := Vector3.ZERO
const _VM_DIP_POS := Vector3(0.12, -0.32, -0.20)
const _VM_DIP_ROT := Vector3(25.0, 0.0, 0.0)

@export var projectile_scene: PackedScene
## NodePath to the view-model Node3D holding the mesh, Muzzle and MuzzleFlash.
## Override in derived weapon scenes to swap in a different view-model mesh.
@export var view_model_path: NodePath = ^"PistolViewModel"
@export var fire_rate: float = 0.2
@export var ammo_max: int = 12
@export var reload_time: float = 1.2
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
## Maximum rounds in the reserve pool (pistol default 48 = 4 spare mags).
@export var reserve_max: int = 48
## Ammo type this weapon consumes. Matched against Pickup.ammo_caliber on collect.
@export var caliber: StringName = &"light"

var _aiming: bool = false
var _crouched: bool = false
var _ammo: int = 0
var _reserve: int = 0
var _reloading: bool = false
var _swapping: bool = false
var _reload_tween: Tween
var _swap_tween: Tween
var _flash_tween: Tween

var _muzzle: Marker3D
var _muzzle_flash: OmniLight3D
var _view_model: Node3D
var _sprint_sway: SprintSway
var _firing: bool = false
# Cached world position of last hit target — used by _on_target_died to emit vfx_kill.
var _last_hit_pos: Vector3 = Vector3.ZERO

@onready var _cooldown: Timer = $Cooldown
@onready var _reload_timer: Timer = $Reload
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx
@onready var _empty_sfx: AudioStreamPlayer = $EmptySfx
@onready var _reload_sfx: AudioStreamPlayer = $ReloadSfx


func _ready() -> void:
	# Resolve view-model via export so derived scenes can override with a different mesh node.
	_view_model = get_node(view_model_path) as Node3D
	if _view_model == null:
		push_error("Weapon: view_model_path '%s' not found or not Node3D" % view_model_path)
		return
	# Hide every sibling *ViewModel node that is NOT the active one.
	# Inherited scenes (e.g. rifle.tscn) carry the base PistolViewModel; hiding it
	# here is authoritative regardless of scene-property-override quirks.
	for child: Node in get_children():
		if child is Node3D and child.name.ends_with("ViewModel") and child != _view_model:
			(child as Node3D).visible = false
	# SprintSway sits between view-model and mesh/muzzle children.
	_sprint_sway = _view_model.get_node_or_null(^"SprintSway") as SprintSway
	# Muzzle/MuzzleFlash live under SprintSway when present, else directly under view-model.
	var muzzle_root: Node3D = _sprint_sway if _sprint_sway != null else _view_model
	_muzzle = muzzle_root.get_node_or_null(^"Muzzle") as Marker3D
	if _muzzle == null:
		push_error("Weapon: Muzzle not found under view-model '%s'" % view_model_path)
		return
	_muzzle_flash = _muzzle.get_node_or_null(^"MuzzleFlash") as OmniLight3D
	if _muzzle_flash == null:
		push_error("Weapon: MuzzleFlash not found under Muzzle")
		return
	# Flash must never cast shadows — perf + correctness (skill: godot-oneshot-vfx).
	_muzzle_flash.shadow_enabled = false
	_cooldown.one_shot = true
	_cooldown.wait_time = fire_rate
	_cooldown.timeout.connect(_on_cooldown_done)
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	_reload_timer.timeout.connect(_on_reload_done)
	_ammo = ammo_max
	_reserve = reserve_max
	ammo_changed.emit(_ammo, _reserve)


## Called by the host on the shoot input. Returns true if a shot was fired.
func try_fire() -> bool:
	if _reloading or _swapping:
		return false
	if _ammo <= 0:
		out_of_ammo.emit()
		_empty_sfx.play()
		if _reserve > 0:
			start_reload()
		return false
	if not _cooldown.is_stopped():
		return false
	_fire()
	_fire_sfx.play()
	_flash_pulse()
	_cooldown.start()
	fired.emit()
	_ammo -= 1
	ammo_changed.emit(_ammo, _reserve)
	return true


## Adds one magazine worth of rounds to the reserve (capped at reserve_max).
## Returns false (no-op) if reserve already full.
## Active-weapon-only seam for AMMO pickups — signature unchanged.
func refill_ammo() -> bool:
	if _reserve >= reserve_max:
		return false
	_reserve = mini(_reserve + ammo_max, reserve_max)
	ammo_changed.emit(_ammo, _reserve)
	return true


## Re-emits ammo_changed so late-connecting HUDs can seed their display.
func emit_ammo() -> void:
	ammo_changed.emit(_ammo, _reserve)


## Called by the player on aim press/release to switch hip/ADS spread.
func set_aiming(aiming: bool) -> void:
	_aiming = aiming


## Called by the player each frame when crouch_amount crosses 0.5 threshold.
## Crouched spread stacks multiplicatively with ADS (crouch+ADS = tightest cone).
func set_crouched(crouched: bool) -> void:
	_crouched = crouched


## Starts a reload. No-ops if already reloading, magazine is full, or reserve empty.
func start_reload() -> void:
	if _reloading or _ammo >= ammo_max or _reserve <= 0:
		return
	_reloading = true
	_reload_timer.start()
	reload_started.emit(reload_time)
	_reload_sfx.play()
	_play_reload_dip()


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
	swap_draw_finished.emit()


func _on_reload_done() -> void:
	var need: int = ammo_max - _ammo
	var pulled: int = mini(need, _reserve)
	_ammo += pulled
	_reserve -= pulled
	_reloading = false
	reload_finished.emit()
	ammo_changed.emit(_ammo, _reserve)
	_restore_view_model()


func _play_reload_dip() -> void:
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween().set_parallel(true)
	var half: float = reload_time * 0.5
	(
		_reload_tween
		. tween_property(_view_model, "position", _VM_DIP_POS, half)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_reload_tween
		. tween_property(_view_model, "rotation_degrees", _VM_DIP_ROT, half)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_SINE)
	)


func _restore_view_model() -> void:
	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween().set_parallel(true)
	var half: float = reload_time * 0.5
	(
		_reload_tween
		. tween_property(_view_model, "position", _VM_REST_POS, half)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_reload_tween
		. tween_property(_view_model, "rotation_degrees", _VM_REST_ROT, half)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)


func _flash_pulse() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_muzzle_flash.visible = true
	_muzzle_flash.light_energy = 4.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_muzzle_flash, "light_energy", 0.0, 0.04)
	_flash_tween.tween_callback(_on_flash_done)


func _on_flash_done() -> void:
	_muzzle_flash.visible = false


## Relays sprint state from player to SprintSway child each physics frame.
func update_sprint(is_sprinting: bool, velocity_factor: float, delta: float) -> void:
	if _sprint_sway == null:
		return
	_sprint_sway.update_sprint(
		is_sprinting, velocity_factor, _aiming, _firing, _reloading, _swapping, delta
	)


func _on_cooldown_done() -> void:
	_firing = false


func _fire() -> void:
	_firing = true
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	# Spawn into world space so the projectile travels independently of the firer.
	get_tree().current_scene.add_child(projectile)
	projectile.top_level = true
	# Apply spread: perturb the muzzle basis by a random cone before launch.
	# Crouch multiplier stacks with ADS: crouch+ADS = tightest cone.
	var base_spread: float = spread_ads if _aiming else spread_hip
	var half_angle: float = deg_to_rad(base_spread * (crouch_spread_mult if _crouched else 1.0))
	var spread_basis: Basis = _muzzle.global_transform.basis
	if half_angle > 0.0:
		var rand_yaw: float = randf_range(-half_angle, half_angle)
		var rand_pitch: float = randf_range(-half_angle, half_angle)
		spread_basis = spread_basis.rotated(spread_basis.y, rand_yaw)
		spread_basis = spread_basis.rotated(spread_basis.x, rand_pitch)
	projectile.global_transform = Transform3D(spread_basis, _muzzle.global_position)
	# SEAM: forward hit_confirmed up to weapon so hosts can react without coupling to Projectile.
	projectile.hit.connect(_on_projectile_hit)


func _on_projectile_hit(target: Node3D) -> void:
	var hit_pos: Vector3 = target.global_position
	vfx_impact.emit(hit_pos)
	hit_confirmed.emit()
	# If the target exposes a `died` signal, subscribe one-shot to detect a kill this frame.
	# SEAM: duck-typed kill detection — only enemies with `died` trigger kill_confirmed;
	# world geometry and other bodies are silently ignored (godot-composition rule).
	if target.has_signal("died"):
		# Cache position so _on_target_died can emit vfx_kill with the enemy's world pos.
		_last_hit_pos = hit_pos
		# Emit hit burst for all enemy-body hits (fatal and non-fatal).
		# On a killing blow, both vfx_hit_burst and vfx_kill fire — hit_burst is smaller
		# and fires first, adding to the juice rather than conflicting.
		vfx_hit_burst.emit(hit_pos)
		# SEAM: target proven to have `died` signal by has_signal check; Node3D base has connect().
		# Guard: multi-hit enemies (health>1) survive several bullets; each bullet's projectile.hit
		# triggers this. CONNECT_ONE_SHOT auto-disconnects after the signal fires (on death), but
		# while the enemy is still alive the connection persists — a second bullet would double-connect.
		# SEAM: target.is_connected() uses Callable; duck-typed via has_signal guard above.
		@warning_ignore("unsafe_method_access")
		if not target.is_connected("died", _on_target_died):
			target.connect("died", _on_target_died, CONNECT_ONE_SHOT)


func _on_target_died(_enemy: Node) -> void:
	kill_confirmed.emit()
	vfx_kill.emit(_last_hit_pos)
