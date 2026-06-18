# entities/hud/controls_hud.gd — ControlsHud: toggle-able controls reference overlay (H key).
class_name ControlsHud
extends Control

@onready var _overlay: Panel = $Overlay


func _ready() -> void:
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		_overlay.visible = not _overlay.visible
		get_viewport().set_input_as_handled()
