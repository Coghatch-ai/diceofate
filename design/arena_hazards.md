# Arena Hazards

**Goal** — The firing yard has hazards that actually do something: touching a marked danger floor, or being caught by a moving crusher, snaps the player back to spawn — same reset feel as the fake-wall fall and the enemy touch.

> Two slices, built and verified independently. Slice 1 (hazard floor) ships first — it reuses
> the proven FallZone reset pattern almost verbatim. Slice 2 (crusher) builds on the same reset
> hook and adds motion. Do NOT build both in one task.

## Context (what's there now)
- Three hazards exist in `levels/firing_yard.tscn`, but only the **fake-wall fall trap (id-3)** does
  anything (FallZone → respawn). The other two are inert colored boxes:
  - **id-1 `HazardPlaceholder`** — orange floor box, cols 5-8 rows 1-2 (~8×4 m, centre `Vector3(14,0.25,4)`). No collision, no effect. → **becomes the hazard floor (Slice 1).**
  - **id-2 `WallClingA/B`** — thin wall strips. → **CUT** (see Scope out).
- Reset path already exists and is the template: `levels/firing_yard.gd` `_on_FallZone_body_entered`
  → set `global_position = SPAWN_POS` (`Vector3(24,1,30)`), `rotation.y = SPAWN_ROT_Y` (PI), zero
  `velocity`. Player is in group `"Player"`, `collision_layer = 2`.
- Build method: extend the headless builder `scripts/build_firing_yard.gd` (`@tool extends SceneTree`,
  skill `godot-gridmap-level`) and re-run to regenerate `levels/firing_yard.tscn`. Never hand-author
  `.tscn` geometry/Transform3D. Reset handlers go in `levels/firing_yard.gd`.

## Roadmap fit
Hazards ride the **reset-on-touch** rail (Track C). Touch = teleport to spawn + print line. NO health,
NO damage bar, NO HUD, NO death VFX/audio — all explicitly out of POC scope. Both slices obey this.

---

## Slice 1 — Hazard floor (wire id-1)

**Goal** — Stepping onto the orange floor patch resets you to spawn.

**Scope (in)**
- Replace inert id-1 `HazardPlaceholder` mesh with a hazard zone: keep the same orange box as the
  **visual tell** (readable danger — feel = "punishing but fair"), plus an `Area3D` (`HazardFloor`)
  with a `BoxShape3D` covering the patch footprint (~8×4 m), thin in Y, top flush with the floor so
  standing on it triggers. `monitoring = true`; `collision_mask` includes layer 2 (player).
- Reset handler on `levels/firing_yard.gd`: `HazardFloor.body_entered` → reuse the exact
  `_on_FallZone_body_entered` logic (extract a shared `_reset_player(body)` helper; FallZone calls it
  too). Print one line e.g. `"[hazard] floor touched -> reset"`.

**Scope (out)**
- Damage/health — reset only, per rail.
- Animated/pulsing floor — readable static patch is enough; pulsing is Slice-2-adjacent, parked.
- Moving any other hazard — Slice 2.

**Acceptance**
- Re-run `scripts/build_firing_yard.gd` headless; regenerates `levels/firing_yard.tscn`, no push_error,
  project loads (no node-name clash).
- F5: orange patch visible; walking onto it teleports player to spawn facing −Z, able to move/fire
  again; print line fires. Fake-wall trap + enemy reset still work.
- `tools/validate.sh` passes on changed `.gd`.

---

## Slice 2 — Moving crusher (new hazard)

**Goal** — A block slides back and forth across one lane; getting caught by it resets you to spawn.

**Scope (in)**
- One crusher: a `StaticBody3D` (visible `BoxMesh`, distinct hazard color so it reads as dangerous)
  + a child `Area3D` (`CrusherHit`) box matching its footprint, mask layer 2. Placed in a clear
  open lane in the arena interior (builder picks an unobstructed lane off the navmesh-heavy areas;
  one cell-aligned start/end pair). Baked in the builder as computed positions, not hand Transform3D.
- Motion: a looping back-and-forth slide between two world points at constant speed, driven in
  `levels/firing_yard.gd` `_process` (lerp/ping-pong on the body's `position.x` or `.z`), OR a `Tween`
  set up in `_ready`. Builder authors start/end markers; the script moves it. Body collision blocks
  the player; the `Area3D` is what triggers reset (touch = caught).
- `CrusherHit.body_entered` → shared `_reset_player(body)` helper from Slice 1. Print
  `"[hazard] crushed -> reset"`.

**Scope (out)**
- Multiple crushers / rows of them — one proves it; more is a tuning copy-paste, parked.
- Crusher damaging/killing enemies — only affects the player (per rail; enemy interaction is its own design).
- Squash VFX / audio / screen shake — out of POC scope.
- Vertical stamping crusher — horizontal sweep is simpler to read + verify; vertical parked.

**Acceptance**
- Re-run builder headless; regenerates scene, no push_error, loads clean.
- F5: crusher visibly slides on a loop; its body blocks the player (can't walk through); standing in
  its path = caught = teleport to spawn. Slice 1 floor + fake-wall + enemy resets all still work.
- `tools/validate.sh` passes.

---

## Skill notes
- `godot-gridmap-level` — id-1 zone, crusher body/markers all baked as computed-position instances in
  the headless builder (not GridMap tiles, not hand Transform3D). Express the crusher as ONE block at
  its centre with start/end points — never a per-cell `×N` count.
- `godot-composition` — hazard Areas signal UP (`body_entered`) to the level root, which calls the
  shared `_reset_player` DOWN. Extract `_reset_player(body)` once; FallZone + both hazards call it.
- `godot-code-rules` — load before editing `scripts/build_firing_yard.gd` + `levels/firing_yard.gd`;
  strict typed GDScript; the `velocity` reset is the existing duck-typed SEAM (`@warning_ignore`).
- `godot-verify` — 3-layer gate per slice; plus: scene loads no clash, hazard Area present, F5
  touch→reset observed, existing resets intact.
- **Owner gotcha** (see builder `_add_targets` ~line 441): set `owner = scene_root` on freshly-`.new()`
  nodes you create; do NOT set owner on internal children of an instanced PackedScene.

## Later
- Pulsing/timed emitter hazard (rhythm) — parked from the interview.
- id-2 wall-cling revived if a climb/wall-run mechanic ever lands.
- Multiple crushers / vertical stamper / hazard reset VFX+audio (whoosh, flash) — pure polish.
- Hazards affecting enemies (push them into pits, etc.) — own design.

## Open questions
None blocking. Crusher exact lane + speed are builder/tuning choices within "one clear interior lane";
adjust on the F5 look.

## Scope (out) — both slices (cut & why)
- id-2 wall-cling hazard — needs a climb/wall-run mechanic the FPS POC doesn't have; an inert strip
  that kills on touch reads as a random death wall. Cut, parked.
- Health/damage/lives, HUD, win/lose, death VFX/audio — out of POC scope (Track C rail).
- Pit/spike-trench hazard — overlaps the existing fake-wall fall trap; low novelty. Not built.
