# entities/vfx/shockwave_ring.gd — MeshInstance3D scale-tween shockwave ring: expands, fades, frees.
class_name ShockwaveRing
extends Node3D

## Scale the ring reaches at end of tween (start = 1.0).
@export var end_scale: float = 6.0
## Duration of the expand + fade tween in seconds.
@export var duration: float = 0.35


func _ready() -> void:
	var ring: MeshInstance3D = $Ring
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * end_scale, duration)
	tw.tween_property(ring, "transparency", 1.0, duration)
	tw.chain().tween_callback(queue_free)
