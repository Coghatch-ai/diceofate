# entities/hud/arena_hud.gd — ArenaHud: displays kills and active-enemy count.
class_name ArenaHud
extends Control

@onready var _kills_label: Label = $KillsLabel
@onready var _active_label: Label = $ActiveLabel


func _ready() -> void:
	set_kills(0)
	set_active(0)


func set_kills(n: int) -> void:
	_kills_label.text = "KILLS  %d" % n


func set_active(n: int) -> void:
	_active_label.text = "ENEMIES  %d" % n
