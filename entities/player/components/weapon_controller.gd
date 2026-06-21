# entities/player/components/weapon_controller.gd — weapon firing, reload, swap,
# hammer melee, ammo pickup, recoil spring.
class_name WeaponController
extends Node3D
## Owns weapon/combat input + recoil spring + HUD wiring. Signals: fired, hit, kill (relayed).
## Slot 0=Pistol (Gun), 1=Rifle (Gun), 2=Hammer.
## LMB fires active slot: guns call try_fire(), hammer calls try_melee().
## RMB aims guns only; no-op when hammer slot active.
## Q cycles all 3 slots; hammer view-model stays visible at rest like guns.

signal fired
signal health_pickup_requested

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
# Active weapon slot node — Gun (slots 0/1) or Hammer (slot 2). Duck-typed as Node3D.
var _active_slot: Node3D
var _slot_index: int = 0
var _swapping: bool = false
var _aiming: bool = false
var _hit_stop_active: bool = false
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_yaw_prev: float = 0.0
var _recoil_target_pitch: float = 0.0
var _recoil_target_yaw: float = 0.0
# Additive melee-kick offset on Head.rotation.x — tweened 0→kick→0, read by player
# and summed with recoil+look in one write. Never written directly to _head.rotation.x.
var _melee_kick_offset: float = 0.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _pistol: Gun = $Head/Pistol
@onready var _rifle: Gun = $Head/Rifle
@onready var _hammer: Hammer = $Head/Hammer


func _ready() -> void:
	_slot_index = 0
	_active_slot = _pistol
	# Slot 0 starts visible; rifle and hammer hidden.
	_pistol.visible = true
	_rifle.visible = false
	_hammer.visible = false
	_connect_gun_signals(_pistol)
	_connect_gun_signals(_rifle)
	_hammer.hit_confirmed.connect(_on_hit_confirmed)
	_hammer.kill_confirmed.connect(_on_kill_confirmed)
	_hammer.hit_with_position.connect(_on_melee_hit)


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_crosshair = crosshair


## Called by main.gd after load to wire weapon ammo/reload signals to the HUD.
func set_ammo_hud(hud: ArenaHud) -> void:
	_ammo_hud = hud
	_wire_ammo_hud(_active_slot)


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


## Additive melee-kick pitch offset — summed into head rotation by player (single write owner).
func get_melee_kick_offset() -> float:
	return _melee_kick_offset


## Exposes Head node (contains Camera3D and weapons).
func get_head() -> Node3D:
	return _head


## Exposes Camera3D for FOV control.
func get_camera() -> Camera3D:
	return _camera


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
	# ADS — guns only; no-op when hammer slot active.
	if _slot_index != 2:
		if is_aiming_pressed:
			_set_aiming(true)
		elif ads_released:
			_set_aiming(false)

	# LMB: route to active slot.
	# Gun slots (0/1): call try_fire(). Hammer slot (2): call try_melee().
	if Input.is_action_pressed("shoot"):
		if _slot_index == 2:
			_hammer.try_melee()
		else:
			var gun := _active_slot as Gun
			if gun != null:
				gun.try_fire()

	# Manual reload (R) — guns only.
	if Input.is_action_just_pressed("reload") and _slot_index != 2:
		var gun := _active_slot as Gun
		if gun != null:
			gun.start_reload()

	# Swap weapon (Q) — debounced: ignore while swap in flight.
	if Input.is_action_just_pressed("equip_weapon") and not _swapping:
		_swap_weapon()


## Notifies active gun of crouch state each frame. No-op for hammer slot.
func set_active_weapon_crouch(crouched: bool) -> void:
	var gun := _active_slot as Gun
	if gun != null:
		gun.set_crouched(crouched)


## Relays sprint/walk state to active gun's SprintSway component each physics frame.
func update_sprint(
	is_sprinting: bool, is_moving: bool, velocity_factor: float, delta: float
) -> void:
	var gun := _active_slot as Gun
	if gun != null:
		gun.update_sprint(is_sprinting, is_moving, velocity_factor, delta)


## Collects a pickup by kind. AMMO → refills all guns matching ammo_caliber; HEALTH → add life.
## Returns true if something changed (pickup consumed), false if no-op (already full).
func collect_pickup(kind: Pickup.Kind, ammo_caliber: StringName = &"light") -> bool:
	match kind:
		Pickup.Kind.AMMO:
			var took: bool = false
			for w: Gun in [_pistol, _rifle]:
				if w.caliber == ammo_caliber:
					took = w.refill_ammo() or took
			return took
		Pickup.Kind.HEALTH:
			# SEAM: signal upward to player; player routes to WaveManager (godot-composition rule).
			health_pickup_requested.emit()
			return true
	return false


