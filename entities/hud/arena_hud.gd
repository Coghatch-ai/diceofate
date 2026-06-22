# entities/hud/arena_hud.gd — score, enemies, HP, 5-slot bullet hotbar, stamina, end panel.
class_name ArenaHud
extends Control

## HP fraction below which the bar pulses red (low-health warning).
const _LOW_HP_THRESHOLD: float = 0.25
## Number of bullet slots in the hotbar.
const SLOT_COUNT: int = 5
## Key labels shown above each slot.
const SLOT_KEYS: Array[String] = ["Q", "E", "R", "T", "Y"]

var _pulse_tween: Tween
## Slot containers: each holds a ColorRect swatch + Label count.
var _slots: Array[Control] = []
var _slot_swatches: Array[ColorRect] = []
var _slot_labels: Array[Label] = []
var _active_slot: int = 0

@onready var _score_label: Label = $TopCenter/ScoreLabel
@onready var _active_label: Label = $TopCenter/ActiveLabel
@onready var _hp_bar: ColorRect = $BottomLeft/HpRow/HpBar
@onready var _hp_fill: ColorRect = $BottomLeft/HpRow/HpBar/HpFill
@onready var _stamina_bar: ColorRect = $BottomLeft/StaminaRow/StaminaBar
@onready var _stamina_fill: ColorRect = $BottomLeft/StaminaRow/StaminaBar/StaminaFill
@onready var _hotbar: HBoxContainer = $BottomRight/BulletHotbar
@onready var _result_panel: Panel = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_build_hotbar_slots()
	set_score(0)
	set_active(0)
	set_health(100, 100)
	set_stamina(100.0, 100.0)
	_result_panel.visible = false


func set_score(n: int) -> void:
	_score_label.text = "SCORE  %d" % n


func set_active(n: int) -> void:
	_active_label.text = "ENEMIES  %d" % n


## Update HP bar fill and low-HP pulse. current/max are int from HealthComponent.health_changed.
func set_health(current: int, maximum: int) -> void:
	if maximum <= 0:
		_hp_fill.size.x = 0.0
		return
	var ratio: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	_hp_fill.size.x = _hp_bar.size.x * ratio
	if ratio < _LOW_HP_THRESHOLD:
		_start_hp_pulse()
	else:
		_stop_hp_pulse()


## Update one bullet slot's ammo display. Connected to BulletAmmoTracker.ammo_changed.
func set_bullet_ammo(index: int, current: int, maximum: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slot_labels[index].text = "%d/%d" % [current, maximum]


## Highlight the active slot. Connected to Gun.active_bullet_changed.
func set_active_bullet(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_active_slot = index
	for i: int in range(SLOT_COUNT):
		var slot: Control = _slots[i]
		var swatch: ColorRect = _slot_swatches[i]
		if i == index:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
			swatch.color = Color(swatch.color.r, swatch.color.g, swatch.color.b, 1.0)
		else:
			slot.modulate = Color(0.55, 0.55, 0.55, 1.0)
			swatch.color = Color(swatch.color.r, swatch.color.g, swatch.color.b, 0.6)


func show_result(won: bool, score: int) -> void:
	var title: String = "YOU WIN" if won else "YOU DIE"
	_result_label.text = "%s\nSCORE  %d\n\nPress Enter to restart" % [title, score]
	_result_panel.visible = true


func hide_result() -> void:
	_result_panel.visible = false


func set_stamina(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		_stamina_fill.size.x = 0.0
		return
	var ratio: float = clampf(current / maximum, 0.0, 1.0)
	_stamina_fill.size.x = _stamina_bar.size.x * ratio


func _build_hotbar_slots() -> void:
	# Bullet colors: pistol=yellow, heavy=red, stun=cyan, blast=orange, rapid=white.
	var colors: Array[Color] = [
		Color(1.0, 1.0, 0.0),
		Color(1.0, 0.2, 0.15),
		Color(0.2, 0.8, 1.0),
		Color(1.0, 0.5, 0.0),
		Color(1.0, 1.0, 1.0),
	]
	for i: int in range(SLOT_COUNT):
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(52.0, 56.0)
		_hotbar.add_child(slot)
		_slots.append(slot)

		var key_lbl := Label.new()
		key_lbl.text = SLOT_KEYS[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 11)
		slot.add_child(key_lbl)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(52.0, 10.0)
		swatch.color = colors[i]
		slot.add_child(swatch)
		_slot_swatches.append(swatch)

		var ammo_lbl := Label.new()
		ammo_lbl.text = "0/0"
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.add_theme_font_size_override("font_size", 13)
		slot.add_child(ammo_lbl)
		_slot_labels.append(ammo_lbl)

	# Highlight slot 0 by default.
	set_active_bullet(0)


func _start_hp_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_hp_fill, "color", Color(1.0, 0.0, 0.0, 1.0), 0.4)
	_pulse_tween.tween_property(_hp_fill, "color", Color(0.85, 0.1, 0.1, 1.0), 0.4)


func _stop_hp_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_hp_fill.color = Color(0.85, 0.1, 0.1, 1.0)
