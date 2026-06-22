# tools/lib/enemy/enemy_archetype.gd — typed Resource carrying enemy stats + behaviour scenes.
class_name EnemyArchetype
extends Resource
## Enemy archetype: stats + ordered list of behaviour-component scenes.
## Analogous to CastData — pure data, no per-frame logic.
## Behaviours are instanced as child nodes under Enemy/Abilities at spawn (slice 2+).

@export_group("Identity")
@export var display_name: String = "Grunt"
@export var tint_color: Color = Color.WHITE

@export_group("Stats")
@export_range(1, 50, 1) var max_health: int = 2
@export_range(0.5, 20.0, 0.1) var move_speed: float = 3.5
@export_range(0.5, 10.0, 0.1) var patrol_speed: float = 1.75
@export_range(1.0, 40.0, 0.5) var detect_range: float = 12.0
@export_range(0.5, 20.0, 0.5) var attack_range: float = 1.8
@export_range(1.0, 60.0, 0.5) var escape_range: float = 16.0
@export_range(0.1, 10.0, 0.05) var attack_cooldown: float = 0.8
@export_range(1, 100, 1) var score_value: int = 1
@export_range(1, 100, 1) var touch_damage: int = 25

@export_group("Behaviours")
## Ordered list of behaviour-component scenes (each root must extend EnemyBehaviour).
## Empty = default melee-lunge (no extra behaviour). Instanced under Abilities at spawn.
@export var behaviours: Array[PackedScene] = []
