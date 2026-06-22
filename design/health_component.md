# HealthComponent — shared health, player HP migration, shield + typed damage

**Goal** — One reusable `HealthComponent` node owns hit points for enemy/target/npc/player; player moves from a 3-lives model to a single HP pool with an HP bar; shield + 2 damage types prove the Cast extension. Player-visible: enemies still die in N shots; player has a draining HP bar instead of pips; FIRE damage can be resisted.

**Build method** — Pure GDScript + scene wiring; no GridMap/level work. `tools/lib/health_component.gd` is a child `Node` component (godot-composition: signals up / calls down). Parents keep their existing external signals as thin re-emitters so WaveManager + the Cast `DamageEffect` seam need ZERO changes in slice 1.

## Ground-truth seams (verified, do not break)
- `DamageEffect.apply()` calls `target.apply_damage(amount: int)` (duck-typed, `has_method` guarded).
- `on_hit()` aliases `apply_damage(1)` on enemy/target/npc (godot-fps-enemy-combat). Bare-projectile path.
- Enemy: `signal died(enemy: Enemy)`, `_health`, `_flash_hit()` / `_flash_and_die()`. WaveManager connects `died`.
- Player today: NO hp. `WaveManager._lives` (`lose_life()`/`add_life()`), enemy `touched_player` → `lose_life()` (= instant -1 life + `advance_level`). Pickup HEALTH → `WeaponController.health_pickup_requested` → `player._on_health_pickup_requested()` → `WaveManager.add_life()`.
- HUD: life pips (`_MAX_PIPS=3`, pulse ≤1), `flash_life_lost()`, stamina bar = ColorRect fill (reuse pattern for HP bar).

---

## Slice 1 — CORE component + enemy/target/npc dedup  *(independently shippable)*

