# tools/lib/enemy/enemy_flash_helper.gd — static helpers: hit spark spawn + hitstop.
class_name EnemyFlashHelper


## Spawn a one-shot hit spark at world_pos parented under the scene root.
## Falls back to default_scene when archetype provides no override.
static func spawn_hit_spark(scene_root: Node, spark_scene: PackedScene, world_pos: Vector3) -> void:
	if scene_root == null:
		return
	var fx: Node3D = spark_scene.instantiate() as Node3D
	scene_root.add_child(fx)
	fx.global_position = world_pos


## Brief Engine.time_scale dip for hit-weight, restored after duration seconds.
## duration is in real-world seconds (unaffected by the time_scale dip itself).
static func apply_hitstop(host: Node, duration: float) -> void:
	Engine.time_scale = 0.05
	var tw: Tween = host.create_tween()
	tw.tween_interval(duration * 0.05)
	tw.tween_callback(func() -> void: Engine.time_scale = 1.0)
