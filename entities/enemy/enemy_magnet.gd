# entities/enemy/enemy_magnet.gd — Magnet enemy: tint, pull-field group, visual charging bubble.
# Costs ONE life after 3 discrete hit events (player enters attack range after having left it).
# Each entry = one hit; counter resets after firing. Bubble ramps with hit count (visual tell).
# NOTE: "3 hits → lose ONE life" matches the lives system. To switch to instant game-over after
# 3 magnet hits regardless of remaining lives, replace the touched_player emit with a direct
# wave_manager.lose_life() call repeated until _lives==0, or expose a new signal — one-line swap.
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")

## Number of discrete player-enters-range events required before a life is lost.
const HITS_TO_DAMAGE: int = 3

# Count of discrete contact events since last life-loss (or start).
var _hit_count: int = 0
# True while player is currently inside attack_range — prevents counting continuous overlap
# as multiple hits; a new hit only registers on re-entry after the player has left.
var _player_in_range: bool = false
# Bubble material kept as typed ref so emission_energy_multiplier can be set without unsafe cast.
var _bubble_mat: StandardMaterial3D

@onready var _bubble: MeshInstance3D = $RadiusBubble


func _ready() -> void:
	super._ready()
	score_value = 4
	# Bullet attraction/bending via group "magnet" + projectile.gd — bullets steer toward this enemy.
	add_to_group("magnet")
	_apply_magnet_tint()
	_setup_bubble()


func _physics_process(_delta: float) -> void:
	_update_contact()


## Track discrete player-entry events each physics frame.
## A new hit is registered only when the player transitions from outside → inside attack_range.
func _update_contact() -> void:
	var dist: float = distance_to_target()
	var in_range: bool = dist <= attack_range

	if in_range and not _player_in_range:
		# Player just entered range — count as one hit.
		_hit_count += 1
		print("EnemyMagnet: hit %d/%d" % [_hit_count, HITS_TO_DAMAGE])
		if _hit_count >= HITS_TO_DAMAGE:
			_hit_count = 0
			touched_player.emit(self)
			bumped_player.emit(self)

	_player_in_range = in_range

	# Bubble ramp: fraction of hits accumulated (0→1 over HITS_TO_DAMAGE entries).
	var ramp: float = float(_hit_count) / float(HITS_TO_DAMAGE)
	if in_range:
		# Inside range: ramp emission toward 1.5 based on hit progress.
		_bubble_mat.emission_energy_multiplier = lerpf(0.5, 1.5, ramp)
	else:
		# Outside range: dim tell, still shows hit progress faintly.
		_bubble_mat.emission_energy_multiplier = lerpf(0.3, 0.8, ramp)


## Override base perform_attack: play lunge telegraph only; life-loss handled by _update_contact.
func perform_attack() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_mesh_instance, "scale", _base_scale * Vector3(1.3, 0.7, 1.3), 0.1)
	tw.tween_property(_mesh_instance, "scale", _base_scale, 0.1)


func _apply_magnet_tint() -> void:
	var mesh_root: Node3D = $Mesh
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var tint_mat := StandardMaterial3D.new()
			tint_mat.albedo_color = ART_STYLE.ENEMY_MAGNET_MID
			tint_mat.emission_enabled = true
			tint_mat.emission = ART_STYLE.ENEMY_MAGNET_DARK
			tint_mat.emission_energy_multiplier = 0.4
			mi.set_surface_override_material(0, tint_mat)


## Build the bubble material at runtime so energy ramp works on the typed ref _bubble_mat.
func _setup_bubble() -> void:
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.albedo_color = Color(
		ART_STYLE.ENEMY_MAGNET_LIGHT.r,
		ART_STYLE.ENEMY_MAGNET_LIGHT.g,
		ART_STYLE.ENEMY_MAGNET_LIGHT.b,
		0.15
	)
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.emission_enabled = true
	_bubble_mat.emission = ART_STYLE.ENEMY_MAGNET_LIGHT
	_bubble_mat.emission_energy_multiplier = 0.3
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble_mat.no_depth_test = false
	_bubble.set_surface_override_material(0, _bubble_mat)
