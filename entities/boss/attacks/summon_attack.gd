# entities/boss/attacks/summon_attack.gd — spawn a small wave of enemy adds around the boss.
# Reuses the existing Enemy scene + EnemyArchetype system; no parallel spawner.
# All tunables are @export fields on this component — data-driven via the .tres.
class_name SummonAttack
extends BossAttack

## Enemy scene to instance. Must be the standard enemy.tscn (root = Enemy).
@export var enemy_scene: PackedScene
## Archetype applied to each spawned add. Null = bare enemy defaults (grunt stats).
@export var add_archetype: EnemyArchetype
## Number of adds to spawn per activation (before max_concurrent_adds cap).
@export_range(1, 8, 1) var spawn_count: int = 2
## Horizontal radius around the boss to scatter spawn positions (metres).
@export_range(1.0, 12.0, 0.5) var spawn_radius: float = 3.0
## Minimum time between summon activations (seconds). Boss cadence already gates
## this via the attack-loop; this is an additional per-component floor so a fast
## cadence config cannot chain summons back-to-back.
@export_range(1.0, 30.0, 0.5) var cooldown: float = 8.0
## Maximum live adds spawned by this component at once. New summon skipped if
## current live-add count >= this cap. Prevents flooding the arena.
@export_range(1, 12, 1) var max_concurrent_adds: int = 4
## Contact damage dealt to the player when a summoned add touches them.
## Mirrors RoomController.touch_damage so adds threaten the player identically.
@export_range(1, 100, 1) var touch_damage: int = 25

# Injected Boss ref (typed — calls down only).
var _boss: Boss = null
# Clock since the last successful summon (seconds). Initialized so the first
# activation is never blocked by cooldown (0 means "ready from the start").
var _cooldown_accum: float = 0.0
# Live adds spawned by this component; entries erased on death signal.
var _live_adds: Array[Enemy] = []
# Tracks random angle offsets so each summon scatters adds in a new pattern.
# Re-seeded per activation — no state carried between activations.
var _summon_angles: Array[float] = []


func bind(boss: Node) -> void:
	_boss = boss as Boss


func telegraph_duration() -> float:
	if _boss == null or _boss.data == null:
		return 0.8
	return _boss.data.telegraph_duration


func start() -> void:
	# Purge freed entries from the live-adds list (guards against leaked references).
	_prune_dead_adds()

	# Cooldown guard: skip summon if cooldown hasn't elapsed since last successful one.
	# Uses INF as the initial sentinel so the very first activation is always allowed.
	if _cooldown_accum < cooldown:
		return

	# Cap guard: skip if already at max concurrent adds.
	if _live_adds.size() >= max_concurrent_adds:
		return

	# Compute how many adds to actually spawn (respect both the cap and spawn_count).
	var slots_remaining: int = max_concurrent_adds - _live_adds.size()
	var to_spawn: int = mini(spawn_count, slots_remaining)

	if to_spawn <= 0:
		return

	if enemy_scene == null:
		return

	# Reset cooldown clock on a successful summon.
	_cooldown_accum = 0.0

	# Build evenly-spread spawn angles for this wave.
	_summon_angles.clear()
	var angle_step: float = TAU / float(to_spawn)
	# Random start angle so each summon looks different.
	var start_angle: float = randf() * TAU
	for i: int in range(to_spawn):
		_summon_angles.append(start_angle + angle_step * float(i))

	var scene_root: Node = _boss.get_tree().current_scene if _boss != null else null
	if scene_root == null:
		return

	var boss_pos: Vector3 = _boss.global_position if _boss != null else Vector3.ZERO

	for i: int in range(to_spawn):
		var angle: float = _summon_angles[i]
		var offset: Vector3 = Vector3(cos(angle) * spawn_radius, 0.0, sin(angle) * spawn_radius)
		var spawn_pos: Vector3 = boss_pos + offset

		var inst: Node = enemy_scene.instantiate()
		if not inst is Enemy:
			inst.queue_free()
			continue

		var enemy: Enemy = inst as Enemy
		# Apply archetype before add_child so _ready() seeds from it.
		if add_archetype != null:
			enemy.archetype = add_archetype
		enemy.collision_layer = 8
		enemy.collision_mask = 1
		scene_root.add_child(enemy)
		# Position after add_child so global_position is valid.
		enemy.global_position = spawn_pos + Vector3(0.0, 0.1, 0.0)

		# Track this add; erase from list when it dies.
		_live_adds.append(enemy)
		# SEAM: Enemy.died(enemy: Enemy) — signal already carries the enemy as arg;
		# no .bind() needed (would pass 2 args to a 1-arg handler → runtime error).
		enemy.died.connect(_on_add_died)
		# Wire contact damage: adds must threaten the player just like room-spawned enemies.
		# Mirrors room_controller.gd:250 — connect touched_player → apply_damage on the player.
		enemy.touched_player.connect(_on_add_touched_player)


func tick(_delta: float) -> bool:
	# Summon is fire-once in start(); tick just signals "done immediately".
	return true


func recover_duration() -> float:
	if _boss == null or _boss.data == null:
		return 1.0
	return _boss.data.recover_duration


func _physics_process(delta: float) -> void:
	# Accumulate cooldown clock each frame so we know when the component is ready again.
	# Cap at cooldown + 1 to avoid floating-point overflow on a long idle.
	_cooldown_accum = minf(_cooldown_accum + delta, cooldown + 1.0)


func _on_add_died(enemy: Enemy) -> void:
	_live_adds.erase(enemy)


func _on_add_touched_player(_enemy: Enemy) -> void:
	var player: Node3D = (
		_boss.get_tree().get_first_node_in_group("player") as Node3D if _boss != null else null
	)
	if player == null:
		return
	if not player.has_method("apply_damage"):
		return
	# SEAM: duck-typed apply_damage — mirrors room_controller._on_enemy_touched_player.
	@warning_ignore("unsafe_method_access")
	player.apply_damage(touch_damage)


func _prune_dead_adds() -> void:
	var live: Array[Enemy] = []
	for e: Enemy in _live_adds:
		if is_instance_valid(e):
			live.append(e)
	_live_adds = live
