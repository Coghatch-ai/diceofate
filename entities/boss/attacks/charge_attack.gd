# entities/boss/attacks/charge_attack.gd — ChargeAttack: dash toward player + contact damage.
# Ported from boss.gd _start_charge / _tick_charge / _on_charge_contact.
# Data: reads charge_speed, charge_duration, charge_damage, knockback_impulse from BossData.
class_name ChargeAttack
extends BossAttack

const _CONTACT_DIST: float = 1.6

# Injected Boss ref (typed — Boss is the host, calls down).
var _boss: Boss = null
# Direction locked at start() from player position.
var _charge_dir: Vector3 = Vector3.ZERO
# Time remaining in the charge dash.
var _time_left: float = 0.0
# Guard: player already hit this charge (one contact per dash).
var _hit_player: bool = false


func bind(boss: Node) -> void:
	_boss = boss as Boss


func telegraph_duration() -> float:
	if _boss == null or _boss.data == null:
		return 0.8
	return _boss.data.telegraph_duration


func start() -> void:
	_hit_player = false
	if _boss == null:
		_time_left = 0.5
		_charge_dir = Vector3.FORWARD
		return
	# Lock direction toward player at dash start.
	var p: Node3D = _boss.get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		var dir: Vector3 = p.global_position - _boss.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			_charge_dir = dir.normalized()
		else:
			_charge_dir = -_boss.global_transform.basis.z
	else:
		_charge_dir = -_boss.global_transform.basis.z
	var dur: float = _boss.data.charge_duration if _boss.data != null else 0.5
	_time_left = dur


func tick(delta: float) -> bool:
	if _boss == null:
		return true
	var speed: float = _boss.data.charge_speed if _boss.data != null else 18.0
	_boss.velocity.x = _charge_dir.x * speed
	_boss.velocity.z = _charge_dir.z * speed
	# Contact check.
	if not _hit_player:
		var p: Node3D = _boss.get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			var dist: float = _boss.global_position.distance_to(p.global_position)
			if dist < _CONTACT_DIST:
				_hit_player = true
				_deal_contact_damage(p)
				return true
	_time_left -= delta
	return _time_left <= 0.0


func recover_duration() -> float:
	if _boss == null or _boss.data == null:
		return 1.0
	return _boss.data.recover_duration


func _deal_contact_damage(player: Node3D) -> void:
	if _boss == null:
		return
	var dmg: int = _boss.data.charge_damage if _boss.data != null else 30
	if player.has_method("apply_damage"):
		# SEAM: duck-typed apply_damage — same contract as on_hit targets.
		@warning_ignore("unsafe_method_access")
		player.apply_damage(dmg)
	if player.has_method("apply_knockback"):
		var impulse: float = _boss.data.knockback_impulse if _boss.data != null else 14.0
		# SEAM: duck-typed apply_knockback(hitter_pos, speed_override).
		@warning_ignore("unsafe_method_access")
		player.apply_knockback(_boss.global_position, impulse)
	_boss.notify_touched_player()
