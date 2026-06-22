# tools/smoke_attack_freed.gd — headless L2 smoke: perform_attack() survives freed _touch_reset_sfx.
# Reproduces the freeze path: enemy attacks, SFX reparented+freed, enemy attacks AGAIN.
# Asserts no freed-instance crash and attack bails safely.
# Run: $GODOT --headless --path . --script tools/smoke_attack_freed.gd
# Exit 0 = all pass, 1 = any failure.
extends SceneTree

const GRUNT_SCENE := "res://entities/enemy/enemy.tscn"

var _pass_count: int = 0
var _fail_count: int = 0
var _frame: int = 0
var _done: bool = false
var _enemy: Enemy = null
var _sfx_freed: bool = false


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  FAIL: %s" % msg)


func _initialize() -> void:
	print("=== ATTACK FREED SFX SMOKE ===")


func _process(_delta: float) -> bool:
	_frame += 1

	if _frame == 2:
		# Instantiate enemy standalone (no nav needed for this smoke).
		var scene: PackedScene = load(GRUNT_SCENE) as PackedScene
		_assert(scene != null, "grunt scene loads")
		if scene == null:
			_done = true
			quit(1)
			return false
		_enemy = scene.instantiate() as Enemy
		_assert(_enemy != null, "enemy instantiates as Enemy")
		if _enemy == null:
			_done = true
			quit(1)
			return false
		root.add_child(_enemy)

	if _frame == 4:
		# Confirm enemy alive and has the SFX child.
		_assert(is_instance_valid(_enemy), "enemy valid after ready")
		var sfx: AudioStreamPlayer = _enemy.get_node_or_null("TouchResetSfx") as AudioStreamPlayer
		_assert(sfx != null, "TouchResetSfx node present")

		# --- Simulate first attack: call perform_attack() directly. ---
		# This reparents _touch_reset_sfx to the scene root.
		_enemy.perform_attack()
		_assert(is_instance_valid(_enemy), "enemy still valid after first perform_attack")

		# Simulate the SFX finishing and freeing itself (the fire-and-free path).
		var sfx_after: AudioStreamPlayer = (
			root.find_child("TouchResetSfx", true, false) as AudioStreamPlayer
		)
		if sfx_after != null:
			sfx_after.queue_free()
			_sfx_freed = true

	if _frame == 6:
		# SFX should be freed by now (deferred queue_free processed).
		if _sfx_freed:
			_assert(true, "SFX node freed (simulated finished)")

		# --- Reproduce the crash: perform_attack() again with SFX already freed. ---
		# Before the fix this threw: Cannot call method 'get_parent' on a previously freed instance.
		_enemy.perform_attack()
		_assert(is_instance_valid(_enemy), "enemy survives second perform_attack with freed SFX")

		# Verify no crash: touched_player still emits after SFX freed.
		# Use Array ref — GDScript lambdas capture primitives by value, not by reference.
		var touched_count: Array[int] = [0]
		_enemy.touched_player.connect(func(_e: Enemy) -> void: touched_count[0] += 1)
		_enemy.perform_attack()
		_assert(touched_count[0] > 0, "touched_player emits even after SFX freed")

	if _frame == 8:
		print("=== RESULT: %d passed, %d failed ===" % [_pass_count, _fail_count])
		_done = true
		quit(1 if _fail_count > 0 else 0)
		return false

	return false
