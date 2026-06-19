# Tech Debt — parked decisions

Durable record of deliberately-parked tech-debt items so they are not re-litigated.
Each: what + why parked + trigger to revisit. **Do not act on these without the trigger.**

**Source:** `library/verdicts/hermes-contract-findings-2026-06-19.md` (Hermes reusable-systems contract findings).

## Parked

### 1. Typed `@abstract class_name` hit contract
- **What** — replace the duck-typed `on_hit()` / `apply_knockback()` / `died`-signal seams with an abstract `HitReceiver`/`Damagable` base + `as` casts.
- **Why parked** — conflicts with our duck-typing skills (godot-composition r6, godot-code-rules SEAM, godot-fps-enemy-combat) and the "formalize on demand only" rule. Only 2 shootable types today (enemy + NPC); a shared `on_hit()` covers both with zero new abstraction.
- **Trigger** — a 3rd+ shootable entity type, OR an actual typo-bug from a misspelled seam method. Then it becomes a new skill (godot-hit-contract) or an addition to godot-fps-enemy-combat — NOT a CLAUDE.md line.

### 2. WeaponData / EnemyStats Resources
- **What** — move variant data out of `@export`-on-node / code subclasses into `.tres` Resources.
- **Why parked** — pays off only at designer-authoring / many-variant scale; today's `@export` + scene-inherited / `extends Enemy` subclasses work. Resource is an upgrade, not a correction.
- **Trigger** — ~5th weapon, OR many enemy stat variants, OR a non-programmer authoring stats.

### 3. WaveManager dependency injection — *cheap, endorsed (not a standalone task)*
- **What** — replace `find_child("WaveManager")` + `has_method("add_life")` with `@export var wave_manager` injected by the level root.
- **Why parked** — endorsed and squarely in our conventions (composition r5, DI); just not worth a dedicated task. **Autoload approach was rejected (anti-pattern).**
- **Trigger** — **do it when that WaveManager-wiring code is next touched** (NOT a standalone task).
