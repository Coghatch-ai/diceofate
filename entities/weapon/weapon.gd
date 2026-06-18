# entities/weapon/weapon.gd — firing component: spawns projectiles from a Muzzle, timer-gated.
class_name Weapon
extends Node3D

signal fired
signal hit_confirmed
signal kill_confirmed
signal ammo_changed(current: int, maximum: int)
signal out_of_ammo
signal reload_started(duration: float)
signal reload_finished
signal swap_draw_finished

const _VM_REST_POS := Vector3(0.12, -0.12, -0.25)
const _VM_REST_ROT := Vector3.ZERO
const _VM_DIP_POS := Vector3(0.12, -0.32, -0.20)
const _VM_DIP_ROT := Vector3(25.0, 0.0, 0.0)

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.2
@export var ammo_max: int = 12
@export var reload_time: float = 1.2
## Cone half-angle (degrees) for hip-fire spread.
@export var spread_hip: float = 2.5
## Cone half-angle (degrees) for ADS spread.
@export var spread_ads: float = 0.3
## Pitch impulse (radians) added to player recoil per shot — read by player via export.
@export var recoil_pitch: float = 0.012
## Max yaw jitter (radians) per shot — read by player via export.
@export var recoil_yaw: float = 0.004

var _aiming: bool = false
var _ammo: int = 0
var _reloading: bool = false
var _swapping: bool = false
var _reload_tween: Tween
var _swap_tween: Tween
var _flash_tween: Tween

@onready var _muzzle: Marker3D = $PistolViewModel/Muzzle
@onready var _muzzle_flash: OmniLight3D = $PistolViewModel/Muzzle/MuzzleFlash
@onready var _cooldown: Timer = $Cooldown
@onready var _reload_timer: Timer = $Reload
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx
@onready var _empty_sfx: AudioStreamPlayer = $EmptySfx
@onready var _reload_sfx: AudioStreamPlayer = $ReloadSfx
@onready var _view_model: Node3D = $PistolViewModel


func _ready() -> void:
	_cooldown.one_shot = true
	_cooldown.wait_time = fire_rate
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	_reload_timer.timeout.connect(_on_reload_done)
	_ammo = ammo_max
	ammo_changed.emit(_ammo, ammo_max)


## Called by the host on the shoot input. Returns true if a shot was fired.
func try_fire() -> bool:
	if _reloading or _swapping:
		return false
	if _ammo <= 0:
		out_of_ammo.emit()
		_empty_sfx.play()
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
	ammo_changed.emit(_ammo, ammo_max)
	return true


## Refills magazine to full. Returns false (no-op) if already full.
## Instant — no reload timer or dip animation. Active-weapon-only seam for pickups.
func refill_ammo() -> bool:
	if _ammo >= ammo_max:
		return false
	_ammo = ammo_max
	ammo_changed.emit(_ammo, ammo_max)
	return true


## Re-emits ammo_changed so late-connecting HUDs can seed their display.
func emit_ammo() -> void:
	ammo_changed.emit(_ammo, ammo_max)


## Called by the player on aim press/release to switch hip/ADS spread.
func set_aiming(aiming: bool) -> void:
	_aiming = aiming


## Starts a reload. No-ops if already reloading or magazine is full.
func start_reload() -> void:
	if _reloading or _ammo >= ammo_max:
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
	_ammo = ammo_max
	_reloading = false
	reload_finished.emit()
	ammo_changed.emit(_ammo, ammo_max)
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


func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	# Spawn into world space so the projectile travels independently of the firer.
	get_tree().current_scene.add_child(projectile)
	projectile.top_level = true
	# Apply spread: perturb the muzzle basis by a random cone before launch.
	var half_angle: float = deg_to_rad(spread_ads if _aiming else spread_hip)
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
	hit_confirmed.emit()
	# If the target exposes a `died` signal, subscribe one-shot to detect a kill this frame.
	# SEAM: duck-typed kill detection — only enemies with `died` trigger kill_confirmed;
	# world geometry and other bodies are silently ignored (godot-composition rule).
	if target.has_signal("died"):
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
