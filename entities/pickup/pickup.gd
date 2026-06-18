# entities/pickup/pickup.gd — Area3D pickup: detects player, routes collect, hides + respawns.
class_name Pickup
extends Area3D

enum Kind { AMMO, HEALTH }

@export var kind: Kind = Kind.AMMO
@export var respawn_time: float = 15.0
## Ammo caliber this crate supplies. Matched against Weapon.caliber on collect. AMMO kind only.
@export var ammo_caliber: StringName = &"light"

var _consumed: bool = false

@onready var _mesh: Node3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _collect_sfx: AudioStreamPlayer = $CollectSfx
@onready var _respawn_timer: Timer = $Respawn


func _ready() -> void:
	_respawn_timer.wait_time = respawn_time
	_respawn_timer.timeout.connect(_on_respawn)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _consumed:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("collect_pickup"):
		return
	# SEAM: duck-typed collect — any body with collect_pickup(Kind, StringName) can trigger this.
	@warning_ignore("unsafe_method_access")
	var collected: bool = body.collect_pickup(kind, ammo_caliber)
	if not collected:
		return
	_consumed = true
	_mesh.visible = false
	_collision.disabled = true
	_collect_sfx.play()
	_respawn_timer.start()


func _on_respawn() -> void:
	_consumed = false
	_mesh.visible = true
	_collision.disabled = false
