# autoload/run_state.gd — RunState: carries run state across a level swap. Data only, no logic.
class_name RunStateData
extends Node

## True while a progression carry is in flight (set by main.gd, cleared by WaveManager._seed_start).
static var active: bool = false
## Score to restore into the next level's WaveManager when active is true.
static var score: int = 0
