# entities/hud/crosshair.gd — simple FPS crosshair drawn at screen center via _draw().
class_name Crosshair
extends Control

@export var arm_length: int = 8
@export var line_thickness: int = 2
@export var center_gap: int = 3
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.9)

@export var fire_pop_scale: float = 1.6
@export var fire_pop_duration: float = 0.12
@export var hit_color: Color = Color(1.0, 0.55, 0.1, 1.0)
@export var hit_pop_duration: float = 0.18
@export var kill_color: Color = Color(0.2, 1.0, 0.8, 1.0)
@export var kill_pop_scale: float = 1.8
@export var kill_pop_duration: float = 0.22
@export var aim_expand_scale: float = 3.5
@export var aim_tween_duration: float = 0.12

var _pop_scale: float = 1.0
var _aim_scale: float = 1.0
var _pop_alpha: float = 0.9
var _pop_color: Color = Color(1.0, 1.0, 1.0, 0.9)
var _aim_tween: Tween


func _draw() -> void:
	var cx: float = get_rect().size.x * 0.5
	var cy: float = get_rect().size.y * 0.5
	var combined: float = _pop_scale * _aim_scale
	var half: float = float(arm_length) * combined
	var g: float = float(center_gap) * combined
	var t: float = float(line_thickness)
	var col := Color(_pop_color.r, _pop_color.g, _pop_color.b, _pop_alpha)
	# Horizontal bar (left arm + right arm).
	draw_rect(Rect2(cx - half, cy - t * 0.5, half - g, t), col)
	draw_rect(Rect2(cx + g, cy - t * 0.5, half - g, t), col)
	# Vertical bar (top arm + bottom arm).
	draw_rect(Rect2(cx - t * 0.5, cy - half, t, half - g), col)
	draw_rect(Rect2(cx - t * 0.5, cy + g, t, half - g), col)


## Brief scale/alpha pop on weapon fire.
func fire_pop() -> void:
	_pop_color = line_color
	var tw := create_tween()
	tw.tween_method(_set_pop_scale, fire_pop_scale, 1.0, fire_pop_duration)
	tw.parallel().tween_method(_set_pop_alpha, 1.0, line_color.a, fire_pop_duration)


## Brief color flash on confirmed projectile hit (hitmarker).
func hit_pop() -> void:
	_pop_color = hit_color
	_pop_alpha = 1.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_method(_set_pop_alpha, 1.0, line_color.a, hit_pop_duration)
	tw.tween_callback(_reset_color)


## Distinct kill-confirm pop: cyan-white scale burst + fade. Overrides any in-flight hit flash.
func kill_pop() -> void:
	_pop_color = kill_color
	_pop_alpha = 1.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_method(_set_pop_scale, kill_pop_scale, 1.0, kill_pop_duration)
	tw.parallel().tween_method(_set_pop_alpha, 1.0, line_color.a, kill_pop_duration)
	tw.tween_callback(_reset_color)


## Expand crosshair while aiming to telegraph projectile spread (intentionally inverted ADS).
func set_aiming_state(aiming: bool) -> void:
	if _aim_tween != null:
		_aim_tween.kill()
	_aim_tween = create_tween()
	var target: float = aim_expand_scale if aiming else 1.0
	_aim_tween.tween_method(_set_aim_scale, _aim_scale, target, aim_tween_duration)


func _set_aim_scale(v: float) -> void:
	_aim_scale = v
	queue_redraw()


func _set_pop_scale(v: float) -> void:
	_pop_scale = v
	queue_redraw()


func _set_pop_alpha(v: float) -> void:
	_pop_alpha = v
	queue_redraw()


func _reset_color() -> void:
	_pop_color = line_color
	queue_redraw()