**Scope (in)**
- New `tools/lib/health_component.gd`: `class_name HealthComponent extends Node`.
  - `@export var max_health: int = 2`; `var _current: int`; `_ready()` sets `_current = max_health`.
  - `signal died`; `signal health_changed(current: int, max_health: int)`.
  - `func apply_damage(amount: int) -> void` → clamp `_current` to ≥0, emit `health_changed`, emit `died` at 0 (guard once-only with a `_dead` bool so a second hit can't re-emit).
  - `func heal(amount: int) -> void` → clamp to `max_health`, emit `health_changed`.
  - `func get_health_percent() -> float`.
- Refactor `enemy.gd`: add child `HealthComponent` node (in `enemy.tscn`, `max_health` bound from existing `@export health`), connect `_health_comp.died` → existing `_on_died` that runs `_play_death_sfx`/`died.emit(self)`/`_flash_and_die`. `apply_damage(amount)` delegates to `_health_comp.apply_damage(amount)`; keep `on_hit()` → `apply_damage(1)`. **External `signal died(enemy)` unchanged.** Hit-flash: connect `health_changed` (non-fatal) → `_flash_hit`.
- Refactor `target.gd`: delegate (target = 1 HP, any damage kills → keep `queue_free`; can keep its trivial override OR use a 1-HP component — builder picks the smaller diff; component preferred for dedup).
- Refactor `npc.gd`: delegate `apply_damage` to component; component `died` → existing `_dead`/`wave_manager.lose_life()`/`died.emit(self)` path. Keep rescue flow untouched.
- Add `HealthComponent` node to `enemy.tscn`, `npc.tscn`, `target.tscn`.

**Scope (out)** — Player (slice 2); shield/typed damage (slice 3); regen, invuln frames, DoT (Later).

**Acceptance**
- `tools/validate.sh` passes (strict-typed, no warnings).
- godot-runtime-smoke `smoke_health_component.gd`: instance a `HealthComponent`, `apply_damage` past max → `died` emitted exactly once; `health_changed` arity = `(current, max)`; `heal` clamps to max.
- Existing `test_combat_integration.gd` / enemy smoke still green: shoot enemy N times → `died(enemy)` fires once, score awarded, no "Signal already connected".
- Human F5: shoot enemies in firing_yard — hit flash on non-fatal, death flash + SFX on fatal, exactly as before.

**Skill notes** — godot-composition (child component, signals up), godot-fps-enemy-combat (keep `on_hit`/`apply_damage`/`died(enemy)` contract), cast-system (`DamageEffect` untouched), godot-runtime-smoke.

---

## Slice 2 — Player HP migration (FULL HP replace, no lives)  *(depends on slice 1)*

> **Design note / scope flag:** user chose **full HP replace** — lives removed entirely. This is the heaviest slice: it deletes the `lose_life`/`add_life`/advance-on-touch flow and the level-swap-on-touch behavior. Touch no longer swaps levels; it deals damage. Recommend building it as the ordered sub-steps below so each is verifiable; if the diff feels too large for one task, split 2a/2b at the dispatch line.

**Scope (in)**
- Player gets a child `HealthComponent` (`max_health = 100`) in `player.tscn`. Player `apply_damage(amount)` delegates to it (player becomes a valid `DamageEffect`/`on_hit` target — future-proof).
- **Touch damage:** enemy `touched_player` no longer maps to `lose_life`. WaveManager `_on_enemy_touched_player` instead calls the player's `apply_damage(25)` (duck-typed, `has_method` guard, mirroring `bumped_player`→`apply_knockback`). Per-touch damage = **25** (4 touches to empty).
- **Death:** player `HealthComponent.died` → WaveManager ends the run. Replace `_lives <= 0` branch logic: player death = `run_lost.emit(_score)` directly. Player exposes `health_comp` or forwards `died` so WaveManager (or main.gd) connects it.
- **Remove lives model:** delete `_lives`, `lives`, `lose_life()`, `add_life()`, `lives_changed`, `life_lost`, `advance_level`-on-touch, `flash_life_lost` wiring. NPC death (`npc.gd` calls `wave_manager.lose_life()`) re-routes to player `apply_damage(<npc_penalty>)` (default 25) — keep NPC penalty as damage, not life loss. RunStateData.lives carry-over: drop (HP resets per level).
- **Health pickup:** reroute `_on_health_pickup_requested` → player `health_comp.heal(<amount>)` (default 40) instead of `WaveManager.add_life()`.
- **HUD:** add an HP bar (ColorRect fill, copy `set_stamina` pattern → `set_health(current, max)`); **remove life pips** + pip pulse + `flash_life_lost`. Low-HP feedback = bar turns red / pulse under 25%. Wire `health_comp.health_changed` → `hud.set_health` in main.gd.

**Scope (out)** — Shield (slice 3); damage vignette/screen-flash on hit (Later — godot-screen-effects); regen (Later).

**Acceptance**
- validate.sh green.
- smoke `smoke_player_health.gd`: boot a scene with player + WaveManager; simulate enemy touch → player `_current` drops by 25; 4 touches → `died` → `run_lost` emitted once. Health pickup `heal` raises `_current`, clamps to 100.
- Human F5: HP bar visible, drains on enemy contact (not instant death), bar empties → YOU DIE panel. Health crate refills bar. No pips on screen.

**Skill notes** — godot-composition, godot-fps-enemy-combat, godot-main-scene (HUD wiring under Main), godot-runtime-smoke. WaveManager loses its lives responsibility — keep it owning enemies/score only.

---

## Slice 3 — ShieldComponent + typed damage  *(depends on slice 1; independent of slice 2)*

> **lift-vs-build verdict:** **BUILD minimal ourselves** — do NOT lift cluttered-code v5. Its modifier pipeline/HurtBox/HitBox stack duplicates our Cast targeting (we already own `TargetResolver` + `DamageEffect`) and forces a name-seam rename. Our typed layer = one `enum` + one `int` field on `DamageEffect` + a resistance `Dictionary` on the component. ~20 lines vs adopting a 4-node addon. Park v5 as reference if DoT/modifier stacking ever lands.

**Scope (in)**
- **ShieldComponent** (separate node, per user): `tools/lib/shield_component.gd`, `class_name ShieldComponent extends Node`, `@export var max_shield: int = 0`; `_current_shield`; `func absorb(amount: int) -> int` returns overflow (damage not absorbed). `signal shield_changed(current, max)`. Sibling of `HealthComponent` on an entity. Entity `apply_damage`: if a `ShieldComponent` is present, `overflow = shield.absorb(amount)` then `health_comp.apply_damage(overflow)`. Opt-in: entities with no shield node behave exactly as slice 1/2.
- **Typed damage:** add `enum DamageType { PHYSICAL, FIRE }` (in `tools/lib/cast/damage_effect.gd` or a tiny shared const). `DamageEffect` gains `@export var damage_type: DamageType = PHYSICAL`. New overloaded path: `HealthComponent.apply_damage(amount, type := DamageType.PHYSICAL)` — keep the 1-arg form working (default PHYSICAL) so slice 1/2 callers and `on_hit()` are unchanged.
- **Resistance:** `HealthComponent` `@export var resistances: Dictionary` (type→float multiplier, default empty = ×1.0). `apply_damage` scales `amount` by `resistances.get(type, 1.0)` before subtracting. Prove with one entity (e.g. a tank variant) set `{FIRE: 0.5}`.
- `DamageEffect.apply`: if target's `apply_damage` accepts a type (check via a 2-arg call guarded), pass `damage_type`; else fall back to 1-arg. Keep `has_method` guard.

**Scope (out)** — More than 2 types; DoT/burn-over-time; shield regen; per-type VFX/HUD (Later). Resistance UI.

**Acceptance**
- validate.sh green.
- smoke `smoke_typed_shield.gd`: (a) component with `{FIRE:0.5}`, `apply_damage(10, FIRE)` → `_current` drops 5; PHYSICAL drops 10. (b) ShieldComponent `max_shield=20`, `absorb(30)` returns 10 overflow, shield → 0. (c) entity with both: 30 FIRE-resisted-0.5 damage vs 20 shield resolves correctly.
- Human F5: author a FIRE `CastData` `.tres` (or temp), shoot a fire-resistant enemy → takes ~half damage (more hits to kill); shielded enemy soaks first hits.

**Skill notes** — cast-system / godot-data-driven-effect-composition (new field on `DamageEffect`, no firing-path change), godot-composition (ShieldComponent sibling), godot-runtime-smoke.

---

## Later (parked)
- Damage vignette / hit screen-flash (godot-screen-effects).
- Health/shield regen, invuln frames, DoT/burn ticks.
- 3rd+ damage type, per-type impact VFX, resistance shown on HUD.
- cluttered-code v5 modifier pipeline — revisit only if stacking modifiers/DoT lands.
- BananaHolograma HealthComponent — revisit if regen + invuln + boss shield bars all wanted.
- RunStateData lives carry-over (removed in slice 2; HP resets per level).

## Open questions
- None block slice 1. Slices 2–3 carry defaults (NPC-death penalty 25, heal pickup 40, fire-resist 0.5) — builder may tune; flagged in-doc, not blocking.
