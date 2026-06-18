# entities/enemy/enemy_shooter.gd — Shooter: telegraph tween then fires slow projectile at player.
# Overrides perform_attack() with LOS-gated telegraph + _fire_at_player().
# touched_player emits via report_ranged_hit() called by the projectile hit signal.
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")

## Scene instantiated on each attack.
@export var projectile_scene: PackedScene
## Travel speed of the enemy projectile (m/s). Player projectile is 30; this is dodgeable.
@export var projectile_speed: float = 12.0
## Wind-up time before the shot fires (seconds).
@export var telegraph_time: float = 0.4

# True while the telegraph tween is running — blocks re-entry into perform_attack().
var _telegraphing: bool = false
# Cached mesh material for the telegraph flash (built once in _ready, reused per shot).
var _tint_mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	score_value = 2
	_apply_shooter_tint()


func _apply_shooter_tint() -> void:
	var mesh_root: Node3D = $Mesh
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			_tint_mat = StandardMaterial3D.new()
			_tint_mat.albedo_color = ART_STYLE.ENEMY_SHOOTER_MID
			_tint_mat.emission_enabled = true
			_tint_mat.emission = ART_STYLE.ENEMY_SHOOTER_DARK
			_tint_mat.emission_energy_multiplier = 0.3
			mi.set_surface_override_material(0, _tint_mat)


## Called by AttackState on cooldown gate. LOS-gated: won't blind-fire through walls.
func perform_attack() -> void:
	if _telegraphing:
		return
	if not can_see_target():
		return
	_telegraphing = true
	# Telegraph: ramp emission bright then fire.
	var tw: Tween = create_tween()
	tw.tween_property(_tint_mat, "emission_energy_multiplier", 4.0, telegraph_time)
	tw.tween_callback(_fire_at_player)
	tw.tween_property(_tint_mat, "emission_energy_multiplier", 0.3, 0.1)
	tw.tween_callback(func() -> void: _telegraphing = false)


func _fire_at_player() -> void:
	if projectile_scene == null:
		return
	var t: Node3D = target()
	if t == null:
		return
	var proj: Projectile = projectile_scene.instantiate() as Projectile
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		proj.queue_free()
		return
	scene_root.add_child(proj)
	proj.top_level = true
	# Aim from body centre toward player capsule centre (+0.9 y offset like magnet aim).
	var aim_from: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	var aim_to: Vector3 = t.global_position + Vector3(0.0, 0.9, 0.0)
	var forward: Vector3 = (aim_to - aim_from).normalized()
	proj.global_position = aim_from
	# Orient so local -Z points along forward direction.
	if forward.length_squared() > 0.001:
		proj.global_transform.basis = Basis.looking_at(-forward, Vector3.UP)
	proj.speed = projectile_speed
	# SEAM: hit signal carries Node3D; duck-check for player group before routing life seam.
	proj.hit.connect(_on_projectile_hit, CONNECT_ONE_SHOT)


func _on_projectile_hit(body: Node3D) -> void:
	if body.is_in_group("player"):
		report_ranged_hit()


## Routes a projectile-player collision to the existing touch→life seam.
## Mirrors the magnet's touched_player.emit(self) path so WaveManager needs no changes.
func report_ranged_hit() -> void:
	touched_player.emit(self)
