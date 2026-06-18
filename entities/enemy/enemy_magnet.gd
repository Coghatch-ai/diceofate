# entities/enemy/enemy_magnet.gd — Magnet enemy: tint, pull-field group, 3-second touch grace.
# Overrides perform_attack() so touched_player only emits after continuous contact >= TOUCH_GRACE.
# If the player breaks contact (distance > attack_range) the accumulator resets — no life lost.
# Grunt / runner / tank are unaffected (they use the base perform_attack which emits immediately).
# Adds a translucent cyan radius bubble (RadiusBubble MeshInstance3D) matching pull_radius = 4.0 m
# in projectile.gd. If pull_radius changes, update the bubble scale in enemy_magnetic.tscn (2×4=8).
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")

## Seconds of continuous contact required before touched_player fires (H14).
## Reset any time the player leaves attack_range.
const TOUCH_GRACE: float = 3.0

# Accumulated contact time (seconds). Reset when player leaves attack_range.
var _contact_time: float = 0.0
# True once touched_player has been emitted for the current grab — prevents repeated fires
# until the player breaks contact and re-enters.
var _grace_fired: bool = false
# Bubble material kept as a typed ref so emission_energy_multiplier can be set without unsafe cast.
var _bubble_mat: StandardMaterial3D

@onready var _bubble: MeshInstance3D = $RadiusBubble


func _ready() -> void:
	super._ready()
	score_value = 4
	# Bullet attraction/bending via group "magnet" + projectile.gd — bullets steer toward this enemy.
	add_to_group("magnet")
	_apply_magnet_tint()
	_setup_bubble()


func _physics_process(delta: float) -> void:
	_update_contact(delta)


## Track contact time each physics frame.
## Accumulates while player is within attack_range; resets on exit; emits once at threshold.
func _update_contact(delta: float) -> void:
	var dist: float = distance_to_target()
	if dist <= attack_range:
		if _grace_fired:
			return
		_contact_time += delta
		# Charging tell: ramp bubble emission energy 0→1.5 as timer fills.
		_bubble_mat.emission_energy_multiplier = (_contact_time / TOUCH_GRACE) * 1.5
		if _contact_time >= TOUCH_GRACE:
			_grace_fired = true
			touched_player.emit(self)
	else:
		# Player left range — reset accumulator and tell.
		_contact_time = 0.0
		_grace_fired = false
		_bubble_mat.emission_energy_multiplier = 0.3


## Override base perform_attack: play lunge telegraph but do NOT emit touched_player.
## Emission happens only via _update_contact after TOUCH_GRACE seconds (H14).
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
