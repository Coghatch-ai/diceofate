# entities/enemy/behaviours/shooter_attack.gd — ShooterAttack: telegraph + fire projectile.
# Attack-role behaviour extracted from enemy_shooter.gd for trait-mixing.
class_name ShooterAttack
extends EnemyBehaviour

const ART_STYLE := preload("res://tools/art_style.gd")

@export_group("Projectile")
## Scene instantiated on each attack.
@export var projectile_scene: PackedScene
## Travel speed of the enemy projectile (m/s).
@export_range(4.0, 40.0, 0.5) var projectile_speed: float = 12.0

@export_group("Telegraph")
## Wind-up time before the shot fires (seconds).
@export_range(0.05, 2.0, 0.05) var telegraph_time: float = 0.4

# Injected enemy ref.
var _enemy: Enemy = null
# Guard: blocks re-entry while telegraph tween runs.
var _telegraphing: bool = false
# Per-surface tint materials kept typed for emission ramp.
var _tint_mats: Array[StandardMaterial3D] = []


func bind(enemy: Node) -> void:
	_enemy = enemy as Enemy
	_apply_shooter_tint()


## Attack role: LOS-gated telegraph then fire.
func do_attack() -> void:
	if _enemy == null or _telegraphing:
		return
	if not _enemy.can_see_target():
		return
	_telegraphing = true
	var tw: Tween = _enemy.create_tween()
	tw.set_parallel(true)
	for mat: StandardMaterial3D in _tint_mats:
		tw.tween_property(mat, "emission_energy_multiplier", 4.0, telegraph_time)
	tw.set_parallel(false)
	tw.tween_callback(_fire_at_player)
	tw.set_parallel(true)
	for mat: StandardMaterial3D in _tint_mats:
		tw.tween_property(mat, "emission_energy_multiplier", 0.3, 0.1)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _telegraphing = false)


func _fire_at_player() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if projectile_scene == null:
		return
	var t: Node3D = _enemy.target()
	if t == null:
		return
	var proj: Projectile = projectile_scene.instantiate() as Projectile
	var scene_root: Node = _enemy.get_tree().current_scene
	if scene_root == null:
		proj.queue_free()
		return
	scene_root.add_child(proj)
	proj.top_level = true
	var aim_from: Vector3 = _enemy.global_position + Vector3(0.0, 1.4, 0.0)
	var aim_to: Vector3 = t.global_position + Vector3(0.0, 0.9, 0.0)
	var forward: Vector3 = (aim_to - aim_from).normalized()
	proj.global_position = aim_from
	if forward.length_squared() > 0.001:
		proj.global_transform.basis = Basis.looking_at(-forward, Vector3.UP)
	proj.speed = projectile_speed
	# SEAM: hit signal carries Node3D + normal + pos; duck-check group before routing.
	proj.hit.connect(_on_projectile_hit, CONNECT_ONE_SHOT)


func _on_projectile_hit(body: Node3D, _normal: Vector3, _hit_pos: Vector3) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if body.is_in_group("player"):
		_enemy.touched_player.emit(_enemy)
		_enemy.bumped_player.emit(_enemy)


func _apply_shooter_tint() -> void:
	if _enemy == null:
		return
	var mesh_root: Node3D = _enemy.get_node_or_null("Mesh") as Node3D
	if mesh_root == null:
		return
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ART_STYLE.ENEMY_SHOOTER_MID
			mat.emission_enabled = true
			mat.emission = ART_STYLE.ENEMY_SHOOTER_DARK
			mat.emission_energy_multiplier = 0.3
			mi.set_surface_override_material(0, mat)
			_tint_mats.append(mat)
