# entities/player/components/weapon_controller.gd — weapon firing, reload, swap,
# melee, ammo pickup, recoil spring.
class_name WeaponController
extends Node3D
## Owns weapon/combat input + recoil spring + HUD wiring. Signals: fired, hit, kill (relayed).

signal fired

@export var recoil_settle: float = 8.0
@export var recoil_snap: float = 18.0
@export var recoil_max: float = 0.25
@export var ads_tween_time: float = 0.15
@export var melee_kick_angle: float = 0.07
@export var kick_duration: float = 0.08
@export var hit_stop_duration: float = 0.06
@export var hit_stop_scale: float = 0.05

var _crosshair: Crosshair
var _ammo_hud: ArenaHud
var _active_weapon: Weapon
var _swapping: bool = false
var _aiming: bool = false
var _hit_stop_active: bool = false
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_yaw_prev: float = 0.0
var _recoil_target_pitch: float = 0.0
var _recoil_target_yaw: float = 0.0
var _ads_tween: Tween

@onready var _head: Node3D = $Head
@onready var _pistol: Weapon = $Head/Weapon
@onready var _rifle: Weapon = $Head/Rifle
@onready var _melee: Melee = $Head/Melee


func _ready() -> void:
	_active_weapon = _pistol
	_pistol.visible = true
	_rifle.visible = false
	_connect_weapon_signals(_pistol)
	_connect_weapon_signals(_rifle)
	_melee.hit_confirmed.connect(_on_hit_confirmed)
	_melee.kill_confirmed.connect(_on_kill_confirmed)
	_melee.hit_with_position.connect(_on_melee_hit)


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_crosshair = crosshair


## Called by main.gd after load to wire weapon ammo/reload signals to the HUD.
func set_ammo_hud(hud: ArenaHud) -> void:
	_ammo_hud = hud
	_wire_ammo_hud(_active_weapon)


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


## Returns aiming state (used by player for FOV/movement).
func is_aiming() -> bool:
	return _aiming


## Called by player every physics frame to update recoil spring.
func update_recoil(delta: float) -> void:
	_recoil_target_pitch = lerpf(_recoil_target_pitch, 0.0, recoil_settle * delta)
	_recoil_target_yaw = lerpf(_recoil_target_yaw, 0.0, recoil_settle * delta)
	_recoil_pitch = lerpf(_recoil_pitch, _recoil_target_pitch, recoil_snap * delta)
	_recoil_yaw = lerpf(_recoil_yaw, _recoil_target_yaw, recoil_snap * delta)


## Processes weapon input each physics frame.
func process_input(is_aiming_pressed: bool, ads_released: bool) -> void:
	# ADS
	if is_aiming_pressed:
		_set_aiming(true)
	elif ads_released:
		_set_aiming(false)

	# Fire on left-click (held); cooldown timer caps cadence, not input.
	if Input.is_action_pressed("shoot"):
		_active_weapon.try_fire()

	# Manual reload (R); weapon guards against full mag / already reloading.
	if Input.is_action_just_pressed("reload"):
		_active_weapon.start_reload()

	# Swap weapon (Q) — debounced: ignore while swap in flight.
	if Input.is_action_just_pressed("equip_weapon") and not _swapping:
		_swap_weapon()

	# Melee swing (V) — always available, independent of active gun.
	if Input.is_action_just_pressed("melee"):
		_melee.try_melee()


## Notifies weapon of crouch state each frame.
func set_active_weapon_crouch(crouched: bool) -> void:
	if _active_weapon != null:
		_active_weapon.set_crouched(crouched)


## Relays sprint state to active weapon's SprintSway component each physics frame.
func update_sprint(is_sprinting: bool, velocity_factor: float, delta: float) -> void:
	if _active_weapon != null:
		_active_weapon.update_sprint(is_sprinting, velocity_factor, delta)


## Collects a pickup by kind. AMMO → refills all weapons matching ammo_caliber; HEALTH → add life.
## Returns true if something changed (pickup consumed), false if no-op (already full).
func collect_pickup(kind: Pickup.Kind, ammo_caliber: StringName = &"light") -> bool:
	match kind:
		Pickup.Kind.AMMO:
			var took: bool = false
			for w: Weapon in [_pistol, _rifle]:
				if w.caliber == ammo_caliber:
					took = w.refill_ammo() or took
			return took
		Pickup.Kind.HEALTH:
			# SEAM: WaveManager is a sibling in the loaded level — found by name, duck-typed.
			var parent: Node = get_parent()
			if parent == null:
				return false
			var wm: Node = parent.find_child("WaveManager", false, false)
			if wm == null:
				return false
			if not wm.has_method("add_life"):
				return false
			@warning_ignore("unsafe_method_access")
			return wm.add_life()
	return false


