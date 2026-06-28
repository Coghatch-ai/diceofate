# entities/boss/boss_visual.gd — Boss color-phase visual: material swap + tell tween + tinted burst.
# Connects to Boss.color_changed and Boss.died; owns no combat logic.
class_name BossVisual
extends Node

const _TELL_SCALE_MULT: float = 1.25
const _TELL_DURATION: float = 0.12
const _EMISSION_SPIKE: float = 4.0
const _EMISSION_SETTLE: float = 1.2

## NodePath to the body mesh root (Node3D with a MeshInstance3D child named "Body").
## Typed Node3D exports do not resolve in hand-authored .tscn; use NodePath resolved in _ready().
@export var mesh_root_path: NodePath = ^""
## Scene spawned as tinted death burst on boss death (VfxOneShotTinted).
@export var burst_scene: PackedScene

var _mesh_root: Node3D
var _body_mat: StandardMaterial3D
var _last_emission: Color = Color.WHITE
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	if mesh_root_path.is_empty():
		push_warning("BossVisual: mesh_root_path not set — wire via Inspector")
		return
	_mesh_root = get_node(mesh_root_path) as Node3D
	if _mesh_root == null:
		push_warning("BossVisual: mesh_root_path does not point to a Node3D")
		return
	_setup_material()


func _setup_material() -> void:
	var body: MeshInstance3D = _mesh_root.find_child("Body", true, false) as MeshInstance3D
	if body == null:
		push_warning("BossVisual: no MeshInstance3D named 'Body' under mesh_root")
		return
	var src: Material = body.get_active_material(0)
	if src == null:
		push_warning("BossVisual: Body has no material")
		return
	# Make unique so we never mutate a shared resource.
	var unique_mat: StandardMaterial3D = src.duplicate() as StandardMaterial3D
	body.set_surface_override_material(0, unique_mat)
	_body_mat = unique_mat
	_body_mat.emission_enabled = true
	_base_scale = _mesh_root.scale


## Connected to Boss.color_changed signal via .tscn [connection].
func on_color_changed(color_index: int, albedo: Color, emission: Color) -> void:
	_last_emission = emission
	if _body_mat == null:
		return
	_body_mat.albedo_color = albedo
	_body_mat.emission = emission
	_body_mat.emission_energy_multiplier = _EMISSION_SETTLE
	if color_index == 0:
		# Phase 0 on _ready — apply color immediately, no tell animation.
		return
	_run_tell_tween(albedo, emission)


func _run_tell_tween(albedo: Color, emission: Color) -> void:
	if _body_mat == null or _mesh_root == null:
		return
	if not _mesh_root.is_inside_tree():
		return
	# White flash + scale pop, then settle to phase color.
	_body_mat.albedo_color = Color.WHITE
	_body_mat.emission = Color.WHITE
	_body_mat.emission_energy_multiplier = _EMISSION_SPIKE

	var tw: Tween = _mesh_root.create_tween().set_parallel(true)
	tw.tween_property(_mesh_root, "scale", _base_scale * _TELL_SCALE_MULT, _TELL_DURATION)
	tw.set_parallel(false)
	tw.tween_property(_mesh_root, "scale", _base_scale, _TELL_DURATION)
	tw.tween_property(_body_mat, "albedo_color", albedo, _TELL_DURATION * 2.0)
	tw.tween_property(_body_mat, "emission", emission, _TELL_DURATION * 2.0)
	tw.tween_property(
		_body_mat, "emission_energy_multiplier", _EMISSION_SETTLE, _TELL_DURATION * 2.0
	)


## Connected to Boss.died signal via .tscn [connection]. Spawns tinted death burst.
func on_boss_died(boss: Boss) -> void:
	if burst_scene == null:
		return
	var scene_root: Node = boss.get_tree().current_scene if boss.is_inside_tree() else null
	if scene_root == null:
		return
	var burst: Node3D = burst_scene.instantiate() as Node3D
	scene_root.add_child(burst)
	burst.global_position = boss.global_position
	if burst.has_method("set_tint"):
		# SEAM: duck-typed set_tint(Color) — VfxOneShotTinted seam.
		@warning_ignore("unsafe_method_access")
		burst.set_tint(_last_emission)
