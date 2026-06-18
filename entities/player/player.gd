# entities/player/player.gd — first-person movement, mouse-look, jump, weapon firing, ADS, recoil.
class_name Player
extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var melee_kick_angle: float = 0.07
## Duration of the melee camera kick tween (seconds).
@export var kick_duration: float = 0.08
## Seconds Engine.time_scale is suppressed on melee connect (real-time, ignores time_scale).
@export var hit_stop_duration: float = 0.06
@export var hit_stop_scale: float = 0.05
## FOV while hip-firing (default).
@export var hip_fov: float = 75.0
## FOV while aiming down sights.
@export var ads_fov: float = 55.0
## Duration of the ADS FOV tween (seconds).
@export var ads_tween_time: float = 0.15
## Move speed multiplier while aiming.
@export var ads_move_scale: float = 0.6
## Recoil decay rate (radians/second back toward zero).
@export var recoil_recover: float = 8.0
## Maximum accumulated recoil pitch (radians).
@export var recoil_max: float = 0.18

# SEAM: ProjectSettings.get_setting() returns Variant; the physics gravity setting is always float.
@warning_ignore("unsafe_cast")
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _was_on_floor: bool = false
var _swapping: bool = false
var _hit_stop_active: bool = false
var _aiming: bool = false
var _look_pitch: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _ads_tween: Tween
var _crosshair: Crosshair
var _ammo_hud: ArenaHud
var _active_weapon: Weapon

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _pistol: Weapon = $Head/Weapon
@onready var _rifle: Weapon = $Head/Rifle
@onready var _melee: Melee = $Head/Melee
@onready var _jump_sfx: AudioStreamPlayer = $JumpSfx
@onready var _land_sfx: AudioStreamPlayer = $LandSfx


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_active_weapon = _pistol
	_pistol.visible = true
	_rifle.visible = false
	_connect_weapon_signals(_pistol)
	_connect_weapon_signals(_rifle)
	_melee.hit_confirmed.connect(_on_hit_confirmed)
	_melee.kill_confirmed.connect(_on_kill_confirmed)
	_melee.hit_with_position.connect(_on_melee_hit)
	_camera.fov = hip_fov


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_crosshair = crosshair


## Called by main.gd after load to wire weapon ammo/reload signals to the HUD.
func set_ammo_hud(hud: ArenaHud) -> void:
	_ammo_hud = hud
	_wire_ammo_hud(_active_weapon)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Yaw on the body, pitch tracked in _look_pitch (recoil added separately in physics).
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_look_pitch = clampf(
			_look_pitch - motion.relative.y * mouse_sensitivity, -PI / 2.0, PI / 2.0
		)
		_head.rotation.x = clampf(_look_pitch + _recoil_pitch, -PI / 2.0, PI / 2.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var on_floor_now: bool = is_on_floor()

	# 1. Gravity while airborne.
	if not on_floor_now:
		velocity.y -= _gravity * delta

	# 2. Jump only when grounded.
	if Input.is_action_just_pressed("jump") and on_floor_now:
		velocity.y = jump_velocity
		_jump_sfx.play()

	# 3. Land detection: floor transition airborne → grounded.
	if on_floor_now and not _was_on_floor:
		_land_sfx.play()

	_was_on_floor = on_floor_now

	# 4. ADS: hold aim to zoom; release to zoom back.
	if Input.is_action_just_pressed("aim"):
		_set_aiming(true)
	elif Input.is_action_just_released("aim"):
		_set_aiming(false)

	# 5. Recoil decay — pitch and yaw recover toward zero when not actively firing.
	if _recoil_pitch > 0.0:
		_recoil_pitch = maxf(0.0, _recoil_pitch - recoil_recover * delta)
	if _recoil_yaw != 0.0:
		var sign_yaw: float = signf(_recoil_yaw)
		_recoil_yaw = sign_yaw * maxf(0.0, absf(_recoil_yaw) - recoil_recover * delta)

	# 6. Apply accumulated recoil as additive offset on top of mouse-look pitch.
	# _look_pitch holds the pure mouse-look value; _recoil_pitch is layered on top.
	# Writing head.rotation.x here is safe: _unhandled_input already updated _look_pitch.
	_head.rotation.x = clampf(_look_pitch + _recoil_pitch, -PI / 2.0, PI / 2.0)

	# 7. Movement — scale speed when aiming.
	var effective_speed: float = move_speed * (ads_move_scale if _aiming else 1.0)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, effective_speed)
		velocity.z = move_toward(velocity.z, 0.0, effective_speed)

	# 8. Fire on left-click (held); cooldown timer caps cadence, not input.
	if Input.is_action_pressed("shoot"):
		_active_weapon.try_fire()

	# 9. Manual reload (R); weapon guards against full mag / already reloading.
	if Input.is_action_just_pressed("reload"):
		_active_weapon.start_reload()

	# 10. Swap weapon (Q) — debounced: ignore while swap in flight.
	if Input.is_action_just_pressed("equip_weapon") and not _swapping:
		_swap_weapon()

	# 11. Melee swing (V) — always available, independent of active gun.
	if Input.is_action_just_pressed("melee"):
		_melee.try_melee()

	# 12. Engine resolves collisions and updates position.
	move_and_slide()


