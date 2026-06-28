# entities/encounter/room_controller.gd — scripted room-progression driver.
# Handles spawning, scoring, and level advancement via hand-placed encounter data.
# New rooms = new RoomEncounter .tres, no new code.
#
# ── RunController signal contract ─────────────────────────────────────────────
# RoomController is the sole run-controller. Any future controller must honour
# this exact signal shape so main.gd wires one branch unconditionally.
#
#   score_changed(total: int)
#       Emitted whenever the run score changes (kill award or complete_run bonus).
#       main.gd → ArenaHud.set_score(total).
#
#   active_changed(count: int)
#       Emitted whenever the live enemy count changes (spawn or death).
#       main.gd → ArenaHud.set_active(count).
#
#   run_lost(score: int)
#       Emitted when the player dies mid-run. Payload = final score.
#       main.gd → _on_run_ended(score, false) → show lose screen.
#
#   advance_level(score: int)
#       Emitted when all encounters are cleared (or complete_run() is called by
#       a boss outside the encounter array). Payload = final score.
#       main.gd → _on_advance_level(score) → carry RunStateData → show win screen.
#
#   room_cleared(id: StringName)
#       Emitted per-room when that room's enemies are wiped. id = RoomEncounter.id.
#       Consumed by levels that want per-room events (doors, hints); main.gd ignores.
#
#   hint_changed(text: String)
#       Emitted when an encounter with a non-empty hint_text arms.
#       main.gd → ArenaHud.set_hint(text).
# ──────────────────────────────────────────────────────────────────────────────
class_name RoomController
extends Node

signal score_changed(total: int)
signal active_changed(count: int)
signal run_lost(score: int)
signal advance_level(score: int)
signal hint_changed(text: String)
signal room_cleared(id: StringName)
## Emitted whenever a room's last enemy dies, regardless of clear_advances.
## Use this (not room_cleared) to trigger boss spawns when the boss room has
## clear_advances = false and must not fire advance_level itself.
signal encounter_cleared(id: StringName)

## Generic enemy scene (root must be Enemy).
@export var enemy_scene: PackedScene
## Ordered encounter data; index matches room_trigger_paths / door_paths.
@export var encounters: Array[RoomEncounter] = []
## One Area3D trip-wire per room (player enters → arm that room's encounter).
@export var room_trigger_paths: Array[NodePath] = []
## One door node per room (StaticBody3D: hide mesh + disable collider on open).
@export var door_paths: Array[NodePath] = []
## All Marker3D spawn points in the level; resolved by node name at _ready().
@export var spawn_marker_paths: Array[NodePath] = []
## Damage dealt on enemy contact.
@export_range(1, 100, 1) var touch_damage: int = 25
## Minimum distance (metres) between the player and any spawn position.
## If a chosen marker is closer than this, the spawn is relocated to the
## room-local marker farthest from the player so no enemy ever spawns on top.
## The fallback never crosses to another room's markers.
## Set to 0.0 to disable the guard (legacy / test scenarios only).
@export_range(0.0, 20.0, 0.5) var min_spawn_clearance: float = 4.5
## When true: all encounters spawn immediately on _ready (no trigger entry needed).
## Doors still open room-by-room as each room's enemies are cleared.
@export var spawn_all_on_load: bool = false

var _score: int = 0
var _run_over: bool = false
## Per-room live enemy lists; index = encounter index.
var _room_enemies: Array[Array] = []
## Marker3D registry: node-name StringName → Marker3D.
var _marker_registry: Dictionary = {}
## Triggers resolved to Area3D; index = encounter index.
var _triggers: Array[Area3D] = []
## Doors resolved to StaticBody3D; index = encounter index.
var _doors: Array[StaticBody3D] = []


