# entities/hud/vignette.gd — movement vignette: darkens screen edges proportional to player speed.
class_name VignetteOverlay
extends ColorRect

## Speed (m/s) at which vignette reaches full intensity.
@export_range(0.1, 30.0, 0.1) var max_speed: float = 10.0
## Lerp rate for smoothing intensity changes (~0.2s at value 5.0).
@export_range(1.0, 20.0, 0.5) var lerp_rate: float = 5.0
## Maximum vignette intensity passed to shader (comfort cap).
@export_range(0.0, 1.0, 0.05) var peak_intensity: float = 0.75

var _material: ShaderMaterial
var _current_intensity: float = 0.0
var _player: CharacterBody3D


func _ready() -> void:
	_material = material as ShaderMaterial
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
	var target: float = 0.0
	if is_instance_valid(_player):
		var flat_speed: float = Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
		target = clampf(flat_speed / max_speed, 0.0, 1.0) * peak_intensity
	_current_intensity = lerpf(_current_intensity, target, lerp_rate * delta)
	if _material:
		_material.set_shader_parameter("intensity", _current_intensity)


func _find_player() -> CharacterBody3D:
	var nodes: Array = get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	# SEAM: group lookup returns untyped Node; cast safe because only
	# CharacterBody3D nodes join the "player" group.
	@warning_ignore("unsafe_cast")
	return nodes[0] as CharacterBody3D
