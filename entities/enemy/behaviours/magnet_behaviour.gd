# entities/enemy/behaviours/magnet_behaviour.gd - bullet-pull field + visual bubble; no player dmg.
# Registers the enemy in the "magnet" group so projectile.gd steers bullets toward it.
# The bubble sphere is VISUAL ONLY — no collision, no player damage, no Area3D.
# Player damage is NOT emitted here; the magnet is a bullet-pull threat, not a melee attacker.
class_name MagnetBehaviour
extends EnemyBehaviour

const ART_STYLE := preload("res://tools/art_style.gd")

@export_group("Bubble")
## Bubble sphere radius (metres). Matches the MeshInstance3D scale in the scene.
@export_range(1.0, 20.0, 0.5) var bubble_radius: float = 4.0
## Albedo alpha of the bubble material (0 = invisible, 1 = opaque).
@export_range(0.0, 1.0, 0.01) var bubble_alpha: float = 0.5
## Base emission energy of the bubble at rest (player far away).
@export_range(0.0, 10.0, 0.1) var bubble_emission_energy: float = 2.0
## Emission multiplier at minimum proximity (player at max distance).
@export_range(0.0, 5.0, 0.05) var emission_min: float = 0.3
## Emission multiplier at maximum proximity (player touching bubble).
@export_range(0.0, 10.0, 0.1) var emission_max: float = 1.8

@export_group("Lunge")
## Scale factor applied to enemy mesh on lunge telegraph (XYZ).
@export var lunge_scale: Vector3 = Vector3(1.3, 0.7, 1.3)
## Duration in seconds for each phase of the lunge tween (out + return).
@export_range(0.01, 1.0, 0.01) var lunge_duration: float = 0.1

# Injected enemy ref (set in bind).
var _enemy: Enemy = null
# Bubble material ref — typed so emission_energy_multiplier is set without unsafe cast.
var _bubble_mat: StandardMaterial3D = null
# Resolved in bind() after add_child fires _ready() and the sub-tree exists.
var _bubble: MeshInstance3D = null


func bind(enemy: Node) -> void:
	_enemy = enemy as Enemy
	# Join magnet group so projectile.gd bullet-steering can find us.
	_enemy.add_to_group("magnet")
	_apply_magnet_tint()
	# Resolve bubble directly (not @onready) — bind() is called after add_child() on an
	# in-tree parent, so _ready() has fired and RadiusBubble exists in the sub-tree.
	# Doing this here (rather than _ready()) keeps all setup behind the _enemy ref.
	_bubble = get_node_or_null("RadiusBubble") as MeshInstance3D
	_setup_bubble()


## Movement role not taken — default nav walk used.
func wants_nav_velocity() -> bool:
	return false


## Attack role: scale-lunge telegraph only (visual). No player damage — magnet is bullet-pull only.
func do_attack() -> void:
	if _enemy == null:
		return
	# SEAM: _mesh_instance is a private var on Enemy; access via public property would be ideal,
	# but Enemy exposes no mesh property — replicate the lunge on the enemy's Mesh child.
	var mesh_node: Node3D = _enemy.get_node_or_null("Mesh") as Node3D
	if mesh_node == null:
		return
	var base_scale: Vector3 = mesh_node.scale
	var tw: Tween = _enemy.create_tween()
	tw.tween_property(mesh_node, "scale", base_scale * lunge_scale, lunge_duration)
	tw.tween_property(mesh_node, "scale", base_scale, lunge_duration)


func _physics_process(_delta: float) -> void:
	if _enemy == null:
		return
	_update_contact()


func _update_contact() -> void:
	# Bubble is VISUAL ONLY — no player damage emitted here.
	# Glow pulses brighter as the player approaches (pure feedback; no HP cost).
	if _bubble_mat == null:
		return
	var dist: float = _enemy.distance_to_target()
	var proximity: float = clampf(1.0 - dist / bubble_radius, 0.0, 1.0)
	_bubble_mat.emission_energy_multiplier = lerpf(emission_min, emission_max, proximity)


func _apply_magnet_tint() -> void:
	if _enemy == null:
		return
	var mesh_root: Node3D = _enemy.get_node_or_null("Mesh") as Node3D
	if mesh_root == null:
		return
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var tint_mat := StandardMaterial3D.new()
			tint_mat.albedo_color = ART_STYLE.ENEMY_MAGNET_MID
			tint_mat.emission_enabled = true
			tint_mat.emission = ART_STYLE.ENEMY_MAGNET_DARK
			tint_mat.emission_energy_multiplier = 0.4
			mi.set_surface_override_material(0, tint_mat)


func _setup_bubble() -> void:
	# RadiusBubble not found — no-op. This only happens if the node was removed from the
	# tscn or bind() was called before add_child(). Both are bugs in the caller, not here.
	if _bubble == null:
		return
	# Apply data-driven radius: duplicate the SphereMesh so instances don't share the resource,
	# then set radius/height from the export. bubble_radius default matches the tscn value.
	if _bubble.mesh is SphereMesh:
		# SEAM: _bubble.mesh is Mesh base type; is-guard proves SphereMesh before cast.
		@warning_ignore("unsafe_cast")
		var sm: SphereMesh = (_bubble.mesh as SphereMesh).duplicate() as SphereMesh
		sm.radius = bubble_radius
		sm.height = bubble_radius * 2.0
		_bubble.mesh = sm
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.albedo_color = Color(
		ART_STYLE.ENEMY_MAGNET_LIGHT.r,
		ART_STYLE.ENEMY_MAGNET_LIGHT.g,
		ART_STYLE.ENEMY_MAGNET_LIGHT.b,
		bubble_alpha
	)
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.emission_enabled = true
	_bubble_mat.emission = ART_STYLE.ENEMY_MAGNET_LIGHT
	_bubble_mat.emission_energy_multiplier = bubble_emission_energy
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# CULL_DISABLED: render both inner and outer faces of the sphere so the bubble is
	# visible whether the player is far away (sees outer face) or close (sees inner face).
	# CULL_BACK would hide the sphere entirely when the camera is inside the 4 m radius
	# because the inner face is the only face visible from that position.
	_bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth write disabled so the sphere does not occlude the opaque enemy mesh inside it.
	_bubble_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# Depth test active — sphere occludes behind walls/geometry correctly.
	# no_depth_test = true would bleed through all geometry.
	_bubble_mat.no_depth_test = false
	# render_priority = 1 draws after priority-0 opaques in the transparent pass.
	_bubble_mat.render_priority = 1
	_bubble.visible = true
	_bubble.set_surface_override_material(0, _bubble_mat)
