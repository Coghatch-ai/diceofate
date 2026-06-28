# tools/smoke_stat_block.gd — headless StatBlock logic asserts (godot-runtime-smoke).
# Run: $GODOT --headless --path . --script tools/smoke_stat_block.gd
extends SceneTree


func _init() -> void:
	var block: StatBlock = StatBlock.new()
	block.base_values = {&"move_speed": 6.0}

	var passed: int = 0
	var failed: int = 0

	# ── Helper ────────────────────────────────────────────────────────────────

	var assert_approx := func(label: String, got: float, want: float) -> void:
		if is_equal_approx(got, want):
			print("  PASS  %s  (%.4f)" % [label, got])
			passed += 1
		else:
			push_error("  FAIL  %s  got=%.4f  want=%.4f" % [label, got, want])
			failed += 1

	var assert_true := func(label: String, cond: bool) -> void:
		if cond:
			print("  PASS  %s" % label)
			passed += 1
		else:
			push_error("  FAIL  %s" % label)
			failed += 1

	# ── 1. Two +50% MULTIPLY buffs → ×2.0 (NOT ×2.25 sequential) ─────────────
	var m1: StatModifier = StatModifier.new()
	m1.stat = &"move_speed"
	m1.op = StatModifier.Op.MULTIPLY
	m1.value = 0.5
	m1.source = &"buff:haste_a"

	var m2: StatModifier = StatModifier.new()
	m2.stat = &"move_speed"
	m2.op = StatModifier.Op.MULTIPLY
	m2.value = 0.5
	m2.source = &"buff:haste_b"

	block.add_modifier(m1)
	block.add_modifier(m2)
	# 6.0 × (1.0 + 0.5 + 0.5) = 6.0 × 2.0 = 12.0
	assert_approx.call(
		"two +50% MULTIPLY → 12.0 (×2.0 not ×2.25)", block.get_value(&"move_speed"), 12.0
	)

	# ── 2. ADD-then-MULTIPLY order: (6+2)×1.5 = 12.0 ─────────────────────────
	var block2: StatBlock = StatBlock.new()
	block2.base_values = {&"move_speed": 6.0}

	var add_mod: StatModifier = StatModifier.new()
	add_mod.stat = &"move_speed"
	add_mod.op = StatModifier.Op.ADD
	add_mod.value = 2.0
	add_mod.source = &"buff:flat"

	var mult_mod: StatModifier = StatModifier.new()
	mult_mod.stat = &"move_speed"
	mult_mod.op = StatModifier.Op.MULTIPLY
	mult_mod.value = 0.5
	mult_mod.source = &"buff:pct"

	block2.add_modifier(add_mod)
	block2.add_modifier(mult_mod)
	# (6 + 2) × 1.5 = 12.0
	assert_approx.call("ADD(+2) then MULTIPLY(+50%) → 12.0", block2.get_value(&"move_speed"), 12.0)

	# ── 3. Same source re-apply refreshes (no double) ─────────────────────────
	var block3: StatBlock = StatBlock.new()
	block3.base_values = {&"move_speed": 6.0}

	var same_a: StatModifier = StatModifier.new()
	same_a.stat = &"move_speed"
	same_a.op = StatModifier.Op.MULTIPLY
	same_a.value = 0.5
	same_a.source = &"buff:haste"

	var same_b: StatModifier = StatModifier.new()
	same_b.stat = &"move_speed"
	same_b.op = StatModifier.Op.MULTIPLY
	same_b.value = 0.5
	same_b.source = &"buff:haste"  # same source

	block3.add_modifier(same_a)
	block3.add_modifier(same_b)
	# Only one slot → 6.0 × 1.5 = 9.0 (not 12.0)
	assert_approx.call(
		"same source re-apply → 9.0 (refresh, not stack)", block3.get_value(&"move_speed"), 9.0
	)

	# ── 4. remove_all_from_source restores base ────────────────────────────────
	block3.remove_all_from_source(&"buff:haste")
	assert_approx.call(
		"remove_all_from_source → base 6.0 restored", block3.get_value(&"move_speed"), 6.0
	)

	# ── 5. stat_changed suppressed on no-op ────────────────────────────────────
	var block4: StatBlock = StatBlock.new()
	block4.base_values = {&"move_speed": 6.0}
	var emit_count: int = 0
	block4.stat_changed.connect(func(_s: StringName, _v: float) -> void: emit_count += 1)
	# set_base to the current value — should NOT emit again (is_equal_approx guard)
	block4.set_base(&"move_speed", 6.0)
	assert_true.call("stat_changed suppressed on no-op set_base", emit_count == 0)

	# ── Result ────────────────────────────────────────────────────────────────
	print("\nsmoke_stat_block: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		push_error("smoke_stat_block: FAIL (%d assertion(s) failed)" % failed)
		quit(1)
	else:
		print("smoke_stat_block: OK")
		quit(0)
