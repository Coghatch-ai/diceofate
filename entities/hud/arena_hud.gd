# entities/hud/arena_hud.gd — ArenaHud: score, enemies, lives pips, ammo, stamina bar, end panel.
class_name ArenaHud
extends Control

const _MAX_PIPS: int = 3

var _last_ammo_text: String = ""
var _pulse_tween: Tween

@onready var _score_label: Label = $TopCenter/ScoreLabel
@onready var _active_label: Label = $TopCenter/ActiveLabel
@onready var _lives_container: HBoxContainer = $BottomLeft/LivesContainer
@onready var _stamina_bar: ColorRect = $BottomLeft/StaminaRow/StaminaBar
@onready var _stamina_fill: ColorRect = $BottomLeft/StaminaRow/StaminaBar/StaminaFill
@onready var _ammo_label: Label = $BottomRight/AmmoLabel
@onready var _result_panel: Panel = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel
@onready var _life_lost_label: Label = $LifeLostLabel


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_score(0)
	set_active(0)
	set_lives(3)
	set_ammo(0, 0)
	set_stamina(100.0, 100.0)
	_result_panel.visible = false


func set_score(n: int) -> void:
	_score_label.text = "SCORE  %d" % n


func set_active(n: int) -> void:
	_active_label.text = "ENEMIES  %d" % n


func set_lives(n: int) -> void:
	var pips: Array[Node] = _lives_container.get_children()
	for i: int in range(pips.size()):
		# SEAM: pip nodes are ColorRect children; get_children() returns Array[Node].
		@warning_ignore("unsafe_property_access")
		pips[i].visible = i < n
	if n <= 1:
		_start_pulse()
	else:
		_stop_pulse()


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


## Show a brief centered "LIFE LOST" flash that fades out over ~1 s.
## No-op if the end result panel is already visible (final life — panel takes over).
func flash_life_lost() -> void:
	if _result_panel.visible:
		return
	_life_lost_label.modulate = Color.WHITE
	_life_lost_label.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_life_lost_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	tw.tween_callback(_life_lost_label.hide)


func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_lives_container, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.4)
	_pulse_tween.tween_property(_lives_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)


func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_lives_container.modulate = Color.WHITE
