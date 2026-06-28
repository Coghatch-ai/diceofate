# tools/lib/nav_utils.gd — runtime navmesh bake helper for drawn/greybox levels.
# Call NavUtils.ensure_baked(region) from a level's _ready() to bake on first play
# when the pre-baked .tres is empty (no polygon data). Skips bake if polys exist.
# Agent parameters (height/radius/max_climb) are read from the region's existing
# NavigationMesh resource — author them in the level's navmesh .tres, not in code.
class_name NavUtils


## Bakes [param region]'s NavigationMesh at runtime if it contains no polygons,
## then force-syncs the NavigationServer3D map so paths are queryable immediately.
## Without map_force_update the server only syncs at the end of the physics frame;
## agents that set target_position in the same frame as the bake would get no path.
## If region.navigation_mesh is null, creates a bare NavigationMesh (engine defaults)
## before baking — author agent params in the level's .tres to set them explicitly.
## Safe to call every load — cheap polygon-count guard avoids redundant bakes.
static func ensure_baked(region: NavigationRegion3D) -> void:
	if region == null:
		push_error("NavUtils.ensure_baked: region is null")
		return
	var nav_mesh: NavigationMesh = region.navigation_mesh
	if nav_mesh == null:
		nav_mesh = _make_default_mesh()
		region.navigation_mesh = nav_mesh
	if nav_mesh.get_polygon_count() > 0:
		print(
			(
				"NavUtils: navmesh already baked (%d polygons) — skipping."
				% nav_mesh.get_polygon_count()
			)
		)
		return
	# Bake synchronously.
	# geometry_parsed_geometry_type = PARSED_GEOMETRY_STATIC_COLLIDERS (1) — uses
	# CollisionShape3D data, works headless (no GPU/RenderingServer needed).
	# geometry_source_geometry_mode = SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN (1) — bake
	# finds nodes tagged with geometry_source_group_name ("navigation_mesh_source_group"
	# by default) and scans their children. The level root carries that group; the region
	# is a sibling, NOT a parent, so ROOT_NODE_CHILDREN (0) would scan an empty subtree.
	# Both settings are authored in the level's navmesh .tres — do not override here.
	region.bake_navigation_mesh(false)
	var polygon_count: int = nav_mesh.get_polygon_count()
	print("NavUtils: bake complete — %d polygons produced." % polygon_count)
	if polygon_count == 0:
		# 0 polygons = bake scope or parsed-geometry-type mismatch.
		# Check: navmesh .tres has geometry_parsed_geometry_type=1 (STATIC_COLLIDERS)
		# and geometry_source_geometry_mode=1 (GROUPS_WITH_CHILDREN); level root node
		# carries group "navigation_mesh_source_group" so the bake finds geometry siblings.
		push_error(
			(
				"NavUtils: bake produced 0 polygons — enemies will stand still. "
				+ "Check navmesh .tres geometry_parsed_geometry_type=1 and "
				+ "geometry_source_geometry_mode=1; level root must be in group "
				+ "'navigation_mesh_source_group'."
			)
		)
		return
	# Force-sync the nav server map so agents can query paths immediately in the
	# same frame, without waiting for the automatic end-of-physics-frame sync.
	# Without this call, NavigationAgent3D.is_navigation_finished() returns true and
	# get_next_path_position() returns the agent's own position — enemy never moves.
	NavigationServer3D.map_force_update(region.get_navigation_map())


# Creates a bare NavigationMesh when the region has none assigned.
# Agent params (height/radius/max_climb) use Godot engine defaults.
# Prefer authoring params in the level's navmesh .tres instead of hitting this path.
static func _make_default_mesh() -> NavigationMesh:
	return NavigationMesh.new()