func _ready() -> void:
	# Build marker registry keyed by node name.
	for np: NodePath in spawn_marker_paths:
		var node: Node = get_node(np)
		if node is Marker3D:
			var m: Marker3D = node as Marker3D
			_marker_registry[StringName(m.name)] = m
		else:
			push_warning("RoomController: spawn marker '%s' not Marker3D" % np)

	# Resolve triggers.
	for np: NodePath in room_trigger_paths:
		var node: Node = get_node(np)
		if node is Area3D:
			_triggers.append(node as Area3D)
		else:
			push_warning("RoomController: trigger '%s' not Area3D" % np)

	# Resolve doors. Empty NodePath = no door for that room (append null placeholder).
	for np: NodePath in door_paths:
		if np.is_empty():
			_doors.append(null)
			continue
		var node: Node = get_node(np)
		if node is StaticBody3D:
			_doors.append(node as StaticBody3D)
		else:
			push_warning("RoomController: door '%s' not StaticBody3D" % np)

	# Pre-size per-room enemy lists.
	for i: int in range(encounters.size()):
		_room_enemies.append([])

	# Validate parallel arrays.
	if encounters.size() != room_trigger_paths.size():
		push_warning(
			(
				"RoomController: encounters(%d) != room_trigger_paths(%d)"
				% [encounters.size(), room_trigger_paths.size()]
			)
		)

	if spawn_all_on_load:
		# Arm every encounter on the first deferred call so the parent tree is
		# fully settled before add_child(enemy) runs — calling add_child during
		# _ready while the parent is still setting up children fails (engine guard).
		_spawn_all_deferred.call_deferred()
	else:
		# Wire each trigger (one-shot arm).
		for i: int in range(mini(_triggers.size(), encounters.size())):
			var trigger: Area3D = _triggers[i]
			var idx: int = i
			trigger.body_entered.connect(
				func(body: Node3D) -> void: _on_trigger_entered(body, idx), CONNECT_ONE_SHOT
			)

	_wire_player_health()
	score_changed.emit(_score)
	active_changed.emit(0)


func _spawn_all_deferred() -> void:
	for i: int in range(encounters.size()):
		_arm_encounter(i)


func _wire_player_health() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not player.has_method("get_health_comp"):
		return
	# SEAM: duck-typed get_health_comp(); returns HealthComponent by contract.
	@warning_ignore("unsafe_method_access")
	@warning_ignore("unsafe_cast")
	var hc: HealthComponent = player.get_health_comp() as HealthComponent
	if hc == null:
		return
	if not hc.died.is_connected(_on_player_died):
		hc.died.connect(_on_player_died)


func _on_trigger_entered(body: Node3D, encounter_idx: int) -> void:
	# Only arm when the player walks in.
	if not body.is_in_group("player"):
		return
	_arm_encounter(encounter_idx)


func _arm_encounter(idx: int) -> void:
	if idx < 0 or idx >= encounters.size():
		return
	var enc: RoomEncounter = encounters[idx]
	if enc == null:
		return

	if not enc.hint_text.is_empty():
		hint_changed.emit(enc.hint_text)

	# Lock the door for this room (index-matched).
	if idx < _doors.size():
		_set_door_open(_doors[idx], false)

	# Collect this room's Marker3D nodes (used for room-local clearance fallback).
	var room_markers: Array[Marker3D] = _collect_room_markers(enc)

	# Spawn each listed enemy at its marker.
	for spawn: RoomSpawn in enc.spawns:
		_spawn_enemy(spawn, idx, room_markers)

	active_changed.emit(_count_active())


## Build the list of Marker3D nodes referenced by this encounter's spawns.
## Used to constrain clearance fallback to the same room.
func _collect_room_markers(enc: RoomEncounter) -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	for spawn: RoomSpawn in enc.spawns:
		if spawn == null:
			continue
		if spawn.spawn_marker_id == &"":
			continue
		if not _marker_registry.has(spawn.spawn_marker_id):
			continue
		# SEAM: registry values are Marker3D by construction (_ready guard).
		@warning_ignore("unsafe_cast")
		var m: Marker3D = _marker_registry[spawn.spawn_marker_id] as Marker3D
		if m != null and not markers.has(m):
			markers.append(m)
	return markers


func _spawn_enemy(spawn: RoomSpawn, room_idx: int, room_markers: Array[Marker3D]) -> void:
	if enemy_scene == null:
		push_warning("RoomController: enemy_scene not assigned — cannot spawn")
		return
	if spawn == null:
		return

	var pos: Vector3 = Vector3.ZERO
	if spawn.spawn_marker_id != &"" and _marker_registry.has(spawn.spawn_marker_id):
		# SEAM: registry value is Marker3D by construction.
		@warning_ignore("unsafe_cast")
		var m: Marker3D = _marker_registry[spawn.spawn_marker_id] as Marker3D
		if m != null:
			pos = m.global_position
	else:
		push_warning(
			"RoomController: marker id '%s' not found — spawning at origin" % spawn.spawn_marker_id
		)

	# Spawn clearance: if chosen position is too close to the player, relocate
	# to the farthest marker within THIS ROOM ONLY.  Never crosses room boundaries.
	if min_spawn_clearance > 0.0:
		pos = _apply_clearance(pos, room_markers)

	var inst: Node = enemy_scene.instantiate()
	if not inst is Enemy:
		push_error("RoomController: enemy_scene root is not Enemy")
		inst.queue_free()
		return
	var enemy: Enemy = inst as Enemy
	if spawn.archetype != null:
		enemy.archetype = spawn.archetype
	enemy.collision_layer = 8
	# mask 3 = layer 1 (world) + layer 2 (player) — enemy CharacterBody3D must
	# see the player layer so move_and_slide produces physical push on contact.
	enemy.collision_mask = 3
	get_parent().add_child(enemy)
	enemy.global_position = pos + Vector3(0.0, 0.1, 0.0)

	# SEAM: Enemy.died(enemy: Enemy) — typed signal, safe direct connect.
	enemy.died.connect(_on_enemy_died.bind(room_idx))
	enemy.touched_player.connect(_on_enemy_touched_player)

	_room_enemies[room_idx].append(enemy)