func _set_aiming(aiming: bool) -> void:
	_aiming = aiming
	_active_weapon.set_aiming(aiming)
	var target_fov: float = ads_fov if aiming else hip_fov
	if _ads_tween:
		_ads_tween.kill()
	_ads_tween = create_tween()
	_ads_tween.tween_property(_camera, "fov", target_fov, ads_tween_time)
	if _crosshair != null:
		_crosshair.visible = not aiming


func _swap_weapon() -> void:
	# Cancel ADS before swapping.
	if _aiming:
		_set_aiming(false)
		_camera.fov = hip_fov
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
	_ammo_hud.set_reloading(true)


func _on_reload_finished_hud() -> void:
	_ammo_hud.set_reloading(false)


func _connect_weapon_signals(weapon: Weapon) -> void:
	weapon.fired.connect(_on_weapon_fired)
	weapon.hit_confirmed.connect(_on_hit_confirmed)
	weapon.kill_confirmed.connect(_on_kill_confirmed)


func _on_weapon_fired() -> void:
	# Accumulate recoil from the active weapon's per-weapon exports.
	_recoil_pitch = minf(_recoil_pitch + _active_weapon.recoil_pitch, recoil_max)
	_recoil_yaw += randf_range(-_active_weapon.recoil_yaw, _active_weapon.recoil_yaw)
	if _crosshair != null:
		_crosshair.fire_pop()


func _on_hit_confirmed() -> void:
	if _crosshair != null:
		_crosshair.hit_pop()


func _on_kill_confirmed() -> void:
	if _crosshair != null:
		_crosshair.kill_pop()


## Collects a pickup by kind. AMMO → refills active weapon; HEALTH → adds a life via WaveManager.
## Returns true if something changed (pickup consumed), false if no-op (already full).
func collect_pickup(kind: Pickup.Kind) -> bool:
	match kind:
		Pickup.Kind.AMMO:
			return _active_weapon.refill_ammo()
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


## Fires on every melee body connect. Owns hit-stop, melee camera kick, knockback relay.
func _on_melee_hit(hitter_pos: Vector3) -> void:
	_do_hit_stop()
	_do_melee_camera_kick()
	# Relay knockback to every overlapping body that supports it (duck-typed, godot-composition).
	# _melee hitbox overlapping bodies are the same set that triggered the hit.
	for body: Node3D in _melee._hitbox.get_overlapping_bodies():
		if body.has_method("apply_knockback"):
			# SEAM: duck-typed knockback — any body with apply_knockback(Vector3) is valid.
			@warning_ignore("unsafe_method_access")
			body.apply_knockback(hitter_pos)


## Brief time_scale dip on melee connect. Re-entrant-safe: guard prevents overlapping dips
## from stacking (only one active at a time). Always restores to 1.0 via real-time timer.
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
