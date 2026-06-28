# Boss Contact Damage + Knockback

**Goal** — The boss, on body contact with the player, deals damage AND physically pushes (knocks back) the player. Push strength is DATA on `BossData`. The boss arena has no walls.

## Foundation already exists (confirmed in repo)

- `boss.gd._on_charge_contact(player)` already calls `player.apply_damage(charge_damage)` + emits `touched_player`. Contact DAMAGE is done.
- Player already exposes `apply_knockback(Vector3)` (WaveManager's `_on_enemy_bumped_player` calls it with the attacker's position). Reuse this exact seam.
- `BossData` is the tunables resource; `boss_warden.tres` is the instance.

## Scope (in)

- **`BossData`: add `@export_range knockback_impulse: float = 14.0`** (m/s push applied to player on contact). One new data field — knockback as data per brief.
- **`boss.gd._on_charge_contact`**: after `apply_damage`, if `player.has_method("apply_knockback")`, call it through the SAME duck-typed seam WaveManager uses. CONFIRMED signature (`player.gd:428`): `apply_knockback(hitter_pos: Vector3)` — position-only; the player computes direction and applies its OWN `knockback_speed` export. → Boss passes `self.global_position`. This works immediately at the player's fixed strength.
- **Stronger boss push (decided): add an optional magnitude param to the player.** Extend player to `apply_knockback(hitter_pos: Vector3, speed_override: float = -1.0)` (default keeps every existing caller — WaveManager — unchanged; -1 = use `knockback_speed`). Boss passes `knockback_impulse` as the override so the data field actually drives force. Small, backward-compatible player edit; record it as part of this slice.
- **`boss_warden.tres`**: set `knockback_impulse` (default 14.0). Also raise `charge_damage` review is out of scope — leave at 30.
- **Wall-less boss room** (geometry detail lives in slice 4): the boss room is an OPEN platform — no perimeter walls. Fall protection = a `FallZone` Area3D below + the existing fall-reset pattern (`ruined_warehouse.gd._reset_player`) so a knocked-back player who goes off the edge respawns on the platform with hazard damage, NOT an instant loss. This makes "no walls + knockback" survivable. State in slice 4.

## Scope (out)

- New knockback system on the player — reuse existing `apply_knockback` seam (cut).
- Knockback on volley/slam — v1 = charge-contact only (cut: scope; slam already has its own AoE damage).
- Boss new mechanics / phases — already built (cut).
- Tuning charge_damage/health balance (cut: separate balance pass).

## Acceptance

- Headless smoke (`tools/smoke_boss.gd` extend, or new): drive boss into charge contact with a stub player exposing `apply_damage`+`apply_knockback`; assert both called once, `touched_player` emitted.
- In-engine (slice-4 F5): boss charge that hits player visibly shoves the player backward AND drops HP; a player shoved off the wall-less platform respawns on it (fall-reset), not game-over.
- validate.sh clean.

## Skill notes

- `godot-fps-enemy-combat` — contact uses the established `apply_damage`/duck-typed seam; knockback rides the same seam.
- `godot-data-driven-enemy` / BossData — knockback strength is data on the resource.
- `godot-greybox` — wall-less open platform + FallZone is the spatial spec; verticality/landmark per P5/P6 in slice 4.
- `godot-code-rules` — `@warning_ignore("unsafe_method_access")` on the `apply_knockback` seam, guarded by `has_method`.

## Later

- Knockback on slam (radial push from impact point).
- Player-side knockback magnitude param so `knockback_impulse` scales force directly.
- Boss-room minion adds (brief permits randomness in the final room).

## Open questions

(none — `apply_knockback` is position-only today; this slice adds the backward-compatible `speed_override` param so `knockback_impulse` drives force.)
