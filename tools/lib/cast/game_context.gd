# tools/lib/cast/game_context.gd — DTO built by Projectile on hit; passed to Effect.apply().
class_name GameContext
extends RefCounted

## Node that fired the projectile (the Gun's owner or the Gun itself).
var instigator: Node
## Body the projectile collided with.
var target: Node
## World position of the hit.
var hit_pos: Vector3
## Surface normal at hit point.
var hit_normal: Vector3
## World position of the instigator at fire time (for knockback direction).
var instigator_pos: Vector3
## Direct space state for physics queries (e.g. RadiusTargetResolver sphere query).
## Filled by Projectile._on_body_entered via get_world_3d().direct_space_state.
## Null when running headless smoke tests without a physics world.
var space: PhysicsDirectSpaceState3D
