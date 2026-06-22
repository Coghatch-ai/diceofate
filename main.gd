# main.gd — persistent shell: loads and swaps level scenes under %LevelHost.
extends Node

@export_file("*.tscn") var initial_level: String = "res://levels/firing_yard.tscn"

var current_level: Node = null
var _levels: Array[String] = [
	"res://levels/firing_yard.tscn",
	"res://levels/ruined_warehouse.tscn",
	"res://levels/blast_court.tscn",
]
var _level_index: int = 0
var _result_showing: bool = false

@onready var _level_host: Node = %LevelHost
@onready var _crosshair: Crosshair = %Crosshair
@onready var _arena_hud: ArenaHud = %ArenaHud


func _ready() -> void:
	# Must process while paused so _input handles the restart action on the end screen.
	process_mode = PROCESS_MODE_ALWAYS
	if _levels.is_empty() or initial_level.is_empty():
		return
	_level_index = _levels.find(initial_level)
	if _level_index == -1:
		_level_index = 0
	load_level(_levels[_level_index])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_level"):
		if _levels.is_empty():
			return
		_level_index = (_level_index + 1) % _levels.size()
		load_level(_levels[_level_index])

	if _result_showing and event.is_action_pressed("restart"):
		get_tree().paused = false
		_result_showing = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_arena_hud.hide_result()
		load_level(_levels[_level_index])


func load_level(path: String) -> void:
	if current_level != null:
		# free(), not queue_free(): one frame of two live levels conflicts camera/WorldEnvironment
		current_level.free()
		current_level = null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("main: failed to load level scene: %s" % path)
		return
	current_level = packed.instantiate()
	_level_host.add_child(current_level)

	# Wire the FPS player's eye-camera and attach the outline PostProcessQuad to it.
	var player := current_level.find_child("Player") as Player
	if player != null:
		var camera := player.find_child("Camera3D", true, false) as Camera3D
		if camera != null:
			camera.make_current()
			_attach_post_process_quad(camera)
		player.set_crosshair(_crosshair)
		player.set_ammo_hud(_arena_hud)

	# Wire WaveManager signals to the persistent HUD (if the level has one).
	# Guard score reset: when RunStateData.active is in flight the carried score_changed emit
	# from _seed_start will update the HUD — zeroing here would flash 0 before it fires.
	if not RunStateData.active:
		_arena_hud.set_score(0)
	_arena_hud.set_active(0)
	var wave_manager := current_level.find_child("WaveManager") as WaveManager
	if wave_manager != null:
		wave_manager.score_changed.connect(_arena_hud.set_score)
		wave_manager.active_changed.connect(_arena_hud.set_active)
		wave_manager.run_lost.connect(_on_run_ended.bind(false))
		wave_manager.advance_level.connect(_on_advance_level)
		# Inject wave_manager into the level so fall/hazard handlers can call apply_damage().
		# SEAM: duck-typed set — level scripts (FiringYard/RuinedWarehouse) share the
		# wave_manager export but have no common base class.
		@warning_ignore("unsafe_property_access")
		current_level.wave_manager = wave_manager

	# Wire player HealthComponent.health_changed → HUD HP bar.
	if player != null:
		var hc: HealthComponent = player.get_health_comp()
		hc.health_changed.connect(_arena_hud.set_health)
		_arena_hud.set_health(hc.max_health, hc.max_health)


func _attach_post_process_quad(camera: Camera3D) -> void:
	# Remove any quad left from a previous level (camera node is recreated each swap).
	var existing := camera.get_node_or_null("PostProcessQuad")
	if existing != null:
		existing.queue_free()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/post/post_process.gdshader") as Shader
	mat.set_shader_parameter("depth_threshold", 0.5)
	mat.set_shader_parameter("normal_threshold", 0.4)
	var mesh := QuadMesh.new()
	mesh.flip_faces = true
	mesh.size = Vector2(2.0, 2.0)
	var quad := MeshInstance3D.new()
	quad.name = "PostProcessQuad"
	quad.mesh = mesh
	quad.material_override = mat
	quad.extra_cull_margin = 16384.0
	camera.add_child(quad)


func _on_advance_level(score: int) -> void:
	RunStateData.active = true
	RunStateData.score = score
	_level_index = (_level_index + 1) % _levels.size()
	# Deferred: signal may arrive from inside an enemy's own physics/attack callback.
	# Calling load_level() synchronously frees the level (and the enemy) while still
	# executing inside perform_attack() — create_tween() on a freed instance crashes.
	load_level.call_deferred(_levels[_level_index])


func _on_run_ended(score: int, won: bool) -> void:
	_result_showing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not won:
		_play_death_sfx()
	get_tree().paused = true
	_arena_hud.show_result(won, score)


## Play a one-shot death SFX before the tree pauses.
## AudioStreamPlayer lives on Main (PROCESS_MODE_ALWAYS) so it survives the pause.
## PLACEHOLDER: uses enemy_death.wav — swap for a dedicated player-death sound later.
func _play_death_sfx() -> void:
	var stream := load("res://assets/audio/enemy_death.wav") as AudioStream
	if stream == null:
		push_warning("main: death SFX asset not found")
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.process_mode = PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
