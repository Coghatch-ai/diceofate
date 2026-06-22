# entities/player/player.gd — first-person movement, mouse-look, jump, crouch,
# sprint, slide, head-bob, health.
class_name Player
extends CharacterBody3D

## Forwarded from HealthComponent so WaveManager can connect death without reaching into the comp.
signal died

@export var move_speed: float = 4.0
@export var move_accel: float = 6.0
@export var move_decel: float = 7.0
@export var jump_velocity: float = 9.0
## Overall gravity scale applied on top of the project-settings gravity (9.8 m/s²).
## Raise to make the whole arc faster without changing peak height formula:
## peak_height = jump_velocity² / (2 × gravity × gravity_scale).
@export var gravity_scale: float = 2.25
## Gravity multiplier applied while falling (velocity.y < 0). Values > 1 make the
## descent faster than the rise — snappier, less floaty feel. Tune alongside jump_velocity.
@export var fall_gravity_mult: float = 1.5
@export var mouse_sensitivity: float = 0.0016
## FOV while hip-firing (default).
@export var hip_fov: float = 75.0
## FOV while aiming down sights.
@export var ads_fov: float = 55.0
## Duration of the ADS FOV tween (seconds).
@export var ads_tween_time: float = 0.15
## Move speed multiplier while aiming.
@export var ads_move_scale: float = 0.6
## Sprint speed multiplier (hold sprint action).
@export var sprint_mult: float = 1.6
## Camera FOV while sprinting (hip_fov + kick).
@export var sprint_fov: float = 81.0
## Per-frame lerp rate for sprint FOV kick.
@export var sprint_fov_lerp: float = 8.0
## Crouched capsule height (stand = 1.8; radius 0.4 → min 0.8, so 1.2 is safe).
@export var crouch_height: float = 1.2
## Head/eye height while fully crouched.
@export var crouch_eye: float = 1.3
## Speed multiplier at full crouch (0 = still, 1 = normal).
@export var crouch_speed_mult: float = 0.5
## Lerp rate for crouch_amount transition (higher = snappier).
@export var crouch_lerp_speed: float = 12.0
## Head-bob vertical amplitude (meters) at walk speed.
@export var bob_amount: float = 0.012
## Head-bob cycle frequency (Hz) at walk speed.
@export var bob_freq: float = 1.8
## Multipliers applied to bob amplitude and frequency while sprinting.
## Dialled back from 1.3 — view-model SprintSway carries the arm-swing; avoid doubling.
@export var sprint_bob_mult: float = 1.05
## Sprint-bob frequency multiplier (separate from amplitude).
## Dialled back from 1.4 — footfall cadence only; sway handles the swing feel.
@export var sprint_bob_freq_mult: float = 1.1
## Slide duration in seconds before settling into crouch or stand.
@export var slide_duration: float = 0.55
## Friction (decel rate) applied to horizontal velocity during a slide.
@export var slide_friction: float = 3.5
## Optional small speed boost on slide entry (0 = no boost).
@export var slide_speed_boost: float = 1.5
## Maximum stamina pool.
@export var stamina_max: float = 100.0
## Stamina drained per second while sprinting.
@export var stamina_drain: float = 25.0
## Stamina regenerated per second when not sprinting.
@export var stamina_regen: float = 18.0
## Seconds after sprint ends before regen begins.
@export var stamina_regen_delay: float = 0.6
## Minimum stamina required to START a new sprint.
@export var stamina_min_to_sprint: float = 10.0
## Impulse speed (m/s) applied when an enemy bumps the player. Mirrors enemy _KNOCKBACK_SPEED.
@export var knockback_speed: float = 6.0
## Duration (s) input is suppressed and knockback decays after a bump. Mirrors enemy _STUN_DURATION.
@export var knockback_stun_duration: float = 0.15
## Starting + maximum HP. 100 = 4 enemy touches to die (25 dmg each).
@export_range(1, 500, 1) var max_health: int = 100
## HP restored by a health pickup.
@export_range(1, 200, 1) var heal_amount: int = 40

