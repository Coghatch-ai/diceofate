# Review checklist — the L1 baseline gate (always-on)

The cheap, always-on review baseline godot-dev **self-checks before reporting "done"**, on every
diff. It is the L1 floor of the quality stack:

| Layer | What | Where |
|---|---|---|
| **L0 static** | format / lint / parse / warnings-as-errors / load+render | `tools/validate.sh` |
| **L1 baseline** | this checklist — cheap intra-file + cross-file hygiene, self-applied | **this doc** |
| **L1 deep** | fresh-session, diff-only, rubric review (Codex or Claude) | `code-reviewer` agent — escalate per the rule below |
| **L2 runtime** | headless logic/signal asserts | skill `godot-runtime-smoke` + `tools/smoke_*.gd` |
| **L3 feel** | windowed game-feel / polish sweep | skill `godot-fps-game-feel` |

This is a **convention, not an agent** — godot-dev reads it and self-checks; it costs nothing and
catches the cheap misses before they reach the gate or a reviewer. It does **not** replace
`tools/validate.sh` (run that too) — it catches what validate.sh's parse pass structurally can't
(e.g. a cross-file signal arity mismatch).

## The baseline items (self-check every diff before "done")

Intra-file hygiene (cheap, mechanical):

- [ ] **Strict typing**: every var/param/return typed; no implicit `Variant`; explicit return types
      (per godot-code-rules). No `UNTYPED_DECLARATION` / `UNSAFE_*` left unannotated.
- [ ] **`@export` over setter boilerplate** for inspector-tunable values.
- [ ] **`@warning_ignore` placement**: immediately above the exact line it covers, scoped to the one
      warning — never widened, never file-level, never used to silence a real issue.
- [ ] **No `push_warning` at scene-load** (a load-time warning fails the validate.sh smoke grep) and
      no stray `print` debug left in.
- [ ] **Comment length sane**; no `@abstract` (not used in this project's GDScript).
- [ ] **`.tscn` rules**: StaticBody3D / standalone MeshInstance3D are direct children of the root (no
      organisational Node3D groups); no `#` comments between `[node]` blocks (use `editor_description`);
      no banned `Transform3D` hand-authoring per godot-verify.

Cross-file contracts (the part validate.sh's per-file parse can't see):

- [ ] **Signal connect/emit arity match ACROSS files**: every signal you touched still matches EVERY
      `connect`/handler — arity AND payload type. A re-aritied `died(enemy)` that breaks a connect
      site parses fine per-file but breaks at runtime. Trace each touched signal to all its sites.
- [ ] **Idempotent connects**: reconnecting an already-connected signal throws "Signal already
      connected" — guard or `CONNECT_ONE_SHOT`/`is_connected` as the contract requires.
- [ ] **No new autoload** sneaking in for what should be a component (composition over autoloads).
- [ ] **No `change_scene_to_file`** — levels swap under `Main/LevelHost` (godot-main-scene).
- [ ] **Leaks**: spawned nodes `queue_free`d; one-shots free on `finished`; pooled slots recycle.

Then: **run `tools/validate.sh`** and include its output in the report. The checklist is the human
read; validate.sh is the machine enforcement.

## When to escalate to the `code-reviewer` agent (L1 deep)

The baseline is self-review — the author's context is poisoned by their own intent. Escalate to a
**fresh-session, diff-only** review by the `code-reviewer` agent when the diff is high-risk:

- touches a **cross-file contract** — a signal/callback consumed in more than one place (the combat
  contract: weapon ↔ projectile ↔ enemy);
- touches a **perf-sensitive path** (per-frame, VFX/decal spawning, physics);
- is **large or structural** (a refactor, a new system, many files);
- or the orchestrator/user explicitly asks for a deep review.

The orchestrator dispatches `code-reviewer` (it uses Codex when available, else reviews as Claude).
Routine small glue diffs that pass this baseline + validate.sh do **not** need the deep pass.
