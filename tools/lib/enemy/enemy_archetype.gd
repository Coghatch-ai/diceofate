# tools/lib/enemy/enemy_archetype.gd — typed Resource carrying enemy stats + behaviour scenes.
class_name EnemyArchetype
extends Resource
## Enemy archetype: stats + ordered list of behaviour-component scenes.
## Analogous to CastData — pure data, no per-frame logic.
## Behaviours are instanced as child nodes under Enemy/Abilities at spawn (slice 2+).

@export_group("Identity")
@export var id: StringName = &""
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
## Speed (m/s) applied to the player when the enemy contacts them.
## Passed as speed_override to Player.apply_knockback. 0 = no push.
@export_range(0.0, 30.0, 0.5) var push_strength: float = 6.0

@export_group("Defense")
## Resistance map: DamageType.Kind (int key) → float multiplier.
## 0.0 = full immunity, 0.5 = 50% resistance, 1.0 = no resistance (default).
## Mirrors HealthComponent.resistances exactly. Leave empty for no resistances.
@export var resistances: Dictionary = {}

@export_group("Hit Feedback")
## Albedo+emission color flashed on non-fatal hits. Default = red.
@export var hit_flash_color: Color = Color(1.0, 0.1, 0.1, 1.0)
## Duration of the hit flash tween in seconds. Shorter = snappier.
@export_range(0.02, 0.4, 0.01) var hit_flash_duration: float = 0.05
## Optional spark VFX scene (must be a VfxOneShot). Null = use built-in hit_burst.tscn.
@export var hit_spark_scene: PackedScene
## Hitstop duration in seconds (brief Engine.time_scale dip). 0 = disabled.
@export_range(0.0, 0.2, 0.01) var hitstop_seconds: float = 0.0

@export_group("Model")
## Optional replacement model scene for this archetype. When set, the enemy swaps out
## the default EnemyGrunt mesh at spawn by freeing the existing Mesh children and
## instancing this scene under the Mesh node. Must contain at least one MeshInstance3D
## descendant so tint and hit-flash still apply. Null = keep the hardcoded grunt model.
@export var model: PackedScene

@export_group("Behaviours")
## Ordered list of behaviour-component scenes (each root must extend EnemyBehaviour).
## Empty = default melee-lunge (no extra behaviour). Instanced under Abilities at spawn.
@export var behaviours: Array[PackedScene] = []