# SEAM: ProjectSettings.get_setting() returns Variant; the physics gravity setting is always float.
@warning_ignore("unsafe_cast")
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _was_on_floor: bool = false
var _crouch_amount: float = 0.0
var _aiming: bool = false
var _look_pitch: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_yaw_prev: float = 0.0
# Additive melee-kick offset — fetched from WeaponController each frame, summed here.
var _melee_kick_offset: float = 0.0
var _ads_tween: Tween
# Head-bob state — additive Y/X offsets on _head, never fight look/recoil/crouch.
var _bob_t: float = 0.0
var _bob_offset_y: float = 0.0
var _bob_offset_x: float = 0.0
# Slide state.
var _sliding: bool = false
var _slide_timer: float = 0.0
var _slide_vel: Vector3 = Vector3.ZERO
# Stamina state.
var _stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _was_sprinting: bool = false
# Knockback stun state — movement input skipped while _kb_stun_timer > 0.
var _kb_stun_timer: float = 0.0
var _kb_velocity: Vector3 = Vector3.ZERO
# HUD ref for stamina forwarding (player owns this; ammo goes via WeaponController).
var _arena_hud: ArenaHud

@onready var _weapon_controller: WeaponController = $WeaponController
@onready var _head: Node3D = _weapon_controller.get_head()
@onready var _camera: Camera3D = _weapon_controller.get_camera()
@onready var _jump_sfx: AudioStreamPlayer = $JumpSfx
@onready var _land_sfx: AudioStreamPlayer = $LandSfx
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _health_comp: HealthComponent = $HealthComponent


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.fov = hip_fov
	_stamina = stamina_max
	_health_comp.max_health = max_health
	_health_comp.reset()
	_health_comp.died.connect(_on_health_comp_died)
	_weapon_controller.health_pickup_requested.connect(_on_health_pickup_requested)


## Called by the level host (main.gd) after load to inject the HUD crosshair.
func set_crosshair(crosshair: Crosshair) -> void:
	_weapon_controller.set_crosshair(crosshair)


