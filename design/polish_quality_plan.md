# Polish & Quality Plan — DiceOfFate FPS POC

> Decision-ready plan from Hermes research, reconciled with this project's conventions
> ("modularize/formalize ON DEMAND only"; duck-typing house style; strict typed GDScript +
> `tools/validate.sh` gate; composition over autoloads). Recommend-only — no game code or
> `.claude/` files written in this run. Per-recommendation verdict (with evidence) lives in
> `library/verdicts/polish-quality-eval-2026-06-19.md`. Adoption gated on the board question.

## The gap

Our gate proves **"loads + renders"**, not **"runs correctly / performs / feels right"**.

`tools/validate.sh` today = L0 static (format + lint + parse + warnings-as-errors) + a load/render
pass (`verify_scene.gd` instantiates every scene; a `--quit-after` smoke run flags ERROR/WARNING).
That catches: typos, type errors, dropped-invalid-property scenes, black-screen scenes. It does
**not** catch: a weapon that fires the wrong signal arity, recoil that never applies, an enemy that
takes damage but never emits `died`, a frame hitch on first mid-combat spawn, a regressed game-feel
value. Those only surface at human F5 today — expensive, late, non-repeatable.

Four layers close the gap; we already own the ends, the middle is thin:

| Layer | What | Status |
|---|---|---|
| **L0 static** | format/lint/parse/typing | HAVE — `validate.sh` |
| **L1 isolated review** | second pair of eyes, fresh context, structured rubric, diff-only | PARTIAL — Codex on-demand only |
| **L2 runtime smoke** | boot scene headless, drive a gameplay seam, assert state/signal | MISSING |
| **L3 user-play** | human F5 ear/eye-check | HAVE — roadmap gates |

## Load-bearing facts (verified against Godot 4.6.3 stable on this machine, not taken on faith)

1. **No "ubershader" project setting exists in 4.6.** Probed `ProjectSettings.get_property_list()`
   headless: zero `ubershader` keys. Forward+ ubershader behaviour is engine-internal (specialization
   constants), not a user toggle. Hermes's "enable ubershader in project.godot" is **factually wrong**
   for 4.6 — the real disk-side levers that DO exist:
   `rendering/shader_compiler/shader_cache/enabled` (+ compress/zstd/strip_debug) and
   `rendering/rendering_device/pipeline_cache/enable`. The runtime lever (already shipped) is the
   off-screen warm-up.
2. **`--headless` has NO RenderingDevice.** Probed: `RenderingServer.get_rendering_device() == null`,
   `pipeline_compilations == 0` after 5 frames — headless = dummy renderer. Consequence: an L2 smoke
   test asserting **gameplay logic** (signal emitted, correct arity, recoil applied, `died` fired,
   health decremented) runs fine headless (our existing smoke run already proves logic executes). An
   L2 test asserting **render/draw-calls/pipeline-count** does NOT work headless — needs a real
   window (the existing `tools/verify_render_action.gd` already opens one). So: split L2 — logic
   smoke = headless/CI; render/perf checks = windowed, human/F5 territory.
3. **GdUnit4 not installed** (only `addons/JehenoSimpleFPSWeaponSystem`). Adopting it = a real addon
   dependency + setup cost. Its SceneRunner *would* run headless for logic asserts (consistent with
   fact 2) but render-dependent asserts inherit the dummy-renderer limit.
4. **VFX warm-up already implements the "Hidden-Node prewarm" trick.** `entities/vfx/vfx_router.gd`
   `_warmup_vfx()` spawns every effect once at `Vector3(0,-9999,0)` on ready to force shader-variant
   compilation off the combat path. So a `godot-shader-precompile` skill would *formalize what we
   shipped*, not add new capability.

## Prioritized initiatives

Ordered by ROI for a POC. Each: what / why / cost / verdict / owner.

### 1. L2 runtime-smoke harness — WITHOUT GdUnit4 (extend our own tools) — ADOPT NOW (highest ROI)

- **What:** a headless `tools/smoke_*.gd` pattern (SceneTree script, like the existing
  `verify_enemy_ai.gd` / `test_combat_integration.gd`) that boots a scene, drives ONE gameplay seam
  programmatically (call `weapon.try_fire()`, emit a fake hit), and asserts observable state:
  signal fired with right arity, recoil applied, `died` emitted, score incremented. Wire it as a new
  step in `validate.sh` after the render pass.
- **Why:** closes the biggest gap (logic correctness) at the layer we're missing. We already have
  three ad-hoc scripts doing exactly this shape (`verify_enemy_ai.gd`, `test_combat_integration.gd`,
  `verify_render_action.gd`) — they prove the pattern works headless on 4.6. Formalizing them into a
  re-runnable template + a checklist of which seams to cover is the cheap win.
- **Cost:** low. No addon. One skill to author + 2-3 smoke scripts. Reuses validated infra.
- **Verdict:** **adopt now.** Prefer this over GdUnit4 — same logic-assert capability, zero new
  dependency, matches "formalize on demand" (we already have the scripts, just un-ad-hoc them).
- **Owner:** new skill `godot-runtime-smoke` (game-local first: `.claude/skills/`) +
  godot-dev authors the per-seam scripts. Verifier wires the validate.sh step.

### 2. GdUnit4 SceneRunner as the L2 path — REJECT (for the POC) / revisit later

- **What:** install GdUnit4 addon, use its SceneRunner for headless L2.
- **Why-not:** an addon dependency + learning curve for capability we already get from plain
  SceneTree scripts (fact 2/3). Its headline (render-dependent asserts) is exactly what headless
  *can't* do here. ROI negative at POC scale.
