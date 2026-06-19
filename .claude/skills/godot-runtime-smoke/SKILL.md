---
name: godot-runtime-smoke
description: >-
  The L2 runtime-smoke layer for the DiceOfFate FPS POC (Godot 4.6) WITHOUT
  GdUnit4 — a headless SceneTree tool script (`tools/smoke_*.gd`, run via
  `$GODOT --headless --script`) that boots a real scene, drives ONE gameplay
  seam programmatically (call `weapon.try_fire()`, simulate a hit), and ASSERTS
  runtime outcomes that the static gate and render-snapshot miss: a signal
  emitted with the correct ARITY/payload, a method actually invoked (recoil
  applied), health decremented, `died` fired, no leak. Wires as a step in
  `tools/validate.sh` after the smoke run. Use when a task touches a gameplay
  seam whose correctness validate.sh can't prove — "the weapon fires the wrong
  signal arity", "recoil never applies", "enemy takes damage but never emits
  died", "assert a signal fired", "headless integration test", "smoke test the
  combat contract" — or when a regression slips past lint+parse+render because
  the logic is wrong, not the syntax. Reuses the proven
  `tools/test_combat_integration.gd` pattern. NOT the render/draw/pipeline-count
  checks (those need a real window — godot-verify layer 3 /
  `verify_render_action.gd`), NOT the load-and-renders gate (godot-verify), and
  NOT a feel/polish sweep (godot-fps-game-feel).
---

# Godot runtime smoke (L2 — headless logic asserts)

`tools/validate.sh` proves a scene **loads + renders** (L0 static + a `--quit-after`
smoke run that flags ERROR/WARNING). It does NOT prove the game **runs correctly**:
a weapon that emits the wrong signal arity, recoil that never applies, an enemy that
takes damage but never emits `died`, a regressed feel value — all pass L0 and only
surface at human F5. The L2 layer closes that gap by booting a real scene headless,
driving ONE gameplay seam from code, and **asserting observable state**. The pattern
is already proven on this repo by `tools/test_combat_integration.gd` /
`tools/verify_enemy_ai.gd` — this skill un-ad-hocs it into a re-runnable template +
a checklist of which seams to cover, and wires it as a gate step. No GdUnit4, no
addon: a plain `SceneTree` script gives the same logic-assert capability with zero
new dependency.

## Requirements

- `godot-code-rules` applied — the smoke script is strict typed GDScript and must
  pass the same `validate.sh` format/lint/parse it gates.
- `godot-verify` understood — this is layer **2.5**: it sits between the L2 smoke
  run and the L3 windowed render check, and it asserts logic the others can't.
- The seam under test must be **callable from code** (a public `try_fire()`,
  a `died` signal, an `on_hit()` duck-typed method). If a behaviour is only
  reachable through real physics-overlap between two separately-added nodes, the
  headless cache won't populate it synchronously — assert the **code path** the
  overlap would call instead (see the "headless caveat" below), and leave the true
  overlap to F5.

## The headless caveat (split logic vs render — load-bearing)

Verified on Godot 4.6.3, this machine:

- `--headless` has **NO RenderingDevice**: `RenderingServer.get_rendering_device() == null`,
  and `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` /
  `pipeline_compilations` read **0** — it's the dummy renderer.
- Therefore an L2 smoke test asserting **gameplay logic** (signal emitted, correct
  arity, recoil applied, health decremented, `died` fired, score incremented,
  node freed) runs fine headless. THIS skill.
- An L2 test asserting **render / draw-calls / pipeline-count / pixels** does NOT
  work headless — it needs a real window. That is godot-verify layer 3 /
  `tools/verify_render_action.gd` (which opens a window). Do NOT put a draw-call or
  pipeline-monitor assert in a `tools/smoke_*.gd` — it will read 0 and either falsely
  pass or falsely fail.

**Split rule:** logic/signal/state asserts → headless `smoke_*.gd` (gated in
validate.sh). Render/perf/pipeline asserts → windowed run (verify_render_action,
F5 territory).

Headless physics also does **not** process overlap detection synchronously between
two separately-added nodes within a few frames. If your seam depends on
`get_overlapping_bodies()` / `body_entered`, assert the method it *would* call
(`_apply_hit(enemy)`) directly via the duck-typed seam — exactly as
`test_combat_integration.gd`'s stationary-overlap test does — and prove the code path
exists/is callable, leaving the real overlap to F5.

