# entities/enemy/enemy_runner.gd — Runner tint: applies ENEMY_RUNNER_MID to all mesh parts on ready.
# No behaviour logic — all FSM/movement reused from enemy.gd via inherited scene.
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")


func _ready() -> void:
	super._ready()
	score_value = 2
	_apply_runner_tint()


func _apply_runner_tint() -> void:
	var mesh_root: Node3D = $Mesh
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var tint_mat := StandardMaterial3D.new()
			tint_mat.albedo_color = ART_STYLE.ENEMY_RUNNER_MID
			mi.set_surface_override_material(0, tint_mat)
