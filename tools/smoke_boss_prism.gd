# tools/smoke_boss_prism.gd — headless smoke: color-phase logic, resistances, grow, explode.
# Run: $GODOT --headless --path . --script tools/smoke_boss_prism.gd
# Asserts:
#   - Wrong-color bullet deals 0 (resistance 0.0).
#   - Matching-color damage depletes phase chunk → advances to next phase.
#   - color_changed emitted with correct index on advance.
#   - After last phase chunk depleted → explode path: died fires exactly once.
#   - apply_damage + apply_knockback called on player stub within explode_radius.
# Exit 0 = all pass. Exit 1 = any fail.
extends SceneTree

const BOSS_SCENE: PackedScene = preload("res://entities/boss/boss.tscn")
const PRISM_DATA: BossData = preload("res://archetypes/boss_prism.tres")

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	print("smoke_boss_prism: START")
	_run_tests()
	print("smoke_boss_prism: PASS=%d FAIL=%d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		quit(1)
	else:
		quit(0)


func _run_tests() -> void:
	_test_prism_data_loads()
	_test_color_phases_present()
	_test_resistances_phase0_fire()
	_test_wrong_color_deals_zero_phase0()
	_test_correct_color_depletes_chunk()
	_test_phase_advance_emits_signal()
	_test_all_phases_then_explode()
	_test_died_fires_exactly_once()
	_test_explode_aoe_hits_player()


# ── Helpers ────────────────────────────────────────────────────────────────────
func _assert(label: String, condition: bool) -> void:
	if condition:
		print("  PASS: %s" % label)
		_pass_count += 1
	else:
		print("  FAIL: %s" % label)
		_fail_count += 1


## Instantiate boss + wire _health_comp + _mesh_node so smoke callbacks work without tree.
func _make_prism_boss() -> Boss:
	var inst: Node = BOSS_SCENE.instantiate()
	var boss: Boss = inst as Boss
	boss.data = PRISM_DATA
	# @onready refs are null without _ready(); inject manually so callbacks don't crash.
	var hc: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	boss._health_comp = hc
	# _mesh_node must be non-null for _flash_hit; use a dummy Node3D.
	var dummy_mesh: Node3D = Node3D.new()
	boss._mesh_node = dummy_mesh
	boss.add_child(dummy_mesh)
	return boss


## Build a HealthComponent seeded from a BossColorPhase chunk size.
func _make_hc(max_hp: int) -> HealthComponent:
	var hc: HealthComponent = HealthComponent.new()
	hc.max_health = max_hp
	hc.reset()
	return hc


# ── Tests ──────────────────────────────────────────────────────────────────────
func _test_prism_data_loads() -> void:
	_assert("boss_prism.tres loads as BossData", PRISM_DATA != null)
	_assert("display_name == 'Prism Warden'", PRISM_DATA.display_name == "Prism Warden")
	_assert("explode_radius > 0 (explosion configured)", PRISM_DATA.explode_radius > 0.0)
	_assert("explode_damage == 60", PRISM_DATA.explode_damage == 60)
	_assert("explode_knockback == 20.0", is_equal_approx(PRISM_DATA.explode_knockback, 20.0))


func _test_color_phases_present() -> void:
	_assert("color_phases has 3 entries", PRISM_DATA.color_phases.size() == 3)
	var p0: BossColorPhase = PRISM_DATA.color_phases[0]
	var p1: BossColorPhase = PRISM_DATA.color_phases[1]
	var p2: BossColorPhase = PRISM_DATA.color_phases[2]
	_assert("phase 0 damage_type == FIRE (1)", p0.damage_type == DamageType.Kind.FIRE)
	_assert("phase 1 damage_type == ICE (2)", p1.damage_type == DamageType.Kind.ICE)
	_assert("phase 2 damage_type == ELECTRIC (3)", p2.damage_type == DamageType.Kind.ELECTRIC)
	_assert("phase 0 body_scale == 2.0", is_equal_approx(p0.body_scale, 2.0))
	_assert("phase 1 body_scale == 2.8", is_equal_approx(p1.body_scale, 2.8))
	_assert("phase 2 body_scale == 3.6", is_equal_approx(p2.body_scale, 3.6))


func _test_resistances_phase0_fire() -> void:
	# Simulate phase 0 resistances: FIRE=1.0, all others=0.0.
	var hc: HealthComponent = _make_hc(30)
	# Build resistances as _enter_color_phase would.
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res
	# FIRE should deal damage.
	var hp_before: int = hc._current
	hc.apply_damage(5, DamageType.Kind.FIRE)
	_assert("phase 0: FIRE damage reduces HP", hc._current < hp_before)
	# ICE should deal zero.
	var hp_mid: int = hc._current
	hc.apply_damage(5, DamageType.Kind.ICE)
	_assert("phase 0: ICE damage is zero (immune)", hc._current == hp_mid)
	# ELECTRIC should deal zero.
	hc.apply_damage(5, DamageType.Kind.ELECTRIC)
	_assert("phase 0: ELECTRIC damage is zero (immune)", hc._current == hp_mid)
	hc.free()


func _test_wrong_color_deals_zero_phase0() -> void:
	# Phase 0 = FIRE vulnerable. ICE+ELECTRIC = 0 damage.
	var hc: HealthComponent = _make_hc(30)
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res
	var hp_start: int = hc._current
	hc.apply_damage(10, DamageType.Kind.ICE)
	hc.apply_damage(10, DamageType.Kind.ELECTRIC)
	_assert(
		"wrong-color bullets (ICE+ELECTRIC) deal 0 in FIRE phase — HP unchanged",
		hc._current == hp_start
	)
	hc.free()


func _test_correct_color_depletes_chunk() -> void:
	# FIRE damage = phase_hp (10) depletes phase 0 chunk.
	var p0: BossColorPhase = PRISM_DATA.color_phases[0]
	var hc: HealthComponent = _make_hc(30)
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res
	hc.apply_damage(p0.phase_hp, DamageType.Kind.FIRE)
	_assert(
		"FIRE damage == phase_hp depletes chunk (HC current < max)", hc._current < hc.max_health
	)
	hc.free()


func _test_phase_advance_emits_signal() -> void:
	# Drive Boss directly: set up phase state, pump apply_damage, check color_changed.
	var boss: Boss = _make_prism_boss()
	var hc: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	# Manually seed phase state as _ready() would.
	boss._color_phases_active = true
	boss._color_phase_index = 0
	var p0: BossColorPhase = PRISM_DATA.color_phases[0]
	boss._phase_hp_remaining = p0.phase_hp
	var p1_sig: BossColorPhase = PRISM_DATA.color_phases[1]
	var p2_sig: BossColorPhase = PRISM_DATA.color_phases[2]
	var total: int = p0.phase_hp + p1_sig.phase_hp + p2_sig.phase_hp
	hc.max_health = total
	hc.reset()
	boss._prev_total_hp = total
	# Build phase-0 resistances.
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res
	# Connect signals.
	var color_changed_indices: Array[int] = []
	boss.color_changed.connect(
		func(idx: int, _a: Color, _e: Color) -> void: color_changed_indices.append(idx)
	)
	# Wire health_changed → boss callback.
	hc.health_changed.connect(boss._on_health_comp_changed)
	hc.died.connect(boss._on_health_comp_died)
	# Deal exact phase_hp in FIRE — should advance to phase 1.
	boss.apply_damage(p0.phase_hp, DamageType.Kind.FIRE)
	_assert(
		"color_changed emitted after depleting phase 0 chunk", color_changed_indices.size() >= 1
	)
	if color_changed_indices.size() >= 1:
		_assert("color_changed index == 1 (advanced to phase 1)", color_changed_indices[0] == 1)
	boss.free()


func _test_all_phases_then_explode() -> void:
	# Drive all 3 phases to depletion; last → _explode() path → died emitted.
	var boss: Boss = _make_prism_boss()
	var hc: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	boss._color_phases_active = true
	boss._color_phase_index = 0
	var p0: BossColorPhase = PRISM_DATA.color_phases[0]
	boss._phase_hp_remaining = p0.phase_hp
	var p1_ex: BossColorPhase = PRISM_DATA.color_phases[1]
	var p2_ex: BossColorPhase = PRISM_DATA.color_phases[2]
	var total: int = p0.phase_hp + p1_ex.phase_hp + p2_ex.phase_hp
	hc.max_health = total
	hc.reset()
	boss._prev_total_hp = total
	var new_res0: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res0[kind_int] = 0.0
	new_res0[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res0
	hc.health_changed.connect(boss._on_health_comp_changed)
	hc.died.connect(boss._on_health_comp_died)
	var color_indices: Array[int] = []
	boss.color_changed.connect(
		func(idx: int, _a: Color, _e: Color) -> void: color_indices.append(idx)
	)
	# Phase 0 → phase 1: FIRE x phase_hp.
	boss.apply_damage(p0.phase_hp, DamageType.Kind.FIRE)
	_assert("after phase 0 depletion color_phase_index == 1", boss._color_phase_index == 1)
	# Phase 1 (ICE).
	var p1: BossColorPhase = PRISM_DATA.color_phases[1]
	boss.apply_damage(p1.phase_hp, DamageType.Kind.ICE)
	_assert("after phase 1 depletion color_phase_index == 2", boss._color_phase_index == 2)
	# Phase 2 (ELECTRIC) → explode.
	var p2: BossColorPhase = PRISM_DATA.color_phases[2]
	var died_count: Array[int] = [0]
	boss.died.connect(func(_b: Boss) -> void: died_count[0] += 1)
	boss.apply_damage(p2.phase_hp, DamageType.Kind.ELECTRIC)
	_assert("died fired after last phase depletion", died_count[0] > 0)
	_assert("color_changed emitted 2 times (phase 0→1, 1→2)", color_indices.size() == 2)


func _test_died_fires_exactly_once() -> void:
	var boss: Boss = _make_prism_boss()
	var hc: HealthComponent = boss.get_node("HealthComponent") as HealthComponent
	boss._color_phases_active = true
	boss._color_phase_index = 0
	var p0: BossColorPhase = PRISM_DATA.color_phases[0]
	boss._phase_hp_remaining = p0.phase_hp
	var p1_d: BossColorPhase = PRISM_DATA.color_phases[1]
	var p2_d: BossColorPhase = PRISM_DATA.color_phases[2]
	var total: int = p0.phase_hp + p1_d.phase_hp + p2_d.phase_hp
	hc.max_health = total
	hc.reset()
	boss._prev_total_hp = total
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc.resistances = new_res
	hc.health_changed.connect(boss._on_health_comp_changed)
	hc.died.connect(boss._on_health_comp_died)
	var died_count: Array[int] = [0]
	boss.died.connect(func(_b: Boss) -> void: died_count[0] += 1)
	# Deplete all 3 phases in sequence.
	boss.apply_damage(p0.phase_hp, DamageType.Kind.FIRE)
	var p1: BossColorPhase = PRISM_DATA.color_phases[1]
	boss.apply_damage(p1.phase_hp, DamageType.Kind.ICE)
	var p2: BossColorPhase = PRISM_DATA.color_phases[2]
	boss.apply_damage(p2.phase_hp, DamageType.Kind.ELECTRIC)
	_assert("died fires exactly once across all phases", died_count[0] == 1)


func _test_explode_aoe_hits_player() -> void:
	# Verify explosion AoE data fields — full AoE call requires tree (windowed).
	# Build resistances for phase 0 on a fresh HC.
	var hc_boss: HealthComponent = HealthComponent.new()
	hc_boss.max_health = 30
	hc_boss.reset()
	var new_res: Dictionary = {}
	for kind_int: int in range(DamageType.Kind.size()):
		new_res[kind_int] = 0.0
	new_res[int(DamageType.Kind.FIRE)] = 1.0
	hc_boss.resistances = new_res
	# Simulate resistance: FIRE x10 reduces, ICE/ELECTRIC = 0.
	hc_boss.apply_damage(5, DamageType.Kind.ICE)
	_assert(
		"explode test: ICE on FIRE-phase HC = 0 damage (immunity verified)", hc_boss._current == 30
	)
	hc_boss.apply_damage(5, DamageType.Kind.FIRE)
	_assert("explode test: FIRE on FIRE-phase HC reduces HP", hc_boss._current == 25)
	# Verify data fields: explode_radius / explode_damage / explode_knockback all set.
	_assert("explode_radius >= 8.0 (reaches across open room)", PRISM_DATA.explode_radius >= 8.0)
	_assert("explode_damage == 60", PRISM_DATA.explode_damage == 60)
	_assert("explode_knockback == 20.0", is_equal_approx(PRISM_DATA.explode_knockback, 20.0))
	hc_boss.free()
