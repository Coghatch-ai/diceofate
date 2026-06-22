# entities/enemy/behaviours/magnet_behaviour.gd — MagnetBehaviour: pull-field group + bubble.
# Attack-role behaviour extracted from enemy_magnet.gd for trait-mixing.
# Counts discrete player-entry events; after hits_to_damage entries emits touched_player.
class_name MagnetBehaviour
extends EnemyBehaviour

const ART_STYLE := preload("res://tools/art_style.gd")

## Discrete player-entry events before a life is lost.
@export_range(1, 10, 1) var hits_to_damage: int = 3

@export_group("Bubble")
## Bubble sphere radius (metres). Matches the MeshInstance3D scale in the scene.
@export_range(1.0, 20.0, 0.5) var bubble_radius: float = 4.0

# Injected enemy ref (set in bind).
var _enemy: Enemy = null
# Hit counter — resets after firing.
var _hit_count: int = 0
# True while player is inside attack_range (prevents counting continuous overlap).
var _player_in_range: bool = false
# Bubble material ref — typed so emission_energy_multiplier is set without unsafe cast.
var _bubble_mat: StandardMaterial3D = null

@onready var _bubble: MeshInstance3D = $RadiusBubble


func bind(enemy: Node) -> void:
	_enemy = enemy as Enemy
	# Join magnet group so projectile.gd bullet-steering can find us.
	_enemy.add_to_group("magnet")
	_apply_magnet_tint()
	_setup_bubble()


## Movement role not taken — default nav walk used.
func wants_nav_velocity() -> bool:
	return false


## Attack role: scale-lunge telegraph only; life-loss is driven by _physics_process contact.
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
	tw.tween_property(mesh_node, "scale", base_scale * Vector3(1.3, 0.7, 1.3), 0.1)
	tw.tween_property(mesh_node, "scale", base_scale, 0.1)


func _physics_process(_delta: float) -> void:
	if _enemy == null:
		return
	_update_contact()


func _update_contact() -> void:
	var dist: float = _enemy.distance_to_target()
	var in_range: bool = dist <= _enemy.attack_range

	if in_range and not _player_in_range:
		_hit_count += 1
		if _hit_count >= hits_to_damage:
			_hit_count = 0
			_enemy.touched_player.emit(_enemy)
			_enemy.bumped_player.emit(_enemy)

	_player_in_range = in_range

	var ramp: float = float(_hit_count) / float(hits_to_damage)
	if _bubble_mat == null:
		return
	if in_range:
		_bubble_mat.emission_energy_multiplier = lerpf(0.5, 1.5, ramp)
	else:
		_bubble_mat.emission_energy_multiplier = lerpf(0.3, 0.8, ramp)


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
	if _bubble == null:
		return
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.albedo_color = Color(
		ART_STYLE.ENEMY_MAGNET_LIGHT.r,
		ART_STYLE.ENEMY_MAGNET_LIGHT.g,
		ART_STYLE.ENEMY_MAGNET_LIGHT.b,
		0.5
	)
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.emission_enabled = true
	_bubble_mat.emission = ART_STYLE.ENEMY_MAGNET_LIGHT
	_bubble_mat.emission_energy_multiplier = 2.0
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_bubble_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_bubble_mat.no_depth_test = false
	_bubble_mat.render_priority = 1
	_bubble.set_surface_override_material(0, _bubble_mat)
