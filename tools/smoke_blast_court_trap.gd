# tools/smoke_blast_court_trap.gd — headless smoke: Blast Court trap damage seam.
# Asserts: body_entered on a trap Area3D decrements HP via apply_damage(trap_damage);
#          re-entry within ~0.5 s cooldown does NOT deal further damage.
# Exit 0 = pass. Exit 1 = fail (prints reason).
extends SceneTree

const TRAP_DAMAGE: int = 10
const TRAP_COOLDOWN: float = 0.5
const START_HP: int = 100


# Minimal stub that satisfies the duck-typed seam in blast_court.gd:
# must be in group "player" and expose apply_damage(int) → void.
class PlayerStub:
	extends Node3D
	var _hp: int = START_HP
	var _damage_calls: int = 0

	func _ready() -> void:
		add_to_group("player")

	func apply_damage(amount: int) -> void:
		_hp -= amount
		_damage_calls += 1


func _init() -> void:
	_run()
	quit(0)


func _run() -> void:
	# ── 1. Build a minimal BlastCourt with the trap handler ──────────────────
	var court: BlastCourt = BlastCourt.new()
	court.trap_damage = TRAP_DAMAGE

	# Simulate Area3D trap connections manually — we call the handler directly
	# to avoid spinning up a full physics world headlessly.

	# ── 2. First hit: HP should drop by trap_damage ──────────────────────────
	var stub: PlayerStub = PlayerStub.new()
	# _ready() not called (no scene tree) — add group manually.
	stub.add_to_group("player")

	court._on_trap_body_entered(stub)

	_assert(
		stub._hp == START_HP - TRAP_DAMAGE,
		"first hit: expected %d, got %d" % [START_HP - TRAP_DAMAGE, stub._hp]
	)
	_assert(
		stub._damage_calls == 1, "first hit: apply_damage call count wrong: %d" % stub._damage_calls
	)

	# ── 3. Immediate re-entry: cooldown must block second hit ────────────────
	court._on_trap_body_entered(stub)

	_assert(
		stub._hp == START_HP - TRAP_DAMAGE,
		"re-entry within cooldown: HP should not change, got %d" % stub._hp
	)
	_assert(
		stub._damage_calls == 1,
		"re-entry within cooldown: apply_damage called again (count=%d)" % stub._damage_calls
	)

	# ── 4. After cooldown elapses: hit lands again ───────────────────────────
	# Manually advance the timestamp in the cooldown dict past the threshold.
	var id: int = stub.get_instance_id()
	court._trap_last_hit[id] = Time.get_ticks_msec() / 1000.0 - TRAP_COOLDOWN - 0.01

	court._on_trap_body_entered(stub)

	_assert(
		stub._hp == START_HP - TRAP_DAMAGE * 2,
		"post-cooldown hit: expected %d, got %d" % [START_HP - TRAP_DAMAGE * 2, stub._hp]
	)
	_assert(
		stub._damage_calls == 2, "post-cooldown: apply_damage count wrong: %d" % stub._damage_calls
	)

	# ── 5. Non-player body must be ignored ───────────────────────────────────
	var non_player: Node3D = Node3D.new()
	var hp_before: int = stub._hp
	court._on_trap_body_entered(non_player)
	_assert(stub._hp == hp_before, "non-player body should not change HP")

	print("smoke_blast_court_trap: PASS")


func _assert(condition: bool, msg: String) -> void:
	if not condition:
		push_error("smoke_blast_court_trap: FAIL — %s" % msg)
		quit(1)
