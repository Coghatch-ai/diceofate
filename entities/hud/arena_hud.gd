# entities/hud/arena_hud.gd — ArenaHud: score, enemies, lives, ammo, and end panel.
class_name ArenaHud
extends Control

var _last_ammo_text: String = ""

@onready var _score_label: Label = $ScoreLabel
@onready var _active_label: Label = $ActiveLabel
@onready var _lives_label: Label = $LivesLabel
@onready var _ammo_label: Label = $AmmoLabel
@onready var _stamina_label: Label = $StaminaLabel
@onready var _result_panel: Panel = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel


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
	_lives_label.text = "LIVES  %d" % n


func set_ammo(current: int, reserve: int) -> void:
	_last_ammo_text = "AMMO  %d / %d" % [current, reserve]
	_ammo_label.text = _last_ammo_text


func set_reloading(active: bool) -> void:
	if active:
		_ammo_label.text = "RELOADING..."
	else:
		_ammo_label.text = _last_ammo_text


func show_result(won: bool, score: int) -> void:
	var title: String = "YOU WIN" if won else "GAME OVER"
	_result_label.text = "%s\nSCORE  %d\n\nPress Enter to restart" % [title, score]
	_result_panel.visible = true


func hide_result() -> void:
	_result_panel.visible = false


func set_stamina(current: float, maximum: float) -> void:
	var pct: int = int(current / maximum * 100.0) if maximum > 0.0 else 0
	_stamina_label.text = "STAMINA  %d%%" % pct
