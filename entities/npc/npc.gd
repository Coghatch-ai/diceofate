# entities/npc/npc.gd — rescuable civilian NPC; rewards or penalises via WaveManager.
class_name Npc
extends StaticBody3D

## Emitted just before queue_free() so listeners can react (both outcomes).
signal died(npc: Npc)
## Emitted on the saved (+1 life) branch only — used by NpcVfx for the halo effect.
signal rescued(npc: Npc)

## WaveManager injected by the level root in _ready() (same DI pattern as FiringYard).
## Kept for injection but no longer used for lives — NPC death/rescue route HP directly.
@export var wave_manager: WaveManager
## HP damage dealt to the player when this NPC is killed. Default matches touch_damage (25).
@export_range(1, 100, 1) var kill_penalty: int = 25
## HP healed to the player when this NPC is rescued.
@export_range(1, 200, 1) var rescue_heal: int = 40

var _dead: bool = false

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _rescue_area: Area3D = $RescueArea
@onready var _rescue_timer: Timer = $RescueTimer
@onready var _health_comp: HealthComponent = $HealthComponent


func _ready() -> void:
	_health_comp.max_health = 1
	_health_comp.reset()
	_health_comp.died.connect(_on_health_comp_died)
	_rescue_area.body_entered.connect(_on_RescueArea_body_entered)
	_rescue_area.body_exited.connect(_on_RescueArea_body_exited)
	_rescue_timer.timeout.connect(_on_RescueTimer_timeout)


# ── Hit seam (duck-typed; called by projectile via godot-travelling-projectile-3d) ───


## Called by the projectile via duck-typed on_hit() — aliases apply_damage(1).
func on_hit() -> void:
	apply_damage(1)


## Apply damage. Delegates to HealthComponent; death handled in _on_health_comp_died.
## Accepts optional type (slice 3); defaults to PHYSICAL for backward-compat.
func apply_damage(amount: int, type: DamageType.Kind = DamageType.Kind.PHYSICAL) -> void:
	if _dead:
		return
	var shield: ShieldComponent = get_node_or_null("ShieldComponent") as ShieldComponent
	var overflow: int = amount
	if shield != null:
		overflow = shield.absorb(amount)
	if overflow > 0:
		_health_comp.apply_damage(overflow, type)


func _on_health_comp_died() -> void:
	if _dead:
		return
	_dead = true
	_rescue_timer.stop()
	_damage_player(kill_penalty)
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
	_heal_player(rescue_heal)
	_flash(Color(0.18, 0.72, 0.28))
	rescued.emit(self)
	died.emit(self)
	queue_free()


func _damage_player(amount: int) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("apply_damage"):
		return
	# SEAM: duck-typed apply_damage — any node with apply_damage(int) accepted.
	@warning_ignore("unsafe_method_access")
	player.apply_damage(amount)


func _heal_player(amount: int) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("get_health_comp"):
		return
	# SEAM: duck-typed get_health_comp — Player exposes this accessor.
	# Return is Variant from duck call; cast to HealthComponent is safe by contract.
	@warning_ignore("unsafe_method_access")
	@warning_ignore("unsafe_cast")
	var hc: HealthComponent = player.get_health_comp() as HealthComponent
	if hc != null:
		hc.heal(amount)


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
