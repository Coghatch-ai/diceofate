# entities/player/components/weapon_controller.gd — weapon firing, swap,
# recoil spring, per-bullet-type ammo HUD wiring.
# Single weapon: Rifle (Gun). LMB fires via try_fire(). RMB aims.
class_name WeaponController
extends Node3D
## Owns weapon/combat input + recoil spring + HUD wiring. Signals: fired, hit, kill (relayed).

signal fired
signal health_pickup_requested

@export var recoil_settle: float = 8.0
@export var recoil_snap: float = 18.0
@export var recoil_max: float = 0.18
@export var ads_tween_time: float = 0.15
@export var kick_duration: float = 0.08
@export var hit_stop_duration: float = 0.06
@export var hit_stop_scale: float = 0.05

## Seconds of no firing before the consecutive-shot index resets to 0.
@export_range(0.1, 3.0, 0.05) var shots_reset_after: float = 0.6

var _crosshair: Crosshair
var _ammo_hud: ArenaHud
var _aiming: bool = false
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_yaw_prev: float = 0.0
var _recoil_target_pitch: float = 0.0
var _recoil_target_yaw: float = 0.0
## Consecutive shots fired without a gap; reset after shots_reset_after idle seconds.
var _shot_index: int = 0
## Accumulator tracking idle time since last shot; compared against shots_reset_after.
var _idle_accum: float = 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _rifle: Gun = $Head/Rifle


func _ready() -> void:
	_rifle.visible = true
	_connect_gun_signals(_rifle)


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_crosshair = crosshair


## Called by main.gd after load to wire bullet-ammo tracker signals to the HUD hotbar.
func set_ammo_hud(hud: ArenaHud) -> void:
	_ammo_hud = hud
	_wire_ammo_hud(_rifle)


## Exposes recoil state to player for head rotation application.
func get_recoil_pitch() -> float:
	return _recoil_pitch


## Exposes recoil state to player for body rotation application.
func get_recoil_yaw() -> float:
	return _recoil_yaw


## Exposes recoil state delta for frame-to-frame yaw delta.
func get_recoil_yaw_prev() -> float:
	return _recoil_yaw_prev


## Sets recoil yaw prev for next frame delta.
func set_recoil_yaw_prev(value: float) -> void:
	_recoil_yaw_prev = value


## Exposes Head node (contains Camera3D and rifle).
func get_head() -> Node3D:
	return _head


## Exposes Camera3D for FOV control.
func get_camera() -> Camera3D:
	return _camera


## Returns aiming state (used by player for FOV/movement).
func is_aiming() -> bool:
	return _aiming


## Called by player every physics frame to update recoil spring.
## Also ticks the idle-reset counter so _shot_index returns to 0 after a firing gap.
func update_recoil(delta: float) -> void:
	_recoil_target_pitch = lerpf(_recoil_target_pitch, 0.0, recoil_settle * delta)
	_recoil_target_yaw = lerpf(_recoil_target_yaw, 0.0, recoil_settle * delta)
	_recoil_pitch = lerpf(_recoil_pitch, _recoil_target_pitch, recoil_snap * delta)
	_recoil_yaw = lerpf(_recoil_yaw, _recoil_target_yaw, recoil_snap * delta)
	# Idle-reset: count up while not firing; clamp to avoid float overflow.
	_idle_accum = minf(_idle_accum + delta, shots_reset_after + 0.1)
	if _idle_accum >= shots_reset_after:
		_shot_index = 0


## Processes weapon input each physics frame.
func process_input(is_aiming_pressed: bool, ads_released: bool) -> void:
	# ADS.
	if is_aiming_pressed:
		_set_aiming(true)
	elif ads_released:
		_set_aiming(false)

	# Q/E/R/T/Y: select active bullet type (select-then-LMB model).
	if Input.is_action_just_pressed("bullet_1"):
		_rifle.set_active_bullet(0)
	elif Input.is_action_just_pressed("bullet_2"):
		_rifle.set_active_bullet(1)
	elif Input.is_action_just_pressed("bullet_3"):
		_rifle.set_active_bullet(2)
	elif Input.is_action_just_pressed("bullet_4"):
		_rifle.set_active_bullet(3)
	elif Input.is_action_just_pressed("bullet_5"):
		_rifle.set_active_bullet(4)

	# LMB: fire rifle with active bullet.
	if Input.is_action_pressed("shoot"):
		_rifle.try_fire()