## Project conventions

- Path/name: `tools/smoke_<seam>.gd` (snake_case), e.g. `tools/smoke_combat.gd`.
  `extends SceneTree`. One file per gameplay seam family; keep it focused.
- Run: `$GODOT --headless --path . --script tools/smoke_<seam>.gd`. Exit **0** = all
  asserts passed, **1** = any failure (`quit(1 if _fail_count > 0 else 0)`).
- Drive at **frame 3** (not 1): frame 1 = nodes added + `_ready()`; frame 2 = physics
  server first tick; frame 3 = overlaps/state populated. Use a `_frame` counter in
  `_process` and a `_done` guard so the body runs once.
- Scenes under test live in their domain folder (`res://entities/...`,
  `res://levels/firing_yard.tscn`). Load with `load(path) as PackedScene`,
  `instantiate()`, `root.add_child(...)`; `queue_free()` every spawn at the end so the
  smoke leaves no leak (validate.sh's leak greps still apply).
- Private-field reads (`_health`, `_swing_active`) are a **test SEAM**: read via
  `e.get("_health") as int`, set via `node.set("_swing_active", true)`; annotate the
  duck-typed call site with `@warning_ignore("unsafe_method_access")` /
  `("unsafe_cast")` exactly per godot-code-rules — never widen warning levels.
- Input actions for seam-driving: `move_left, move_right, move_forward, move_back,
  jump, cycle_level`. Fire/recoil/hit are driven by calling the entity's own methods,
  not by faking `Input`.

## Steps

1. **Pick the seam + the observable.** What changed that L0 can't see? For the combat
   contract: fire emits a signal with the right arity; a hit on an enemy emits `died`
   with the enemy payload; recoil state changed on the weapon. Each observable = one
   assert.

2. **Scaffold the SceneTree script.** Counters + frame-gated entry, mirroring the proven
   base:

   ```gdscript
   # tools/smoke_combat.gd — headless L2 smoke: weapon fire + hit/kill contract.
   # Run: $GODOT --headless --path . --script tools/smoke_combat.gd
   # Exit 0 = all pass, 1 = any failure.
   extends SceneTree

   const FIRING_YARD := "res://levels/firing_yard.tscn"

   var _pass_count: int = 0
   var _fail_count: int = 0
   var _frame: int = 0
   var _done: bool = false


   func _initialize() -> void:
       print("=== COMBAT SMOKE ===")


   func _process(_delta: float) -> bool:
       _frame += 1
       if _frame == 3 and not _done:
           _done = true
           _run_all()
       return false


   func _run_all() -> void:
       _test_fire_signal_arity()
       _test_hit_emits_died()
       _test_recoil_applied()
       print("\n=== RESULTS: %d pass / %d fail ===" % [_pass_count, _fail_count])
       quit(1 if _fail_count > 0 else 0)
   ```

3. **Use the reusable assert helpers** (copy verbatim — the proven `_pass`/`_fail` shape):

   ```gdscript
   func _pass(msg: String) -> void:
       _pass_count += 1
       print("  PASS: %s" % msg)


   func _fail(msg: String) -> void:
       _fail_count += 1
       print("  FAIL: %s" % msg)


   func _assert(cond: bool, msg: String) -> void:
       if cond:
           _pass(msg)
       else:
           _fail(msg)
   ```

4. **Assert a signal fired with the correct ARITY/payload.** Capture into a one-element
   array from a lambda (closures can't reassign a captured local, but can mutate an
   Array element — the proven idiom):

   ```gdscript
   func _test_hit_emits_died() -> void:
       var e := _spawn(GRUNT_SCENE) as Enemy
       if e == null:
           _fail("grunt failed to spawn")
           return
       # arity check: died(enemy) — payload must be the enemy that died.
       var got: Array = [0, null]  # [count, last_payload]
       e.died.connect(func(en: Enemy) -> void:
           got[0] = (got[0] as int) + 1
           got[1] = en)
       e.on_hit()  # health=1 grunt: fatal
       _assert(got[0] == 1, "died emitted exactly once on fatal hit")
       _assert(got[1] == e, "died payload is the enemy (correct arity/payload)")
       if is_instance_valid(e):
           e.queue_free()
   ```

   A wrong arity (a builder changes `died` to `died()` or `died(enemy, score)`) breaks
   the `connect`/emit at runtime and this assert catches it — validate.sh's parse pass
   does not.

5. **Assert a method actually ran (recoil applied).** Read the observable state the
   method mutates, before and after:

   ```gdscript
   func _test_recoil_applied() -> void:
       var w := _spawn(WEAPON_SCENE)
       if w == null or not w.has_method("try_fire"):
           _fail("weapon missing try_fire()")
           return
       var before := w.get("_recoil_offset")  # SEAM: private state read
       @warning_ignore("unsafe_method_access")
       w.try_fire()
       var after := w.get("_recoil_offset")
       _assert(after != before, "recoil offset changed after try_fire (recoil applied)")
       if is_instance_valid(w):
           w.queue_free()
   ```

6. **Spawn helper + cleanup.** Free everything; leave no leak.

   ```gdscript
   func _spawn(path: String) -> Node:
       var packed := load(path) as PackedScene
       if packed == null:
           push_error("Failed to load: %s" % path)
           return null
       var inst := packed.instantiate()
       root.add_child(inst)
       return inst
   ```

7. **Wire it into `tools/validate.sh` as a new step AFTER the smoke run (step 5).**
   `tools/` is the plugin-materialized gate — do NOT hand-edit it in the game repo
   (the edit is gitignored + overwritten on re-materialization). Report this wiring to
   the verifier / orchestrator to promote upstream. The step has the shape:

   ```bash
   # 6. runtime smoke (godot-verify layer 2.5) — logic asserts; exit 1 = fail
   for s in tools/smoke_*.gd; do
       if ! "$GODOT" --headless --path . --script "$s"; then
           fail "runtime-smoke — $s"
       fi
   done
   echo "validate: PASS runtime-smoke"
   ```

   Glob `smoke_*.gd` so new seams auto-join the gate. Each script self-reports
   pass/fail counts and sets the exit code; validate.sh only needs the exit code.

## Verification checklist

- Run `$GODOT --headless --path . --script tools/smoke_combat.gd` directly →
  prints `=== RESULTS: N pass / 0 fail ===` and exits 0.
- Deliberately break the seam (rename `died` arity, comment out the recoil mutation)
  → the matching assert prints `FAIL:` and the script exits 1. (A smoke test that
  can't fail proves nothing.)
- `tools/validate.sh` now prints `validate: PASS runtime-smoke` between
  `PASS smoke` and `validate: OK`.
- The smoke run adds no new leak lines to validate.sh's leak greps (every spawn
  `queue_free`d).
- No render/draw-call/pipeline assert lives in any `smoke_*.gd` (those are windowed).

## Error → Fix

| Symptom | Fix |
|---|---|
| Asserts run before state populated (signals never connected, overlaps empty) | Drive at `_frame == 3`, not 1 — frame 1 is only `_ready()`. |
| `pipeline_compilations` / draw-call assert reads 0 and always passes/fails | Headless has no RenderingDevice — move that assert to a windowed `verify_render_action`-style run. |
| `get_overlapping_bodies()` empty for two separately-added nodes | Headless physics doesn't sync overlap in a few frames — assert the method the overlap would call (`_apply_hit`) directly via the duck-typed seam. |
| Lambda "Cannot assign to captured local" | Capture a one-element `Array` and mutate `arr[0]`, don't reassign the local. |
| `UNSAFE_METHOD_ACCESS` / `UNSAFE_CAST` fails parse | Annotate the duck-typed seam call with `@warning_ignore("unsafe_method_access")` / `("unsafe_cast")` immediately above it; never lower warning levels. |
| Script exits 0 even though the seam is broken | The assert reads a value that's true regardless — assert the *delta* (before != after) or the exact payload, not mere "not null". |
| New leak lines appear in validate.sh smoke greps | `queue_free()` every spawned node at the end of each test; check `is_instance_valid` first. |
| Editing `tools/validate.sh` doesn't persist | `tools/` is plugin-materialized + gitignored — don't hand-edit; report the step to the verifier to add upstream. |

This is a game-local skill authored for DiceOfFate from the project's own proven
`tools/test_combat_integration.gd` / `tools/verify_enemy_ai.gd` pattern; no external
library source.
