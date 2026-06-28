# autoload/run_state.gd — RunState: carries run state across a level swap. Data only, no logic.
class_name RunStateData
extends Node

## True while a progression carry is in flight (set by main.gd,
## cleared by RoomController on level load).
static var active: bool = false
## Score to restore into the next level's RoomController when active is true.
static var score: int = 0
## Full-lap counter: increments each time the level list wraps (L3 → L1).
## Resets to 0 on a fresh run/restart. Read by RoomController to scale difficulty.
static var lap: int = 0