## Notifies active gun of crouch state each frame.
func set_active_weapon_crouch(crouched: bool) -> void:
	_rifle.set_crouched(crouched)


## Relays sprint/walk state to rifle's SprintSway component each physics frame.
func update_sprint(
	is_sprinting: bool, is_moving: bool, velocity_factor: float, delta: float
) -> void:
	_rifle.update_sprint(is_sprinting, is_moving, velocity_factor, delta)


## Collects a pickup by kind. HEALTH -> signal up to player.
## AMMO branch is a no-op (ammo is now per-type regen; pickups not yet implemented).
func collect_pickup(kind: Pickup.Kind, _ammo_caliber: StringName = &"light") -> bool:
	match kind:
		Pickup.Kind.HEALTH:
			# SEAM: signal upward to player; player handles heal directly (godot-composition rule).
			health_pickup_requested.emit()
			return true
	return false


func _set_aiming(aiming: bool) -> void:
	_aiming = aiming
	_rifle.set_aiming(aiming)
	if _crosshair != null:
		_crosshair.set_aiming_state(aiming)


## Wire tracker ammo_changed + gun active_bullet_changed to HUD hotbar.
func _wire_ammo_hud(gun: Gun) -> void:
	if _ammo_hud == null:
		return
	var tracker: BulletAmmoTracker = gun.get_node_or_null(^"BulletAmmoTracker") as BulletAmmoTracker
	if tracker != null:
		if not tracker.ammo_changed.is_connected(_ammo_hud.set_bullet_ammo):
			tracker.ammo_changed.connect(_ammo_hud.set_bullet_ammo)
	if not gun.active_bullet_changed.is_connected(_ammo_hud.set_active_bullet):
		gun.active_bullet_changed.connect(_ammo_hud.set_active_bullet)
	# Seed HUD with initial values for all slots.
	if tracker != null:
		for i: int in range(gun.bullet_casts.size()):
			_ammo_hud.set_bullet_ammo(i, tracker.get_ammo(i), tracker.get_max(i))
	_ammo_hud.set_active_bullet(0)


func _connect_gun_signals(gun: Gun) -> void:
	gun.fired.connect(_on_gun_fired.bind(gun))
	gun.hit_confirmed.connect(_on_hit_confirmed)
	gun.kill_confirmed.connect(_on_kill_confirmed)


func _on_gun_fired(gun: Gun) -> void:
	if _rifle != gun:
		return
	# Curve-driven path: active CastData has a RecoilProfile → sample by shot index.
	# Additive-on-head guarantee (I2): impulse feeds ONLY _recoil_target_* accumulators.
	# player.gd sums recoil onto _look_pitch / rotation.y. Never written here.
	var cast: CastData = gun.cast_data
	var profile: RecoilProfile = cast.recoil_profile if cast != null else null
	if profile != null:
		var pitch_impulse: float = profile.sample_pitch(_shot_index)
		var yaw_impulse: float = profile.sample_yaw(_shot_index)
		_recoil_target_pitch = minf(_recoil_target_pitch + pitch_impulse, recoil_max)
		_recoil_target_yaw = clampf(_recoil_target_yaw + yaw_impulse, -recoil_max, recoil_max)
	else:
		# Null profile: fall back to Gun scalar recoil_pitch/yaw (original behaviour).
		_recoil_target_pitch = minf(_recoil_target_pitch + gun.recoil_pitch, recoil_max)
		_recoil_target_yaw = clampf(
			_recoil_target_yaw + randf_range(-gun.recoil_yaw, gun.recoil_yaw),
			-recoil_max,
			recoil_max
		)
	# Advance shot index; idle-reset in update_recoil resets it after shots_reset_after.
	_shot_index += 1
	_idle_accum = 0.0
	if _crosshair != null:
		_crosshair.fire_pop()
	fired.emit()


func _on_hit_confirmed() -> void:
	if _crosshair != null:
		_crosshair.hit_pop()


func _on_kill_confirmed() -> void:
	if _crosshair != null:
		_crosshair.kill_pop()