- **Cost:** medium (addon + CI wiring + maintenance).
- **Verdict:** **reject now.** Revisit if the smoke-script count grows past ~6-8 and we want
  fixtures/parametrization/reporting that hand-rolled scripts make painful. Parked.
- **Owner:** —

### 3. Review layer — baseline checklist gate (always) + per-task deep reviewer (Codex OR Claude-isolated) — ADOPT NOW

- **What (reconciles Hermes vs the user's steer):**
  - **Baseline (always-on, free):** a lightweight review **checklist** the orchestrator runs on
    every diff before "done" — a fixed rubric (convention conflicts, duck-type seam intact, typed,
    validate.sh green, no autoload sneak-in, no Transform3D ban break). An orchestration convention,
    not an agent.
  - **Deep review (per-task, chosen by user/orchestrator):** when warranted, a dedicated reviewer in
    a **fresh isolated session, diff-only input, structured rubric**. Use **Codex when available**;
    **ELSE a Claude-based review agent** (different context window, same rubric). Hermes wanted
    "Codex as a standing gate, no third model" — but Codex is NOT always available here, so we keep
    BOTH and pick per-task.
- **Why:** L1 isolation catches what self-review misses (the author's context is poisoned by their
  own intent). A fresh-session reviewer with diff-only input is a genuine different-eyes pass.
- **Cost:** baseline = ~free (a checklist doc). Deep = latency + tokens per invocation; gated to
  when the user/orchestrator asks — not every diff.
- **Decision — new agent or convention?** A NEW game-local review **agent** is warranted for the
  *deep* path (it needs its own isolated session + rubric prompt; that's an agent, not a one-liner).
  The *baseline* is a convention (a checklist file the orchestrator reads). Propose:
  - **Agent `code-reviewer` (game-local):** fresh session, input = diff only + the rubric, output =
    structured findings (blocking / nit / convention-conflict). Routes to Codex when present, else
    runs as a Claude review pass. Target: `.claude/agents/code-reviewer.md`.
  - **Checklist convention:** a short rubric doc the orchestrator applies pre-"done". Target:
    `design/review_checklist.md` (or a skill if it grows).
- **Verdict:** **adopt now** (baseline checklist + agent outline). Highest *correctness* leverage
  after L2, and cheap for the baseline half.
- **Owner:** orchestrator (baseline) + new `code-reviewer` agent (deep).

### 4. Perf follow-ups (Godot 4.6 code/config — NOT skills) — ADOPT a SUBSET NOW

These are godot-dev code/config tasks, separate from any skill:

| Item | Verdict | Note |
|---|---|---|
| `rendering/shader_compiler/shader_cache/enabled` = on | **adopt now** | The real disk-cache lever (ubershader toggle does NOT exist — fact 1). Verify current value, enable if off. Cheap, one project.godot line. |
| `rendering/rendering_device/pipeline_cache/enable` = on | **adopt now** | Pairs with shader_cache; persists compiled pipelines across runs. |
| Share `ParticleProcessMaterial` across same-look VFX | **adopt now** | Cuts pipeline permutations — directly fewer first-spawn hitches. Our 5 VFX scenes are candidates; audit for shared looks. |
| Check **Draw → pipeline-compilations monitor == 0** at steady state | **adopt now BUT windowed** | Can't be done headless (fact 2: monitor is 0 because no RD). Must be an F5/windowed check; fold into `verify_render_action.gd`'s existing real-window run. |
| #116228 re-spirv regression workaround | **defer/verify** | Confirm the regression actually affects 4.6.3 before applying a workaround for a maybe-fixed bug. Don't pre-emptively patch. |

- **Owner:** godot-dev (config + material sharing) + verifier (windowed pipeline-monitor check).

### 5. Proposed new skills (Hermes suggested four) — adopt 1, merge 2, reject/park 1

| Hermes skill | Verdict | Reasoning |
|---|---|---|
| `godot-runtime-smoke` | **adopt now** (= initiative 1) | Highest-ROI skill. Game-local first. |
| `godot-shader-precompile` | **defer / fold as a reference** | Would only *formalize* the shipped warm-up (fact 4) + the shader_cache/pipeline_cache config (initiative 4). No NEW capability. Capture the warm-up pattern as a section in an existing VFX skill OR a short skill later; don't author a standalone framework skill now for code we already wrote. |
| `godot-weapon-game-feel` + `godot-fps-polish-checklist` | **MERGE into ONE → `godot-fps-game-feel`** (adopt LATER) | Four skills is too many (Hermes flagged it). Game-feel categories + a re-runnable polish checklist are one re-runnable artifact, not two. Adopt LATER — after L2 + review land; game-feel is an F5/human judgement layer (L3), lower correctness-leverage than L1/L2. Game-local. |

**Net new artifacts proposed (author foreground after approval):**
- Skill `godot-runtime-smoke` (game-local) — adopt now.
- Agent `code-reviewer` (game-local) — adopt now.
- Convention doc `design/review_checklist.md` — adopt now.
- Skill `godot-fps-game-feel` (merged; game-local) — adopt later.
- (Parked: `godot-shader-precompile` as a reference section; GdUnit4.)

## Recommended first slice after approval (highest ROI)

**`godot-runtime-smoke` skill + the first smoke script + the validate.sh wiring.**
Concretely: a `tools/smoke_combat.gd` that boots `firing_yard.tscn`, calls `weapon.try_fire()`,
asserts the fire signal emits with correct arity AND a hit on an enemy emits `died` with the enemy
payload AND recoil state changed — then add it as a step in `validate.sh`. This converts the most
regression-prone seam (the combat contract that 6 of the recent commits touched) from
"F5-only" to "every commit", reusing the already-proven `test_combat_integration.gd` pattern.
Lowest cost, highest correctness leverage, no new dependency.