func _set_aiming(aiming: bool) -> void:
	_aiming = aiming
	var gun := _active_slot as Gun
	if gun != null:
		gun.set_aiming(aiming)
	if _crosshair != null:
		_crosshair.set_aiming_state(aiming)


func _swap_weapon() -> void:
	# Cancel ADS before swapping.
	if _aiming:
		_set_aiming(false)
	_swapping = true
	# 3-slot cycle: 0=pistol, 1=rifle, 2=hammer.
	var next_index: int = (_slot_index + 1) % 3
	var outgoing_gun: Gun = _active_slot as Gun
	# Determine incoming slot node.
	var incoming_slot: Node3D
	if next_index == 0:
		incoming_slot = _pistol
	elif next_index == 1:
		incoming_slot = _rifle
	else:
		incoming_slot = _hammer
	# Holster outgoing gun (skip holster anim for hammer slot outgoing — no gun to dip).
	if outgoing_gun != null:
		outgoing_gun.play_holster()
	var holster_wait: float = 0.12 if outgoing_gun != null else 0.0
	get_tree().create_timer(holster_wait).timeout.connect(
		func() -> void:
			# Hide all slots; show only the incoming one.
			_pistol.visible = false
			_rifle.visible = false
			_hammer.visible = false
			_slot_index = next_index
			_active_slot = incoming_slot
			incoming_slot.visible = true
			var incoming_gun: Gun = incoming_slot as Gun
			if incoming_gun != null:
				_wire_ammo_hud(incoming_slot)
				incoming_gun.play_draw()
				incoming_gun.swap_draw_finished.connect(_on_swap_draw_finished, CONNECT_ONE_SHOT)
			else:
				# Hammer slot: HammerViewModel already visible at rest (hammer.gd _ready).
				# No draw animation; swap completes immediately.
				_on_swap_draw_finished(),
		CONNECT_ONE_SHOT
	)


func _on_swap_draw_finished() -> void:
	_swapping = false


## Wire ammo/reload signals from active gun to HUD. No-op for hammer slot (no ammo).
func _wire_ammo_hud(slot: Node3D) -> void:
	var gun := slot as Gun
	if gun == null:
		return
	if _ammo_hud == null:
		return
	# Disconnect old gun signals to avoid duplicate HUD updates.
	for w: Gun in [_pistol, _rifle]:
		if w.ammo_changed.is_connected(_ammo_hud.set_ammo):
			w.ammo_changed.disconnect(_ammo_hud.set_ammo)
		if w.reload_started.is_connected(_on_reload_started_hud):
			w.reload_started.disconnect(_on_reload_started_hud)
		if w.reload_finished.is_connected(_on_reload_finished_hud):
			w.reload_finished.disconnect(_on_reload_finished_hud)
	gun.ammo_changed.connect(_ammo_hud.set_ammo)
	gun.reload_started.connect(_on_reload_started_hud)
	gun.reload_finished.connect(_on_reload_finished_hud)
	gun.emit_ammo()


func _on_reload_started_hud(_duration: float) -> void:
	if _ammo_hud != null:
		_ammo_hud.set_reloading(true)


func _on_reload_finished_hud() -> void:
	if _ammo_hud != null:
		_ammo_hud.set_reloading(false)


func _connect_gun_signals(gun: Gun) -> void:
	gun.fired.connect(_on_gun_fired.bind(gun))
	gun.hit_confirmed.connect(_on_hit_confirmed)
	gun.kill_confirmed.connect(_on_kill_confirmed)


func _on_gun_fired(gun: Gun) -> void:
	if _active_slot != gun:
		return
	# Impulse goes to spring TARGET (not applied value) — stage 2 lerp does the chasing.
	_recoil_target_pitch = minf(_recoil_target_pitch + gun.recoil_pitch, recoil_max)
	_recoil_target_yaw = clampf(
		_recoil_target_yaw + randf_range(-gun.recoil_yaw, gun.recoil_yaw), -recoil_max, recoil_max
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
	for body: Node3D in _hammer.get_hit_bodies():
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
	# Tween the OFFSET var only — player.gd is sole writer of _head.rotation.x.
	# Composited as: _head.rotation.x = clamp(_look_pitch + _recoil_pitch + _melee_kick_offset).
	var tw := create_tween()
	# Sharper downward punch (positive X = look down) for melee impact feel.
	tw.tween_property(self, "_melee_kick_offset", melee_kick_angle, kick_duration * 0.2)
	tw.tween_property(self, "_melee_kick_offset", 0.0, kick_duration * 1.2)
