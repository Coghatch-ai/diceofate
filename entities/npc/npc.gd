# entities/npc/npc.gd — rescuable civilian NPC; rewards or penalises via WaveManager.
class_name Npc
extends StaticBody3D

## Emitted just before queue_free() so listeners can react.
signal died(npc: Npc)

## WaveManager injected by the level root in _ready() (same DI pattern as FiringYard).
@export var wave_manager: WaveManager

var _dead: bool = false

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _rescue_area: Area3D = $RescueArea
@onready var _rescue_timer: Timer = $RescueTimer


func _ready() -> void:
	_rescue_area.body_entered.connect(_on_RescueArea_body_entered)
	_rescue_area.body_exited.connect(_on_RescueArea_body_exited)
	_rescue_timer.timeout.connect(_on_RescueTimer_timeout)


# ── Hit seam (duck-typed; called by projectile via godot-travelling-projectile-3d) ───


## Called by the projectile via duck-typed on_hit(). Costs the player one life.
func on_hit() -> void:
	if _dead:
		return
	_dead = true
	_rescue_timer.stop()
	if wave_manager != null:
		wave_manager.lose_life()
	_flash(Color(0.80, 0.10, 0.10))
	died.emit(self)
	queue_free()


# ── Rescue flow ───────────────────────────────────────────────────────────────────────


func _on_RescueArea_body_entered(body: Node3D) -> void:
	if _dead:
		return
	if body.is_in_group("player"):
		_rescue_timer.start()


func _on_RescueArea_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_rescue_timer.stop()


func _on_RescueTimer_timeout() -> void:
	if _dead:
		return
	_dead = true
	if wave_manager != null:
		wave_manager.add_life()
	_flash(Color(0.18, 0.72, 0.28))
	died.emit(self)
	queue_free()


# ── Flash helper ──────────────────────────────────────────────────────────────────────


func _flash(color: Color) -> void:
	# SEAM: duck-typed surface_material_override — StandardMaterial3D cast needed for emission.
	@warning_ignore("unsafe_method_access")
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	var flash_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	flash_mat.emission_enabled = true
	flash_mat.emission = color
	flash_mat.emission_energy_multiplier = 3.0
	_mesh.set_surface_override_material(0, flash_mat)
