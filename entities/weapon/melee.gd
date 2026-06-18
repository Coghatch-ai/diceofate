# entities/weapon/melee.gd — melee hammer: Area3D hitbox swing, always-available on key V.
# Damage 1 per hit (kills grunt/runner/magnet in 1, tank in 3). Range ~2.2 m. Cooldown 0.75 s.
# Plugs into the same hit_confirmed/kill_confirmed contract as weapon.gd (godot-fps-enemy-combat).
# Hit detection: monitoring is ALWAYS ON (never toggled — toggling clears the physics overlap
# cache, making get_overlapping_bodies() return empty for bodies already in range).
# On swing: query get_overlapping_bodies() for stationary/already-in-range enemies first,
# then body_entered handles enemies that walk into the hitbox during the swing window.
# Damage gated by _swing_active flag, NOT by toggling monitoring.
# Animation: vertical hammer chop — pitches UP (X negative) on wind-up, smashes DOWN (X positive),
# recovers to rest. Pure X-rotation, no Y-yaw — straight top-to-down chop.
class_name Melee
extends Node3D

signal hit_confirmed
signal kill_confirmed
## Emitted on every confirmed melee connect; carries the hitter's world position so
## player.gd can relay knockback direction to the struck body.
signal hit_with_position(hitter_pos: Vector3)

# Rest: centred, neutral.
const _VM_REST_POS := Vector3(0.0, 0.0, 0.0)
const _VM_REST_ROT := Vector3.ZERO
# Wind-up: pulled overhead/back — pure pitch up (negative X = tilts up in view-model space).
const _VM_WINDUP_POS := Vector3(0.0, 0.08, -0.05)
const _VM_WINDUP_ROT := Vector3(-70.0, 0.0, 0.0)
# Strike: hammered straight down — pitch forward past neutral.
const _VM_SLASH_POS := Vector3(0.0, -0.08, -0.10)
const _VM_SLASH_ROT := Vector3(55.0, 0.0, 0.0)

## Seconds between swings.
@export var cooldown: float = 0.75

var _on_cooldown: bool = false
var _swing_active: bool = false
var _thrust_tween: Tween

@onready var _hitbox: Area3D = $MeleeHitbox
@onready var _cooldown_timer: Timer = $Cooldown
@onready var _view_model: Node3D = $HammerViewModel


func _ready() -> void:
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_done)
	_view_model.visible = false
	# monitoring stays TRUE permanently — toggling it clears the physics overlap cache,
	# which breaks get_overlapping_bodies() for enemies already inside the hitbox.
	# Damage is gated by _swing_active instead.
	_hitbox.monitoring = true
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


## Called by player.gd on melee input press.
func try_melee() -> bool:
	if _on_cooldown:
		return false
	_on_cooldown = true
	_cooldown_timer.start()
	_play_thrust()
	_open_damage_window()
	return true


## Open the damage window for windup + slash phases, then close it.
## Window = windup (15% of cooldown) + slash (30% of cooldown).
## monitoring stays on permanently; damage gated by _swing_active flag.
func _open_damage_window() -> void:
	var windup: float = cooldown * 0.15
	var slash: float = cooldown * 0.30
	_swing_active = true
	# Hit enemies already overlapping the hitbox at swing start (stationary/in-range case).
	# body_entered handles enemies that enter during the window.
	for body: Node3D in _hitbox.get_overlapping_bodies():
		_apply_hit(body)
	# Close after windup+slash; recover phase has no damage.
	get_tree().create_timer(windup + slash).timeout.connect(_close_damage_window, CONNECT_ONE_SHOT)


func _close_damage_window() -> void:
	_swing_active = false


func _on_hitbox_body_entered(body: Node3D) -> void:
	if not _swing_active:
		return
	_apply_hit(body)


## Shared hit logic for both already-overlapping and mid-swing-entering bodies.
func _apply_hit(body: Node3D) -> void:
	if not body.has_method("on_hit"):
		return
	# SEAM: duck-typed hit — any body with on_hit() is a valid melee target (godot-composition).
	@warning_ignore("unsafe_method_access")
	body.on_hit()
	hit_confirmed.emit()
	# Carry hitter position so player.gd can push knockback in the correct direction.
	hit_with_position.emit(global_position)
	# Kill-confirm: subscribe one-shot to died if the target has it.
	# Guard: is_connected check prevents double-connect on multi-hit enemies (CONNECT_ONE_SHOT
	# only auto-removes AFTER died fires; a surviving tank stays connected between swings).
	if body.has_signal("died"):
		# SEAM: died proven present by has_signal; Node3D base provides connect/is_connected.
		@warning_ignore("unsafe_method_access")
		if not body.is_connected("died", _on_target_died):
			body.connect("died", _on_target_died, CONNECT_ONE_SHOT)


func _on_target_died(_enemy: Node) -> void:
	kill_confirmed.emit()


func _on_cooldown_done() -> void:
	_on_cooldown = false


func _play_thrust() -> void:
	# Kill any in-flight tween and snap to known rest state before starting.
	# This prevents corrupt transform state from partial tweens on rapid re-press.
	if _thrust_tween and _thrust_tween.is_valid():
		_thrust_tween.kill()
	_view_model.position = _VM_REST_POS
	_view_model.rotation_degrees = _VM_REST_ROT
	_view_model.visible = true

	var windup: float = cooldown * 0.15
	var slash: float = cooldown * 0.30
	var recover: float = cooldown * 0.55

	# Chained parallel groups: tween_parallel() adds to current step in parallel;
	# chain() advances to next sequential step.
	_thrust_tween = create_tween()

	# Phase 1: wind-up — snap hammer up-right-back (anticipation).
	(
		_thrust_tween
		. tween_property(_view_model, "position", _VM_WINDUP_POS, windup)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_thrust_tween
		. parallel()
		. tween_property(_view_model, "rotation_degrees", _VM_WINDUP_ROT, windup)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)

	# Phase 2: smash — fast diagonal down-left arc (the swing).
	(
		_thrust_tween
		. tween_property(_view_model, "position", _VM_SLASH_POS, slash)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	(
		_thrust_tween
		. parallel()
		. tween_property(_view_model, "rotation_degrees", _VM_SLASH_ROT, slash)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)

	# Phase 3: recover — return to rest.
	(
		_thrust_tween
		. tween_property(_view_model, "position", _VM_REST_POS, recover)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)
	(
		_thrust_tween
		. parallel()
		. tween_property(_view_model, "rotation_degrees", _VM_REST_ROT, recover)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_SINE)
	)

	_thrust_tween.tween_callback(func() -> void: _view_model.visible = false)
