# entities/weapon/weapon.gd - firing component: spawns projectiles from a Muzzle, timer-gated.
class_name Weapon
extends Node3D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.2

@onready var _muzzle: Marker3D = $PistolViewModel/Muzzle
@onready var _cooldown: Timer = $Cooldown


func _ready() -> void:
	_cooldown.one_shot = true
	_cooldown.wait_time = fire_rate


## Called by the host on the shoot input. Returns true if a shot was fired.
func try_fire() -> bool:
	if not _cooldown.is_stopped():
		return false
	_fire()
	_cooldown.start()
	return true


func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as Projectile
	# Spawn into world space so the projectile travels independently of the firer.
	get_tree().current_scene.add_child(projectile)
	projectile.top_level = true
	projectile.global_transform = _muzzle.global_transform
