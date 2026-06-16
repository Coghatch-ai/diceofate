# entities/enemy/enemy_tank.gd — Tank tint: applies ENEMY_TANK_MID to all mesh parts on ready.
# No behaviour logic — all FSM/movement reused from enemy.gd via inherited scene.
extends Enemy

const ART_STYLE := preload("res://tools/art_style.gd")


func _ready() -> void:
	super._ready()
	_apply_tank_tint()


func _apply_tank_tint() -> void:
	var mesh_root: Node3D = $Mesh
	for child: Node in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var tint_mat := StandardMaterial3D.new()
			tint_mat.albedo_color = ART_STYLE.ENEMY_TANK_MID
			mi.set_surface_override_material(0, tint_mat)