## Returns a spawn position guaranteed to be at least min_spawn_clearance metres
## from the player.  If candidate_pos already satisfies clearance, returns it
## unchanged.  Otherwise returns the ROOM-LOCAL marker farthest from the player
## (never crosses to another room).  Falls back to candidate_pos when no player
## is found (headless / unit tests) or room_markers is empty.
func _apply_clearance(candidate_pos: Vector3, room_markers: Array[Marker3D]) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return candidate_pos
	var player_pos: Vector3 = player.global_position
	if candidate_pos.distance_to(player_pos) >= min_spawn_clearance:
		return candidate_pos
	if room_markers.is_empty():
		return candidate_pos
	# Candidate too close — pick the farthest marker within THIS ROOM ONLY.
	var best_pos: Vector3 = candidate_pos
	var best_dist: float = -1.0
	for m: Marker3D in room_markers:
		if m == null:
			continue
		var d: float = m.global_position.distance_to(player_pos)
		if d > best_dist:
			best_dist = d
			best_pos = m.global_position
	return best_pos


func _on_enemy_died(enemy: Enemy, room_idx: int) -> void:
	if room_idx >= 0 and room_idx < _room_enemies.size():
		_room_enemies[room_idx].erase(enemy)

	active_changed.emit(_count_active())

	if _run_over:
		return

	# Award score for this kill.
	_score += enemy.score_value
	score_changed.emit(_score)

	# Check if this room is now cleared.
	if room_idx >= 0 and room_idx < encounters.size():
		var enc: RoomEncounter = encounters[room_idx]
		if enc != null and _room_enemies[room_idx].is_empty():
			# Always signal encounter_cleared so boss-room scripts can react
			# even when clear_advances = false (boss win handled by complete_run).
			encounter_cleared.emit(enc.id)
		if enc != null and enc.clear_advances and _room_enemies[room_idx].is_empty():
			_on_room_cleared(room_idx)


func _on_room_cleared(idx: int) -> void:
	var enc: RoomEncounter = encounters[idx]
	if enc == null:
		return
	room_cleared.emit(enc.id)

	# Open door for this room.
	if idx < _doors.size():
		_set_door_open(_doors[idx], true)

	# If this was the last room, emit advance_level.
	var all_done: bool = true
	for i: int in range(_room_enemies.size()):
		if not _room_enemies[i].is_empty():
			all_done = false
			break
	if all_done and idx == encounters.size() - 1:
		_run_over = true
		advance_level.emit(_score)


func _set_door_open(door: StaticBody3D, open: bool) -> void:
	if door == null:
		return
	# Hide all MeshInstance3D children.
	for child: Node in door.get_children():
		if child is MeshInstance3D:
			# SEAM: child is MeshInstance3D by guard above.
			@warning_ignore("unsafe_cast")
			(child as MeshInstance3D).visible = not open
	# Disable collision shapes deferred (safe during physics).
	for child: Node in door.get_children():
		if child is CollisionShape3D:
			# SEAM: set_deferred on CollisionShape3D.disabled — safe during physics step.
			@warning_ignore("unsafe_cast")
			(child as CollisionShape3D).set_deferred(&"disabled", open)
	door.visible = not open


func _on_enemy_touched_player(_enemy: Enemy) -> void:
	if _run_over:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	if not player.has_method("apply_damage"):
		return
	# SEAM: duck-typed apply_damage — any node with apply_damage(int) accepted.
	@warning_ignore("unsafe_method_access")
	player.apply_damage(touch_damage)


func _on_player_died() -> void:
	if _run_over:
		return
	_run_over = true
	for room: Array in _room_enemies:
		for e: Enemy in room as Array[Enemy]:
			if is_instance_valid(e):
				e.queue_free()
		room.clear()
	active_changed.emit(0)
	run_lost.emit(_score)


func _count_active() -> int:
	var total: int = 0
	for room: Array in _room_enemies:
		total += room.size()
	return total


## Called by the level script when a boss outside the encounter array dies.
## Finalises the run and fires advance_level so main.gd can swap the level.
func complete_run(bonus_score: int) -> void:
	if _run_over:
		return
	_run_over = true
	_score += bonus_score
	score_changed.emit(_score)
	advance_level.emit(_score)
