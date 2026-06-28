# tools/lib/cast/cast_data.gd — authored .tres: list of Effects + a TargetResolver.
# Assigned to Gun.cast_data; stamped onto each spawned Projectile at fire time.
class_name CastData
extends Resource

## Effects to apply on hit, in order.
@export var effects: Array[Effect] = []
## Resolves which nodes receive the effects. Default null -> no targets, no-op.
@export var resolver: TargetResolver
## Tint colour applied to the projectile mesh material at fire time.
## Default yellow matches existing pistol behaviour. Null cast_data -> scene default preserved.
@export var bullet_color: Color = Color(1, 1, 0)
## When true, the projectile ignores magnetic steering (pull fields / bubble zones).
## Allows the bullet to travel straight through a magnet enemy's repulsion bubble.
## Default false = all existing casts stay deflected as before.
@export var pierces_barriers: bool = false
## When true, this bullet type is acid-element. Impact spawns an acid crater decal
## via AcidDecalRouter (godot-decal-vfx pool). No gameplay change to other types.
@export var is_acid: bool = false
## Per-bullet recoil climb pattern. Null = fall back to Gun.recoil_pitch/yaw scalars
## (current behaviour — no regression). Assign a RecoilProfile .tres to enable
## curve-driven per-shot impulse climb.
@export var recoil_profile: RecoilProfile

@export_group("VFX")
## Muzzle flash OmniLight3D tint per bullet type. Drives Gun._flash_pulse() color.
## Default warm-white matches generic muzzle; override per element for identity.
@export var muzzle_color: Color = Color(1.0, 0.7, 0.3)
## Muzzle flash peak energy. Heavier/slower casts can use a bigger flash.
@export_range(1.0, 12.0, 0.1) var muzzle_energy: float = 4.0
## Per-element muzzle spark scene. Null = use the generic muzzle_spark.tscn fallback.
## Assign a PackedScene .tscn to get a distinct per-cast muzzle particle burst.
@export var muzzle_vfx_scene: PackedScene

@export_group("Ammo")
## Maximum ammo pool for this bullet type. 0 = unlimited (legacy / non-cast paths).
@export_range(0, 200, 1) var max_ammo: int = 30
## Ammo consumed per shot.
@export_range(1, 10, 1) var ammo_cost: int = 1
## Passive regen rate in ammo units per second.
@export_range(0.0, 20.0, 0.1) var ammo_regen: float = 3.0