func _set_aiming(aiming: bool) -> void:
	_aiming = aiming
	_active_weapon.set_aiming(aiming)


func _swap_weapon() -> void:
	# Cancel ADS before swapping.
	if _aiming:
		_aiming = false
		if _ads_tween:
			_ads_tween.kill()
	_swapping = true
	var outgoing: Weapon = _active_weapon
	var incoming: Weapon = _rifle if _active_weapon == _pistol else _pistol
	outgoing.play_holster()
	# Wait for the holster (0.12 s) then flip visibility and start the draw.
	get_tree().create_timer(0.12).timeout.connect(
		func() -> void:
			outgoing.visible = false
			incoming.visible = true
			_active_weapon = incoming
			if _ammo_hud != null:
				_wire_ammo_hud(_active_weapon)
			incoming.play_draw()
			incoming.swap_draw_finished.connect(_on_swap_draw_finished, CONNECT_ONE_SHOT),
		CONNECT_ONE_SHOT
	)


func _on_swap_draw_finished() -> void:
	_swapping = false


## Wire ammo/reload signals from weapon to HUD. Disconnects previous weapon first.
func _wire_ammo_hud(weapon: Weapon) -> void:
	# Disconnect old weapon signals if connected to avoid duplicate HUD updates.
	for w: Weapon in [_pistol, _rifle]:
		if w.ammo_changed.is_connected(_ammo_hud.set_ammo):
			w.ammo_changed.disconnect(_ammo_hud.set_ammo)
		if w.reload_started.is_connected(_on_reload_started_hud):
			w.reload_started.disconnect(_on_reload_started_hud)
		if w.reload_finished.is_connected(_on_reload_finished_hud):
			w.reload_finished.disconnect(_on_reload_finished_hud)
	weapon.ammo_changed.connect(_ammo_hud.set_ammo)
	weapon.reload_started.connect(_on_reload_started_hud)
	weapon.reload_finished.connect(_on_reload_finished_hud)
	weapon.emit_ammo()


func _on_reload_started_hud(_duration: float) -> void:
	if _ammo_hud != null:
		_ammo_hud.set_reloading(true)


func _on_reload_finished_hud() -> void:
	if _ammo_hud != null:
		_ammo_hud.set_reloading(false)


func _connect_weapon_signals(weapon: Weapon) -> void:
	weapon.fired.connect(_on_weapon_fired)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.kill_confirmed.connect(_on_kill_confirmed)


func _on_weapon_fired() -> void:
	# Impulse goes to spring TARGET (not applied value) — stage 2 lerp does the chasing.
	_recoil_target_pitch = minf(_recoil_target_pitch + _active_weapon.recoil_pitch, recoil_max)
	_recoil_target_yaw = clampf(
		_recoil_target_yaw + randf_range(-_active_weapon.recoil_yaw, _active_weapon.recoil_yaw),
		-recoil_max,
		recoil_max
	)
	if _crosshair != null:
		_crosshair.fire_pop()
	fired.emit()


func _on_hit_confirmed() -> void:
	if _crosshair != null:
		_crosshair.hit_pop()


func _on_kill_confirmed() -> void:
	if _crosshair != null:
		_crosshair.kill_pop()


## Fires on every melee body connect. Owns hit-stop, melee camera kick, knockback relay.
func _on_melee_hit(hitter_pos: Vector3) -> void:
	_do_hit_stop()
	_do_melee_camera_kick()
	# Relay knockback to every overlapping body that supports it (duck-typed, godot-composition).
	for body: Node3D in _melee._hitbox.get_overlapping_bodies():
		if body.has_method("apply_knockback"):
			# SEAM: duck-typed knockback — any body with apply_knockback(Vector3) is valid.
			@warning_ignore("unsafe_method_access")
			body.apply_knockback(hitter_pos)


## Brief time_scale dip on melee connect. Re-entrant-safe: guard prevents overlapping dips.
func _do_hit_stop() -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = hit_stop_scale
	# ignore_time_scale = true → timer runs in real time regardless of Engine.time_scale.
	get_tree().create_timer(hit_stop_duration, true, false, true).timeout.connect(
		func() -> void:
			Engine.time_scale = 1.0
			_hit_stop_active = false
	)


func _do_melee_camera_kick() -> void:
	var base_x: float = _head.rotation.x
	var tw := create_tween()
	# Sharper downward punch (positive X = look down) for melee impact feel.
	tw.tween_property(_head, "rotation:x", base_x + melee_kick_angle, kick_duration * 0.2)
	tw.tween_property(_head, "rotation:x", base_x, kick_duration * 1.2)
