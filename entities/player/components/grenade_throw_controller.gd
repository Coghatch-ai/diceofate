# entities/player/components/grenade_throw_controller.gd — handles grenade throw input + cooldown.
# Composition component: signals up, calls down. Player calls throw_if_ready(); this spawns grenade.
class_name GrenadeThrowController
extends Node

signal grenade_thrown

## Grenade scene to spawn.
@export var grenade_scene: PackedScene
## Tuning resource. If null, grenade uses its own defaults.
@export var grenade_data: GrenadeData
## Camera/head node — aim source for throw direction.
@export var head: Node3D

var _cooldown_elapsed: float = 0.0
var _on_cooldown: bool = false


func _physics_process(delta: float) -> void:
	if _on_cooldown:
		_cooldown_elapsed += delta
		var cd: float = grenade_data.cooldown if grenade_data != null else 1.0
		if _cooldown_elapsed >= cd:
			_on_cooldown = false
			_cooldown_elapsed = 0.0


## Called by player on throw_grenade action. Returns true if thrown.
func try_throw() -> bool:
	if _on_cooldown:
		return false
	if grenade_scene == null:
		return false
	if head == null:
		return false
	_spawn_grenade()
	_on_cooldown = true
	_cooldown_elapsed = 0.0
	grenade_thrown.emit()
	return true


func _spawn_grenade() -> void:
	var grenade: Grenade = grenade_scene.instantiate() as Grenade
	grenade.data = grenade_data
	# Spawn into current scene (world space, not under player).
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		grenade.queue_free()
		return
	scene_root.add_child(grenade)
	# Place at head position, slightly forward to avoid self-collision.
	var throw_force: float = 18.0
	var arc_force: float = 6.0
	if grenade_data != null:
		throw_force = grenade_data.throw_force
		arc_force = grenade_data.arc_force
	var cam_basis: Basis = head.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	grenade.global_position = head.global_position + forward * 0.5
	# Apply impulse: forward component + upward arc.
	var impulse: Vector3 = forward * throw_force + Vector3.UP * arc_force
	grenade.apply_central_impulse(impulse)
