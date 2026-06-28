# entities/hud/minimap_config.gd — tuning resource for RadarMinimap; edit the .tres to retune.
class_name MinimapConfig
extends Resource

@export_group("Radar")
## World radius (metres) within which nodes are shown on the radar.
@export_range(5.0, 200.0, 1.0) var detection_range: float = 40.0
## Pixel diameter of the circular radar widget.
@export_range(64.0, 512.0, 4.0) var radar_size: float = 160.0
## Clamp off-range blips to the ring edge instead of hiding them.
@export var clamp_to_edge: bool = true

@export_group("Appearance")
## Background fill colour (use alpha for transparency).
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.55)
## Colour of the radar ring border.
@export var ring_color: Color = Color(0.7, 0.7, 0.7, 0.8)
## Ring border width in pixels.
@export_range(1.0, 6.0, 0.5) var ring_width: float = 1.5
## Player blip colour (drawn at centre).
@export var player_color: Color = Color(0.2, 1.0, 0.4, 1.0)
## Player blip radius in pixels.
@export_range(2.0, 12.0, 0.5) var player_radius: float = 5.0
## Draw a short tick from player centre in facing direction.
@export var show_facing_tick: bool = true
## Length of facing tick in pixels.
@export_range(4.0, 30.0, 1.0) var facing_tick_length: float = 12.0

@export_group("Tracked Groups")
## Each entry defines one Godot group to plot, its blip colour and size.
## Add entries here to track new categories (pickups, NPCs) without code changes.
@export var tracked_groups: Array[MinimapTrackedGroup] = []
