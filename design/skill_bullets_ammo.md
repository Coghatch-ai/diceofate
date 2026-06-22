# Skill-Bullets + Per-Bullet-Type Ammo

**Goal** — The rifle is the only weapon; Q/E/R/T/Y pick one of 5 bullet-casts, LMB fires the
active one, and each bullet-type has its own ammo that passively regenerates, shown in a 5-slot
HUD hotbar with the active slot highlighted.

**Data-driven first.** Ammo is the next slice of the existing **Cast system** (`tools/lib/cast/`),
not a one-off: ammo becomes authored data on `CastData` (`max_ammo`, `ammo_cost`, `ammo_regen`),
and a runtime `BulletAmmoTracker` component holds current ammo keyed per `CastData`. The 5 skill
bullets are the **first entries** in a `bullet_casts: Array[CastData]` registry on the rifle — add
a 6th bullet later = author a `.tres` + drop it in the array, no firing-path change. Reuses
`gun.gd`'s stamp path, `Projectile`, the 4 existing cast `.tres`, and the `ArenaHud` plumbing.

## Decisions applied (interview — recorded so you can override)
- **Remove pistol; rifle is the only weapon.** Delete pistol/carbine/blast_launcher from the player; no cycling.
- **Select-then-LMB.** Q/E/R/T/Y swap the rifle's active `CastData`; LMB fires it through the unchanged `try_fire()` path. ADS/spread/recoil/sprint-sway untouched.
- **Passive per-type regen.** Each cast has `max_ammo` + `ammo_regen` (/s); ammo refills over time per type. **No reload, no ammo pickups** for bullet-types.
- **5th bullet = Rapid Light:** `[Damage(1)]` only (NO knockback), `HitTargetResolver`, white. The only no-KB bullet — a spammy precision round.
- **Key→bullet:** `Q`=light, `E`=heavy, `R`=stun, `T`=blast, `Y`=rapid-light.
- **Ammo numbers:** light max 30 / regen 3; heavy max 8 / regen 0.5; stun max 12 / regen 1; blast max 5 / regen 0.4; rapid max 20 / regen 2. (`ammo_cost` = 1 each.)
- **HUD:** 5-slot hotbar — key label + bullet color swatch + ammo count; active slot highlighted.

## The 5 bullets (cast → key → identity)
| Key | Cast `.tres` | Effects × resolver | Color | max / regen |
|---|---|---|---|---|
| Q | `pistol_cast.tres` (light) | Dmg1 + KB, Hit | yellow | 30 / 3.0 |
| E | `heavy_cast.tres` | Dmg3 + KB + pierces, Hit | red | 8 / 0.5 |
| R | `stun_cast.tres` | Dmg1 + KB, Hit | cyan | 12 / 1.0 |
| T | `blast_cast.tres` | Dmg2 + KB, Radius(3.0) | orange | 5 / 0.4 |
| Y | `rapid_cast.tres` **(NEW)** | Dmg1 only, Hit | white | 20 / 2.0 |

All 5 already use existing effects/resolvers — composition proven, no new `Effect`/`Resolver` class.

---

## Slice 1 — Single-rifle consolidation (remove extra weapons, kill cycling)
**godot-dev task (godot-player):** In `weapon_controller.gd` reduce to a single rifle weapon.
- Remove `_pistol`/`_carbine`/`_blast_launcher` `@onready` refs, the 4-slot `_swap_weapon()` cycle, `_slot_index`, and the `equip_weapon` input branch in `process_input()`. Active weapon = `_rifle` always.
- Player starts holding the rifle (visible); no other weapon nodes in the player scene.
- Remove `pistol`/`carbine`/`blast_launcher` weapon-instance children from the player `.tscn`; delete `carbine.tscn`, `blast_launcher.tscn` (keep `weapon.tscn` base + `rifle.tscn`). `pistol_cast.tres`/`stun_cast.tres`/`blast_cast.tres` STAY (reused as bullet data in slice 2).
- `collect_pickup()` AMMO branch: simplify to the rifle only (becomes inert after slice 3 removes per-weapon ammo — leave HEALTH branch intact).
- Leave `gun.gd` firing/ammo as-is this slice (still per-weapon ammo; replaced in slice 3).

**Scope (out):** input-map edits (slice 2); ammo model change (slice 3).
**Runtime-smoke:** extend/keep `smoke_*` — boot player scene, assert exactly one Gun present, `try_fire()` still fires, no `equip_weapon` handler. validate.sh clean.
**Acceptance:** F5 → only the rifle in hand; Q does nothing (no swap); LMB fires; `godot-verify` L0/L1/L2 pass.

## Slice 2 — Q/E/R/T/Y skill→cast binding + 5th bullet + input map
**godot-dev task (godot-combat + godot-player):**
- **5th cast:** author `entities/weapon/rapid_cast.tres` — copy `stun_cast.tres` format; effects `[Damage(1)]` (drop the KnockbackEffect sub_resource), `HitTargetResolver`, `bullet_color = Color(1,1,1,1)`. (cast-system "Add a new bullet type".)
- **Input map (`project.godot`):** add actions `bullet_1`=Q, `bullet_2`=E, `bullet_3`=R, `bullet_4`=T, `bullet_5`=Y. **Remove** `equip_weapon` and `reload` actions (both freed: Q/R now skill keys; regen replaces reload). Update CLAUDE.md input-actions line.
- **`gun.gd` (rifle):** add `@export var bullet_casts: Array[CastData] = []` (the 5 casts, in key order) + `var _active_cast: int = 0`; add `func set_active_bullet(index: int) -> void` that sets `cast_data = bullet_casts[index]` (re-uses the existing `cast_data` stamp — the active cast IS what `_fire()` stamps). Emit a new `active_bullet_changed(index: int)` signal for the HUD.
- **`weapon_controller.gd`:** in `process_input()` add 5 `is_action_just_pressed("bullet_N")` → `rifle.set_active_bullet(N-1)`. LMB fire path unchanged.

