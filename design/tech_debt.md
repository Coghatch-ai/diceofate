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

### 4. Windowed / Xvfb render-error gate — *for the NEXT POC version*
- **What** — a verify run under a REAL renderer (windowed on macOS, or Xvfb on Linux CI) that captures render-path engine errors during scene load.
- **Why parked** — it is the ONLY way to auto-catch the render-path error class (e.g. `material_casts_shadows: material is null` on a shadow-caster) — that code path never executes under the `--headless` dummy renderer, so no headless gate can see it. Deferred for the POC: needs a provisioned display, slower + flakier runs, platform-specific. We already ship the cheap 90% (headless `smoke_scene_errors.sh` catches parse / `SCRIPT ERROR` / name-clash / non-render) and added the `cast_shadow=0`-on-material-less rule to the godot-verify contract.
- **Trigger** — next POC version / before any export/release build (a windowed smoke run is the correct pre-ship check), OR if render-path null-material/shadow errors recur.
- **Source** — `library/verdicts/runtime-testing-eval-2026-06-19.md` (rec 3).

### 5. GdUnit4 test framework — *good finding, parked not wasted*
- **What** — adopt the GdUnit4 addon (Scene Runner + assert matchers) instead of hand-rolled `extends SceneTree` smoke/bot scripts.
- **Why parked** — our needs (boot scene, drive input, assert signals/state) are met by ~50–80 lines of hand-rolled scripts using the SAME engine primitives GdUnit4 uses internally; it adds an installed/version-tracked dependency + a full test-framework worldview, and its 4.6 headless reliability is unverified. Rejected for now, NOT discarded — the evaluation (incl. the headless PR #115 detail) is preserved in the verdict.
- **Trigger** — smoke suite grows past ~5 timeline scripts, OR we need rich matchers (assert_signal_emitted_with_args, fixtures) beyond the handful we'd hand-write.
- **Source** — `library/verdicts/runtime-testing-eval-2026-06-19.md` (rec 4) — the durable record; this is where it lives so it is not re-researched.
