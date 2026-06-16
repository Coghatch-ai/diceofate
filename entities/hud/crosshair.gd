# entities/hud/crosshair.gd — simple FPS crosshair drawn at screen center via _draw().
class_name Crosshair
extends Control

@export var arm_length: int = 8
@export var line_thickness: int = 2
@export var center_gap: int = 3
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.9)


func _draw() -> void:
	var cx: float = get_rect().size.x * 0.5
	var cy: float = get_rect().size.y * 0.5
	var half: float = float(arm_length)
	var g: float = float(center_gap)
	var t: float = float(line_thickness)
	# Horizontal bar (left arm + right arm).
	draw_rect(Rect2(cx - half, cy - t * 0.5, half - g, t), line_color)
	draw_rect(Rect2(cx + g, cy - t * 0.5, half - g, t), line_color)
	# Vertical bar (top arm + bottom arm).
	draw_rect(Rect2(cx - t * 0.5, cy - half, t, half - g), line_color)
	draw_rect(Rect2(cx - t * 0.5, cy + g, t, half - g), line_color)