## Called by main.gd after load to wire weapon ammo/reload signals to the HUD.
## Player also keeps the ref to forward stamina each frame.
func set_ammo_hud(hud: ArenaHud) -> void:
	_arena_hud = hud
	_weapon_controller.set_ammo_hud(hud)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var scale_factor: float = get_window().content_scale_factor
		if scale_factor < 0.001:
			scale_factor = 1.0
		var sens: float = mouse_sensitivity / scale_factor
		# Yaw on the body, pitch tracked in _look_pitch (recoil added separately in physics).
		rotate_y(-motion.relative.x * sens)
		_look_pitch = clampf(_look_pitch - motion.relative.y * sens, -PI / 2.0, PI / 2.0)
		_head.rotation.x = clampf(
			_look_pitch + _recoil_pitch + _melee_kick_offset, -PI / 2.0, PI / 2.0
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var on_floor_now: bool = is_on_floor()

	# 1. Gravity while airborne. fall_gravity_mult applied when descending for snappier landing.
	if not on_floor_now:
		var grav_mult: float = fall_gravity_mult if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * gravity_scale * grav_mult * delta

	# 2. Jump only when grounded.
	if Input.is_action_just_pressed("jump") and on_floor_now:
		velocity.y = jump_velocity
		_jump_sfx.play()

	# 3. Land detection: floor transition airborne → grounded.
	if on_floor_now and not _was_on_floor:
		_land_sfx.play()

	_was_on_floor = on_floor_now

	# 4. ADS: hold aim to zoom; release to zoom back. Weapon state + FOV tween.
	var is_aiming_pressed: bool = Input.is_action_just_pressed("aim")
	var ads_released: bool = Input.is_action_just_released("aim")
	if is_aiming_pressed or ads_released:
		_weapon_controller.process_input(is_aiming_pressed, ads_released)
		_aiming = _weapon_controller.is_aiming()
		_update_ads_fov()
	else:
		_weapon_controller.process_input(false, false)
		_aiming = _weapon_controller.is_aiming()

	# 5. Spring recoil — two-stage lerp. Two-stage update via weapon_controller.
	_weapon_controller.update_recoil(delta)
	_recoil_pitch = _weapon_controller.get_recoil_pitch()
	_recoil_yaw = _weapon_controller.get_recoil_yaw()
	_recoil_yaw_prev = _weapon_controller.get_recoil_yaw_prev()
	_melee_kick_offset = _weapon_controller.get_melee_kick_offset()

	# 6. Single owner of _head.rotation.x: look + recoil + melee-kick summed here.
	# WeaponController tweens _melee_kick_offset 0→kick→0; never writes _head.rotation.x directly.
	_head.rotation.x = clampf(_look_pitch + _recoil_pitch + _melee_kick_offset, -PI / 2.0, PI / 2.0)
	rotation.y += _recoil_yaw - _recoil_yaw_prev
	_weapon_controller.set_recoil_yaw_prev(_recoil_yaw)

	# 7. Crouch — lerp crouch_amount toward 1 (held) or 0 (released/blocked), then apply shape.
	_update_crouch(delta)

	# 7a. Crouch-accuracy: inform active weapon of crouch state every frame.
	_weapon_controller.set_active_weapon_crouch(_crouch_amount >= 0.5)

	# 7b. Sprint/walk feel: forward movement state + velocity factor to weapon SprintSway.
	# Uses last frame's velocity (provisional) — close enough for sway.
	var flat_speed_prev: float = Vector3(velocity.x, 0.0, velocity.z).length()
	var vf: float = clampf(flat_speed_prev / (move_speed * sprint_mult), 0.0, 1.0)
	var is_moving_prev: bool = flat_speed_prev > 0.2 and is_on_floor()
	_weapon_controller.update_sprint(_was_sprinting, is_moving_prev, vf, delta)

	# 8. Knockback stun: decay impulse, override XZ, skip movement input while stunned.
	if _kb_stun_timer > 0.0:
		_kb_stun_timer -= delta
		_kb_velocity = _kb_velocity.move_toward(Vector3.ZERO, knockback_speed * delta)
		velocity.x = _kb_velocity.x
		velocity.z = _kb_velocity.z
		move_and_slide()
		_update_bob(delta, false, on_floor_now)
		return

	# 9. Movement — whole-vector lerp so direction changes carry momentum.
	# Per-axis lerp snapped each axis independently; reversing X while Z moves felt robotic.
	# Lerping the XZ vector as a unit means reversing bleeds through existing momentum.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Sprint: computed each frame — on floor, not aiming, not crouched, has forward input.
	# Hoisted above slide so both slide entry and movement block share the same value.
	var is_sprinting: bool = (
		Input.is_action_pressed("sprint")
		and on_floor_now
		and not _aiming
		and _crouch_amount < 0.5
		and input_dir != Vector2.ZERO
		and input_dir.y < 0.0
	)
	# Stamina gate: keep sprinting only while stamina remains; require a minimum to START.
	if is_sprinting:
		if _was_sprinting:
			is_sprinting = _stamina > 0.0
		else:
			is_sprinting = _stamina >= stamina_min_to_sprint

	# 8a. Slide — entry/tick/exit. Must run before normal movement block.
	# While _sliding, _update_slide owns velocity.x/z; normal block is skipped that frame.
	_update_slide(delta, is_sprinting, on_floor_now)

	# 8b. Stamina drain / regen.
	if is_sprinting:
		_stamina = maxf(0.0, _stamina - stamina_drain * delta)
		_stamina_regen_timer = stamina_regen_delay
	else:
		_stamina_regen_timer = maxf(0.0, _stamina_regen_timer - delta)
		if _stamina_regen_timer <= 0.0:
			_stamina = minf(stamina_max, _stamina + stamina_regen * delta)
	_was_sprinting = is_sprinting
	if _arena_hud != null:
		_arena_hud.set_stamina(_stamina, stamina_max)

	if not _sliding:
		# Layered effective_speed: base → ADS → sprint → crouch.
		var effective_speed: float = move_speed
		if _aiming:
			effective_speed *= ads_move_scale
		if is_sprinting:
			effective_speed *= sprint_mult
		effective_speed *= lerpf(1.0, crouch_speed_mult, _crouch_amount)
		# Sprint FOV kick: separate per-frame lerp, never touches the recoil spring.
		# Gated behind not _aiming so ADS tween owns fov exclusively while aimed.
		if not _aiming:
			var target_fov: float = sprint_fov if is_sprinting else hip_fov
			_camera.fov = lerpf(_camera.fov, target_fov, sprint_fov_lerp * delta)
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		var flat_vel := Vector3(velocity.x, 0.0, velocity.z)
		if direction != Vector3.ZERO:
			var target_vel: Vector3 = direction * effective_speed
			flat_vel = flat_vel.lerp(target_vel, move_accel * delta)
		else:
			flat_vel = flat_vel.lerp(Vector3.ZERO, move_decel * delta)
		velocity.x = flat_vel.x
		velocity.z = flat_vel.z

	# 10. Engine resolves collisions and updates position.
	move_and_slide()

	# 11. Head-bob — runs AFTER move_and_slide() and AFTER _update_crouch() has set
	# _head.position.y to the crouch eye height. _update_bob adds _bob_offset_y on top
	# (additive += confirmed in _update_bob body). Recoil writes _head.rotation.x, not
	# position, so no conflict.
	_update_bob(delta, is_sprinting, on_floor_now)


## Lerps crouch_amount toward target each frame and applies capsule/eye height.
## Ceiling gate: if key released but test_move detects overhead obstruction, hold at 1.
func _update_crouch(delta: float) -> void:
	const STAND_HEIGHT: float = 1.8
	const STAND_EYE: float = 1.6
	var want_crouch: bool = Input.is_action_pressed("crouch")
	# Ceiling check: attempt to un-crouch only if key released; if blocked, stay crouched.
	if not want_crouch and _crouch_amount > 0.01:
		var stand_delta: float = STAND_HEIGHT - lerpf(STAND_HEIGHT, crouch_height, _crouch_amount)
		if stand_delta > 0.001 and test_move(global_transform, Vector3.UP * stand_delta):
			want_crouch = true
	var crouch_target: float = 1.0 if want_crouch else 0.0
	_crouch_amount = lerpf(_crouch_amount, crouch_target, crouch_lerp_speed * delta)
	# Apply capsule height and re-anchor center so bottom stays at local Y = 0.
	# SEAM: _collision.shape is Shape3D; cast to CapsuleShape3D to set height/radius.
	@warning_ignore("unsafe_cast")
	var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
	var current_height: float = lerpf(STAND_HEIGHT, crouch_height, _crouch_amount)
	cap.height = current_height
	# Center-anchored capsule: position.y = height/2 keeps bottom at local 0.
	# Crouching DECREASES position.y (e.g. 0.9 → 0.6 at height 1.2).
	_collision.position.y = current_height / 2.0
	# Drive eye/head height.
	_head.position.y = lerpf(STAND_EYE, crouch_eye, _crouch_amount)


## Additive head-bob: advances sine clock by horizontal speed, applies Y+X offset to _head.
## Never overwrites _head.position.y directly — adds _bob_offset_y on top of crouch eye height.
func _update_bob(delta: float, is_sprinting: bool, on_floor: bool) -> void:
	var flat_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	# Amplitude eases to 0 when still or airborne (lerp toward 0 each frame).
	var amp_target: float = 0.0
	if flat_speed > 0.2 and on_floor:
		var sprint_a: float = sprint_bob_mult if is_sprinting else 1.0
		amp_target = bob_amount * sprint_a
	# Smooth amplitude transitions (ease-out when stopping).
	var bob_amp: float = lerpf(
		_bob_offset_y / bob_amount if bob_amount > 0.0 else 0.0,
		amp_target / bob_amount if bob_amount > 0.0 else 0.0,
		8.0 * delta
	)
	bob_amp = bob_amp * bob_amount

	# Advance clock scaled by current speed (faster walk = faster bob).
	var freq_mult: float = sprint_bob_freq_mult if is_sprinting else 1.0
	var speed_scale: float = clampf(flat_speed / move_speed, 0.0, 2.0)
	_bob_t += delta * bob_freq * freq_mult * speed_scale

	_bob_offset_y = sin(_bob_t * TAU) * bob_amp
	# Lateral: half-amplitude, half-frequency (subtle sway).
	_bob_offset_x = sin(_bob_t * PI) * bob_amp * 0.4

	# Apply ADDITIVELY: base crouch eye height already written to _head.position.y by _update_crouch.
	# We offset from that base rather than overwrite it.
	_head.position.y += _bob_offset_y
	_head.position.x = _bob_offset_x


## Slide entry/tick/exit logic (feature 3). No FSM — bool + timer.
## Entry: sprinting + just-pressed crouch + not already sliding.
## Tick: preserve slide velocity with low friction, force crouch.
## Exit: timer expired, jump pressed, or wall hit; settle to crouch-or-stand.
func _update_slide(delta: float, is_sprinting: bool, on_floor: bool) -> void:
	var crouch_just_pressed: bool = Input.is_action_just_pressed("crouch")

	# Entry: sprint + crouch-press + grounded + not mid-slide.
	if not _sliding and is_sprinting and crouch_just_pressed and on_floor:
		_sliding = true
		_slide_timer = slide_duration
		# Capture current horizontal velocity + optional boost along facing.
		var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		var boost_dir: Vector3 = (-transform.basis.z).normalized()
		_slide_vel = flat + boost_dir * slide_speed_boost

	if not _sliding:
		return

	_slide_timer -= delta

	# Exit conditions: timer, jump input, or no floor contact (hit wall → velocity killed by engine).
	var jumped: bool = Input.is_action_just_pressed("jump") and on_floor
	var wall_stop: bool = Vector3(velocity.x, 0.0, velocity.z).length() < 0.3
	if _slide_timer <= 0.0 or jumped or wall_stop:
		_sliding = false
		_slide_timer = 0.0
		return

	# Tick: bleed slide velocity via friction; engine applies via velocity.x/z.
	_slide_vel = _slide_vel.lerp(Vector3.ZERO, slide_friction * delta)
	velocity.x = _slide_vel.x
	velocity.z = _slide_vel.z


## Updates ADS FOV tween based on current aiming state. Crosshair visibility handled here.
func _update_ads_fov() -> void:
	var target_fov: float = ads_fov if _aiming else hip_fov
	if _ads_tween:
		_ads_tween.kill()
	_ads_tween = create_tween()
	_ads_tween.tween_property(_camera, "fov", target_fov, ads_tween_time)


## Forwarding method: delegates to weapon controller. Called by pickups (duck-typed).
func collect_pickup(kind: Pickup.Kind, ammo_caliber: StringName = &"light") -> bool:
	return _weapon_controller.collect_pickup(kind, ammo_caliber)


## Shove the player away from hitter_pos. Input locked for knockback_stun_duration seconds.
## Duck-typed seam — same signature as Enemy.apply_knockback (godot-composition rule).
func apply_knockback(hitter_pos: Vector3) -> void:
	var dir: Vector3 = global_position - hitter_pos
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = global_transform.basis.z
	_kb_velocity = dir.normalized() * knockback_speed
	_kb_stun_timer = knockback_stun_duration


## Delegate damage to HealthComponent. Duck-typed seam for DamageEffect / on_hit paths.
func apply_damage(amount: int) -> void:
	_health_comp.apply_damage(amount)


## Expose HealthComponent so WaveManager can wire health_changed → HUD without find_child.
func get_health_comp() -> HealthComponent:
	return _health_comp


## Handles health pickup signal from WeaponController. Heals the HealthComponent directly.
func _on_health_pickup_requested() -> void:
	_health_comp.heal(heal_amount)


func _on_health_comp_died() -> void:
	died.emit()
