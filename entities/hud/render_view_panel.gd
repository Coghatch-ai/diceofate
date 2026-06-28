# entities/hud/render_view_panel.gd — generic render-to-texture view panel (MirrorViewConfig).
# Scouter = swap config .tres — no code changes needed for different placement.
class_name RenderViewPanel
extends Control

## Config resource. Swap .tres for a different look/placement.
@export var config: MirrorViewConfig

## Player node injected by HUD after level load.
var _player: Node3D = null

var _sub_viewport: SubViewport = null
var _mirror_cam: Camera3D = null
var _texture_rect: TextureRect = null
var _frame_rect: TextureRect = null


func _ready() -> void:
	if config == null:
		push_error("RenderViewPanel: config not assigned")
		return
	_build_panel()


func set_player(player: Node3D) -> void:
	_player = player
	# Share the player's World3D so the mirror cam sees the live game scene.
	if _sub_viewport != null and _player != null:
		# SEAM: get_viewport() returns Viewport; the main game viewport carries world_3d.
		@warning_ignore("unsafe_cast")
		var main_vp: Viewport = _player.get_viewport() as Viewport
		if main_vp != null:
			_sub_viewport.world_3d = main_vp.world_3d


func _process(_delta: float) -> void:
	if _player == null or _mirror_cam == null or config == null:
		return
	# Track player head each frame.
	var head: Node3D = _player.find_child("Head", true, false) as Node3D
	var eye_pos: Vector3
	if head != null:
		eye_pos = head.global_position
	else:
		eye_pos = _player.global_position + Vector3(0.0, 1.6, 0.0)

	_mirror_cam.global_position = eye_pos

	# Yaw: player body yaw + configured offset.
	var yaw_rad: float = _player.rotation.y + deg_to_rad(config.camera_yaw_offset)
	var pitch_rad: float = deg_to_rad(config.camera_pitch_offset)
	_mirror_cam.rotation = Vector3(pitch_rad, yaw_rad, 0.0)


## Positioned deferred after layout so the parent has its final rect.
## Units: panel_size and panel_offset are in parent Control coordinate space
## (same units as offset_left/top/right/bottom — the project's effective resolution).
## The anchor_preset corners are: 0=TOP_LEFT 1=TOP_RIGHT 2=BOTTOM_LEFT 3=BOTTOM_RIGHT 8=CENTER.
## panel_offset is ADDED to the corner position.
func _position_from_config() -> void:
	var ps: Vector2 = config.panel_size
	# get_parent_area_size() returns the available space in parent Control coordinates.
	# This is the correct reference for offset_* which are also in parent-local coordinates.
	# (Using get_viewport().get_visible_rect() fails on maximized windows at native resolution
	# because it returns the full physical pixel size, placing the panel off-screen.)
	var screen_sz: Vector2 = get_parent_area_size()

	# Compute corner origin in parent coordinates based on anchor_preset.
	var origin: Vector2
	match config.anchor_preset:
		0:  # TOP_LEFT
			origin = Vector2.ZERO
		1:  # TOP_RIGHT
			origin = Vector2(screen_sz.x - ps.x, 0.0)
		2:  # BOTTOM_LEFT
			origin = Vector2(0.0, screen_sz.y - ps.y)
		3:  # BOTTOM_RIGHT
			origin = Vector2(screen_sz.x - ps.x, screen_sz.y - ps.y)
		8:  # CENTER
			origin = (screen_sz - ps) * 0.5
		_:  # fallback: top-left
			origin = Vector2.ZERO

	# panel_offset shifts from the corner.
	origin += config.panel_offset

	# All anchors = 0 so offsets are absolute positions inside the parent.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = origin.x
	offset_top = origin.y
	offset_right = origin.x + ps.x
	offset_bottom = origin.y + ps.y


## Build SubViewport + Camera3D + TextureRect + optional frame at runtime.
func _build_panel() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Size is applied deferred so layout has settled.
	call_deferred("_position_from_config")

	# Solid background so the panel is visible before the SubViewport renders.
	var bg := ColorRect.new()
	bg.name = "PanelBg"
	bg.color = Color(0.0, 0.05, 0.0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# SubViewport — shares world_3d with main scene (own_world_3d = false by default).
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "MirrorSubViewport"
	_sub_viewport.size = config.render_size
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.own_world_3d = false
	add_child(_sub_viewport)

	# Camera inside the SubViewport. make_current() required — without it the viewport is black.
	_mirror_cam = Camera3D.new()
	_mirror_cam.name = "MirrorCamera"
	_mirror_cam.fov = config.camera_fov
	_mirror_cam.near = config.camera_near
	_sub_viewport.add_child(_mirror_cam)
	_mirror_cam.make_current()

	# TextureRect displays the SubViewport's output.
	_texture_rect = TextureRect.new()
	_texture_rect.name = "MirrorTexture"
	_texture_rect.texture = _sub_viewport.get_texture()
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.flip_h = config.flip_horizontal
	_texture_rect.modulate = config.tint_color
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	# Optional frame overlay texture.
	if config.frame_texture != null:
		_frame_rect = TextureRect.new()
		_frame_rect.name = "FrameOverlay"
		_frame_rect.texture = config.frame_texture
		_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_frame_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame_rect)
