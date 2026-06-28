# entities/hud/mirror_view_config.gd — data-driven config for a render-to-texture view panel.
# Slice 2 = rear-view mirror; slice 3 (scouter) swaps to a different .tres — no code change.
class_name MirrorViewConfig
extends Resource

@export_group("Viewport")
## Render resolution of the SubViewport (pixels). Lower = cheaper. Default 320x180 (~18 % of 1080p).
@export var render_size: Vector2i = Vector2i(320, 180)
## Camera FOV in degrees.
@export_range(10.0, 160.0, 1.0) var camera_fov: float = 70.0
## Camera near clip (m). Raise to 0.5–1.0 to avoid clipping into nearby walls.
@export_range(0.05, 5.0, 0.05) var camera_near: float = 0.5
## Yaw offset added to player yaw (degrees). 180 = straight back; 0 = forward (scouter side-view).
@export_range(-360.0, 360.0, 1.0) var camera_yaw_offset: float = 180.0
## Pitch offset (degrees). 0 = level; negative tilts down.
@export_range(-90.0, 90.0, 1.0) var camera_pitch_offset: float = 0.0

@export_group("Display")
## Flip image horizontally (true = mirror; false = raw camera feed).
@export var flip_horizontal: bool = true
## Panel size on screen (pixels).
@export var panel_size: Vector2 = Vector2(213.0, 120.0)
## Panel anchor preset (Control.PRESET_*). 0=TOP_LEFT, 1=TOP_RIGHT, 3=BOTTOM_RIGHT.
@export_range(0, 15, 1) var anchor_preset: int = 3
## Pixel offset from the anchored corner.
@export var panel_offset: Vector2 = Vector2(-8.0, 8.0)

@export_group("Frame / Skin")
## Optional border texture drawn over the panel (null = plain rectangle).
@export var frame_texture: Texture2D
## Tint color applied to the TextureRect (alpha controls opacity).
@export var tint_color: Color = Color(1.0, 1.0, 1.0, 1.0)
