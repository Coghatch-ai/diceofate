# entities/hud/arena_hud.gd — ArenaHud: score, enemies, HP bar, ammo, stamina bar, end panel.
class_name ArenaHud
extends Control

## HP fraction below which the bar pulses red (low-health warning).
const _LOW_HP_THRESHOLD: float = 0.25

var _last_ammo_text: String = ""
var _pulse_tween: Tween

@onready var _score_label: Label = $TopCenter/ScoreLabel
@onready var _active_label: Label = $TopCenter/ActiveLabel
@onready var _hp_bar: ColorRect = $BottomLeft/HpRow/HpBar
@onready var _hp_fill: ColorRect = $BottomLeft/HpRow/HpBar/HpFill
@onready var _stamina_bar: ColorRect = $BottomLeft/StaminaRow/StaminaBar
@onready var _stamina_fill: ColorRect = $BottomLeft/StaminaRow/StaminaBar/StaminaFill
@onready var _ammo_label: Label = $BottomRight/AmmoLabel
@onready var _result_panel: Panel = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_score(0)
	set_active(0)
	set_health(100, 100)
	set_ammo(0, 0)
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


func set_ammo(current: int, reserve: int) -> void:
	_last_ammo_text = "%d / %d" % [current, reserve]
	_ammo_label.text = _last_ammo_text


func set_reloading(active: bool) -> void:
	if active:
		_ammo_label.text = "RELOADING..."
	else:
		_ammo_label.text = _last_ammo_text


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
