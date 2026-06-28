# entities/hud/minimap_tracked_group.gd — one entry in MinimapConfig.tracked_groups list.
class_name MinimapTrackedGroup
extends Resource

## Godot group name to scan (e.g. "enemies", "pickups").
@export var group_name: String = "enemies"
## Blip colour for nodes in this group.
@export var blip_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## Blip radius in pixels.
@export_range(1.0, 20.0, 0.5) var blip_radius: float = 4.0