**Scope (out):** ammo gating + HUD hotbar (slice 3). This slice: switching the active cast visibly changes bullet COLOR + behaviour on fire.
**Runtime-smoke:** load `rapid_cast.tres`, run resolve+apply loop vs a 3-HP enemy — assert Dmg1 does NOT one-shot, no `apply_knockback` reached (no-KB identity). Assert `set_active_bullet(i)` swaps `cast_data` to `bullet_casts[i]`.
**Acceptance:** F5 → press Q/E/R/T/Y, LMB → bullet color changes yellow/red/cyan/orange/white; heavy one-shots a 3-HP tank, light does not; blast hits multiple; rapid pushes nothing back. validate.sh + smoke_cast + godot-verify pass.

## Slice 3 — Per-bullet-type ammo in the Cast system + 5-slot HUD
**godot-dev task (godot-combat + godot-player + HUD):**
- **`cast_data.gd`:** add `@export var max_ammo: int = 30`, `@export var ammo_cost: int = 1`, `@export var ammo_regen: float = 3.0`. Author each of the 5 `.tres` with its numbers (table above). Backward-compatible defaults.
- **New component `entities/player/components/bullet_ammo_tracker.gd`** (`class_name BulletAmmoTracker extends Node`): holds `var _ammo: Dictionary` keyed by cast index → float current; `_process(delta)` regens each toward its `max_ammo` (clamped); `func can_fire(i) -> bool` (`_ammo[i] >= cast.ammo_cost`); `func consume(i) -> void`; `func get_ammo(i) -> int`. Signal `ammo_changed(index, current, maximum)`. Composition: child node on the rifle/player, no autoload.
- **Gate firing:** `gun.gd try_fire()` — before `_fire()`, check `tracker.can_fire(_active_cast)`; if not, `out_of_ammo`/dry-click, return false; on fire, `tracker.consume(_active_cast)`. **Migrate OFF per-weapon ammo:** remove `_ammo`/`_reserve`/`ammo_max`/`reserve_max`/`reload_*`/`refill_ammo`/the `Reload` timer from `gun.gd` (ammo now lives in the tracker, keyed per bullet-type). Keep `fired`/`out_of_ammo`/`_empty_sfx`.
- **HUD `arena_hud.gd`:** replace single `AmmoLabel` with a 5-slot `BulletHotbar` row — each slot = key label + color swatch (from `bullet_color`) + ammo count; `set_bullet_ammo(index, current, maximum)` updates a slot; `set_active_bullet(index)` highlights one. Wire `tracker.ammo_changed` → `set_bullet_ammo` and `gun.active_bullet_changed` → `set_active_bullet`.

**Scope (out):** ammo pickups (none — regen model); reload (removed); cross-type shared pool.
**Runtime-smoke (`smoke_*`):** boot scene; assert firing the active bullet decrements its tracker entry by `ammo_cost`; at 0 ammo `try_fire()` returns false (no projectile); `_process` regens toward `max_ammo`; switching active bullet does NOT touch other types' ammo. validate.sh clean.
**Acceptance:** F5 → HUD shows 5 slots with live counts; firing a type drains its slot, others untouched and visibly recharging; empty type → dry-click, can't fire; active slot highlighted, follows Q/E/R/T/Y. `godot-verify` L0/L1/L2 + L3 readability (5 slots crisp). 

## Skill notes
- **cast-system** — ammo is the authored-data extension; `rapid_cast.tres` via "Add a new bullet type". Every new cast/ammo asserts driven from the loaded `.tres` through the resolve+apply loop in `smoke_cast.gd`.
- **godot-data-driven-effect-composition** — `bullet_casts` registry + per-cast ammo data keeps "new bullet = new `.tres`".
- **godot-composition** — `BulletAmmoTracker` is a child component; signals up (`ammo_changed`), calls down (`set_active_bullet`); no autoload/manager. The cast-system's parked "prereq/cost gate" stays parked — this is a per-type ammo gate inside `try_fire()`, not a generic resource system.
- **godot-code-rules** — strict typed; `Dictionary` ammo store typed-keyed by int; `@export` ammo fields on CastData; duck-typed seams unchanged; gate `tools/validate.sh`.
- **godot-runtime-smoke** — each slice adds a headless assert (one Gun; cast-swap; ammo decrement/regen/gate).
- **godot-fps-enemy-combat** — apply/damage seam untouched; no shootability change.

## Later
- Ammo pickups / overcharge crates per type.
- Cooldown-style charges (discrete pips) instead of continuous regen.
- Per-bullet trail/impact-VFX/SFX tint (currently mesh-tint only).
- New status `Effect` for stun/DoT (stun currently reuses Dmg+KB).
- Aim-down-sights tied to specific bullet types.
- 6th+ bullet (just author a `.tres` + add to `bullet_casts`).

## Open questions
None blocking. All decisions captured above; free-text override was empty.
