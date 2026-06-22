# entities/player/components/bullet_ammo_tracker.gd — per-bullet-type ammo pool with passive regen.
# Child node on Gun (or player). Keyed by bullet index (0-4); data sourced from CastData fields.
class_name BulletAmmoTracker
extends Node

## Emitted whenever any bullet type's ammo changes. index = slot 0-4.
signal ammo_changed(index: int, current: int, maximum: int)

## Ordered list of CastData; must match Gun.bullet_casts order.
## Set by the owner (Gun._ready) before use.
var casts: Array[CastData] = []

# Fractional ammo per slot (float for sub-integer regen accumulation).
var _ammo: Array[float] = []


## Initialise pools from casts array. Call after setting casts.
func init_pools() -> void:
	_ammo.clear()
	for cast: CastData in casts:
		_ammo.append(float(cast.max_ammo))


func _process(delta: float) -> void:
	for i: int in range(casts.size()):
		var cast: CastData = casts[i]
		if cast.max_ammo <= 0:
			continue
		var prev_int: int = int(_ammo[i])
		_ammo[i] = minf(_ammo[i] + cast.ammo_regen * delta, float(cast.max_ammo))
		var new_int: int = int(_ammo[i])
		if new_int != prev_int:
			ammo_changed.emit(i, new_int, cast.max_ammo)


## Returns true if bullet index i has enough ammo to fire.
func can_fire(i: int) -> bool:
	if i < 0 or i >= casts.size():
		return false
	var cast: CastData = casts[i]
	if cast.max_ammo <= 0:
		return true  # unlimited (legacy / non-ammo path)
	return int(_ammo[i]) >= cast.ammo_cost


## Consume ammo_cost for bullet index i. No-op if unlimited (max_ammo == 0).
func consume(i: int) -> void:
	if i < 0 or i >= casts.size():
		return
	var cast: CastData = casts[i]
	if cast.max_ammo <= 0:
		return
	var before: int = int(_ammo[i])
	_ammo[i] = maxf(_ammo[i] - float(cast.ammo_cost), 0.0)
	var after: int = int(_ammo[i])
	if after != before:
		ammo_changed.emit(i, after, cast.max_ammo)


## Returns current integer ammo for slot i.
func get_ammo(i: int) -> int:
	if i < 0 or i >= _ammo.size():
		return 0
	return int(_ammo[i])


## Returns max ammo for slot i (from CastData).
func get_max(i: int) -> int:
	if i < 0 or i >= casts.size():
		return 0
	return casts[i].max_ammo
