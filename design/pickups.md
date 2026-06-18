# Ammo & Health Pickups

**Goal** — Player walks over a floor crate to instantly refill the active gun's magazine (ammo crate) or gain +1 life (health crate); crates respawn on a timer so they're a recurring arena resource.

**Scope (in)**
- One reusable `entities/pickup/pickup.gd` (`Area3D`) + base `pickup.tscn`: `@export var kind: Kind` enum `{ AMMO, HEALTH }`, `@export var respawn_time := 15.0`, a `MeshInstance3D` (placeholder crate) and a `CollisionShape3D`.
- Two inherited scenes: `pickup_ammo.tscn` (ammo swatch crate) and `pickup_health.tscn` (health swatch crate). Kind set per scene; no per-scene script.
- Collect: on a body in group `player` entering, call duck-typed `body.collect_pickup(kind)`; if it returns `true` (something was consumed), play collect SFX, hide mesh + disable monitoring, start a one-shot `Respawn` Timer; on timeout re-show + re-enable. If `false` (no-op — see below), do NOT consume/hide/respawn.
- Player seam: `Player.collect_pickup(kind) -> bool` — AMMO routes to `_active_weapon.refill_ammo()`; HEALTH routes to the level's `WaveManager.add_life()`. Returns whether anything changed.
- Weapon seam: `Weapon.refill_ammo() -> bool` — if `_ammo >= ammo_max` return `false` (no-op, full mag); else set `_ammo = ammo_max`, emit `ammo_changed`, return `true`. No reserve pool; instant (NOT a reload — no timer/dip).
- WaveManager seam: `add_life() -> bool` — if `_lives >= lives` return `false` (no-op, at cap); else `_lives += 1`, emit `lives_changed(_lives)`, return `true`.
- Placement: 4 `PickupMarker*` `Marker3D` nodes on the arena floor in `firing_yard.tscn` (godot-dev chooses positions: spread across open lanes, on the navmesh, away from hazards) — 2 ammo + 2 health crates instanced at them. Markers near each other so a tour of the arena passes both kinds.
- One collect SFX (CC0, loop off, `SFX` bus) via the fire-and-free one-shot pattern; an `AudioStreamPlayer` on the pickup. Same clip for both kinds is fine.
- HUD updates ride the existing `ammo_changed` / `lives_changed` signals already wired in `main.gd`/`player.gd` — no new HUD code.
- Two placeholder crate models via `tools/gen_models.gd` (small box, ~0.4 m) — one tinted with a new `PICKUP_AMMO_*` swatch, one with `PICKUP_HEALTH_*`, added to `tools/art_style.gd`.

**Scope (out)**
- Reserve-ammo economy / ammo counter beyond the magazine — banned by roadmap; ammo crate is a magazine refill only.
- Granular HP / damage model — a life is the health unit (per Track G); health crate is +1 life, nothing finer.
- Inventory, pickup-to-carry, drop-on-death — not a pickup-collection game.
- Random/dynamic placement, weighted spawns, pickup waves — fixed markers + flat timer only.
- Particles / glow / float-bob VFX — out per roadmap VFX ban (the H7 muzzle light is the only sanctioned light). A static crate is enough; bob/spin parked.
- Sourced art — placeholder gen_models crate only.

**Acceptance** (observable F5 gate)
- Empty the pistol below full, walk onto an ammo crate → AMMO jumps to `12 / 12` instantly (no reload dip/timer), collect SFX plays, crate disappears, reappears ~15 s later.
- Walk onto an ammo crate with a FULL mag → nothing happens (crate stays, no SFX, no AMMO change).
- Take a hit to drop to LIVES 2, walk onto a health crate → LIVES rises to 3, SFX plays, crate disappears + respawns ~15 s later.
- Walk onto a health crate at LIVES 3 (cap) → nothing happens (crate stays, no SFX, no LIVES change).
- Swap to the rifle, empty it, grab an ammo crate → the **rifle's** mag (active weapon) refills, not the pistol's.
- `tools/validate.sh` clean; `godot-verify` all three layers pass (scenes load, smoke OK, render OK).

**Skill notes**
- `godot-composition` — base pickup + kind export (data-driven), signals up / calls down; pickup calls the player seam, player routes to weapon/manager. Modularize on demand only — one base + two inherited scenes, no hierarchy beyond that.
- `godot-procedural-model` + `godot-art-style` — placeholder crate meshes; add `PICKUP_AMMO_*` / `PICKUP_HEALTH_*` swatches to `art_style.gd` (do NOT re-type Color literals in the generator). Suggest: ammo = muted olive/brass, health = muted green/white-cross-free (a flat green swatch — no decal). Keep below `SATURATION_CEILING` unless flagged like the enemy ramps.
- `godot-audio` — collect SFX: `AudioStreamPlayer` on bus `SFX`, loop off, fire-and-free one-shot; NO AudioManager autoload. Pickup frees itself? No — it only hides/respawns, so no reparent-before-free needed (node survives the SFX tail).
- `godot-main-scene` — `main.gd` already finds `Player` + `WaveManager` in the loaded level; pickups need NO new main.gd wiring (they find the player via group, the player already holds the WaveManager-fed lives seam through the level). If the player can't reach WaveManager, inject it the same way the HUD is injected — prefer the group/find_child path to avoid touching main.gd.
- `godot-code-rules` — strict typed GDScript; `Player.collect_pickup` / `Weapon.refill_ammo` / `WaveManager.add_life` are typed `-> bool`. Duck-typed `body.collect_pickup` on the Area3D side guards with `has_method`.
- `godot-verify` — gate after the change; placeholder crate is non-final art (flag to verifier).

**Later**
- Crate bob/spin idle animation + soft glow once a VFX budget opens.
- Score-on-pickup / pickup streak.
- Random or wave-linked spawn positions; rarer/limited health crates.
- Partial-life or shield pickups if a granular HP model ever lands.

**Open questions** — none blocking.
