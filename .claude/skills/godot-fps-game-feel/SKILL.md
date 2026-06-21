---
name: godot-fps-game-feel
description: >-
  A re-runnable game-feel + polish SWEEP for the DiceOfFate FPS POC (Godot 4.6) —
  the L3 human-judgement layer. Five measurable categories (game feel /
  input-feedback, VFX-SFX timing, performance headroom, input responsiveness &
  readability, audio presence), each with a concrete pass criterion so the sweep
  is a re-runnable checklist, not a vibe. Includes the weapon-feel specifics:
  recoil applied on fire, walk-vs-sprint view-model sway, ≥2 feedback channels
  per player action, weapon identity by feel. The researcher produces a DIFF vs
  this checklist → godot-dev fixes → re-verify. Use when a task asks to "polish",
  "make the weapon feel good", "improve game feel", "juice it up", "feel pass",
  "does it feel responsive", "audit feedback", or before an F5 milestone gate —
  and when judging whether shooting/moving/getting-hit reads and feels right. NOT
  a per-commit gate (that is validate.sh + godot-runtime-smoke), NOT the VFX
  implementation skills (godot-oneshot-vfx / godot-decal-vfx), NOT audio wiring
  (godot-audio), NOT the controller build (godot-first-person-controller) — it is
  the periodic SWEEP that audits whether those already-built systems feel right.
---

# Godot FPS game feel (periodic polish sweep)

Correctness (validate.sh) and runtime logic (godot-runtime-smoke) prove the game
**works**. They say nothing about whether it **feels good** — whether a shot has
weight, whether sprinting reads differently from walking, whether getting hit is
unmissable. That is a human-judgement layer (L3), and the failure mode is that it
gets done by vibe, inconsistently, and regresses silently. This skill makes the
feel pass a **re-runnable SWEEP**: a fixed set of categories, each with a
**measurable** criterion, so the loop is *researcher diffs the live build against
the checklist → godot-dev fixes the misses → re-run the same checklist*. It is the
merge of "weapon game feel" + "fps polish checklist" into one artifact — they were
two halves of the same sweep.

**This is NOT a per-commit gate.** Run it periodically — before an F5 milestone
gate, after a combat/movement system lands, or when a task explicitly asks to
polish. Per-commit correctness stays with validate.sh + godot-runtime-smoke.

## Requirements

- `godot-first-person-controller` applied — the sweep audits its sprint view-model
  / sway, crouch, mouse-look.
- `godot-oneshot-vfx` + `godot-decal-vfx` applied — the VFX channels being timed.
- `godot-audio` applied — the SFX channels being counted.
- `godot-fps-enemy-combat` + `godot-travelling-projectile-3d` applied — the
  fire/hit/died seams the feedback hangs off.
- Run mode: this sweep needs a **windowed** build (real F5 / a windowed run), NOT
  headless — feel, draw-call counts, and pipeline hitches only exist with a real
  RenderingDevice. (Headless reads draw-calls/pipeline = 0; see godot-runtime-smoke.)

## Project conventions

- Feedback hangs off the existing combat seams: `fired` / `hit` / `died` (weapon +
  enemy). Channels = the already-built systems: muzzle/impact/death VFX
  (`entities/vfx/`), scorch decals, fire/hit/death SFX (SFX bus), recoil + view-model
  on the controller, damage vignette (`godot-screen-effects`). The sweep audits
  these; it does not author new systems.
- Measurement tools, all windowed: the in-engine Monitor tab (FPS, draw calls,
  video memory), the existing windowed `tools/verify_render_action.gd`-style run for
  draw-call/pipeline counts, and direct ear/eye F5 observation for the human-only
  criteria. Record numbers, not adjectives.
- Output of a sweep = a **diff**: per category, PASS or the specific miss
  (what + where + the criterion it failed). godot-dev fixes only the misses, then
  the same checklist re-runs.

## Steps — the five categories (each has a measurable criterion)

Run all five against the live windowed build. For each, record PASS or the miss.

1. **Game feel / input-feedback — every player action has ≥2 feedback channels.**
   - Criterion: each of fire / hit-confirm / kill / take-damage drives **at least
     two distinct channels** (e.g. fire = muzzle VFX + SFX + recoil = 3; hit =
     hitmarker + impact spark; kill = death burst + kill-confirm SFX; damage =
     vignette + SFX). Count them. Fewer than 2 on any action = miss.
   - Weapon-feel specifics:
     - **Recoil applied on fire**: the view-model/camera visibly kicks on each
       `try_fire()` and recovers — not a static muzzle flash. (godot-runtime-smoke
       proves the recoil *value* changes; this proves it *reads* on screen.)
     - **Weapon identity by feel**: if more than one weapon exists, they must be
       distinguishable with eyes closed-ish — different fire cadence, recoil
       magnitude, or SFX. Two weapons that feel identical = miss.

2. **VFX-SFX timing — effect and sound land on the same frame as the seam.**
   - Criterion: muzzle flash + fire SFX trigger on the **same** `fired` emission (no
     perceptible lag); impact VFX + hit SFX on the `hit`; death burst + death SFX on
     `died`. A VFX that plays a frame or more after its sound (or vice-versa), or an
     effect that spawns at the wrong position (not the muzzle/impact point), = miss.
   - Death SFX not cut short: the death sound plays to its tail even though the enemy
     `queue_free()`s (the reparent-before-free pattern from godot-audio). A clipped
     death sound = miss.

3. **Performance headroom — steady 60 FPS, no first-spawn hitch.**
   - Criterion (windowed Monitor tab): sustained **≥ 60 FPS** during active combat
     (multiple enemies + projectiles + VFX on screen); **no frame-time spike** on the
     first muzzle flash / first death of a play session (the VFX warm-up in
     `vfx_router._warmup_vfx()` should have absorbed shader-variant compilation off
     the combat path). A visible stutter on first-spawn = miss → check warm-up covers
     that effect. Draw-call count stable, not climbing (leaked VFX) over a minute.

4. **Input responsiveness & readability.**
   - Criterion: mouse-look has no added smoothing lag (raw look); WASD + jump respond
     same-frame; sprint vs walk is **readable** — the **view-model lowers + swings**
     while sprinting and settles when walking (the controller's sprint "running feel"
     is visibly distinct from walk). A sprint that looks identical to walk, or input
     that feels mushy/delayed, = miss. The active reticle/crosshair and the hitmarker
     are visible against the scene (not lost on a bright wall).

5. **Audio presence.**
   - Criterion: spatial enemy SFX (AudioStreamPlayer3D) pan/attenuate with enemy
     position; fire/hit/death each have a sound on the SFX bus; overlapping shots do
     **not** cut each other off (enough poly / fire-and-free players); music (if any)
     loops seamlessly on the Music bus. Silence on any combat seam, or shots cutting
     each other, = miss.

## Verification checklist

Re-run after godot-dev fixes the misses — the sweep passes when ALL hold in a
windowed build:

- Every player action (fire / hit / kill / take-damage) fires ≥2 feedback channels;
  recoil visibly kicks + recovers on each shot.
- VFX and SFX for each seam land together, at the right position; death SFX plays its
  full tail.
- Monitor tab shows sustained ≥60 FPS in active combat; no first-spawn frame spike;
  draw calls stable over a minute (no leak climb).
- Sprint view-model is visibly distinct from walk; look/move/jump respond same-frame;
  reticle + hitmarker readable against the scene.
- Each combat seam has audible SFX; spatial enemy audio attenuates; overlapping shots
  don't cut.
- The sweep produced a written diff (PASS / specific miss per category), not a verdict
  of "feels good".

## Error → Fix

| Symptom | Fix |
|---|---|
| An action has <2 feedback channels | Add a channel off the same seam — VFX (godot-oneshot-vfx), SFX (godot-audio), or recoil/vignette; don't author a new system, reuse the built ones. |
| First muzzle flash / first death stutters | The effect isn't warmed up — ensure `vfx_router._warmup_vfx()` spawns that scene once off-screen on ready (Hidden-Node prewarm). |
| FPS drops over a minute of combat | VFX leaking in the remote tree — confirm one-shots free on `finished` (godot-oneshot-vfx) and decals recycle in the pool (godot-decal-vfx); watch draw-call count climb. |
| Death SFX cut short | Reparent the AudioStreamPlayer3D to a surviving node before the enemy `queue_free()`s (godot-audio despawn-SFX pattern). |
| Sprint feels same as walk | The sprint view-model lower/swing isn't wired — check godot-first-person-controller's sprint "running feel" is applied and tuned. |
| Sound + effect feel out of sync | Both must trigger on the SAME seam emission; don't drive SFX from a Timer and VFX from the signal — drive both from the signal. |
| Overlapping shots cut each other | Use fire-and-free AudioStreamPlayers (one per shot) instead of one re-triggered player (godot-audio). |
| Sweep keeps "passing" but build still feels off | A criterion is being judged by adjective, not measured — record the number (FPS, channel count, frame ms) and compare to the criterion. |

This is a game-local skill authored for DiceOfFate, merging the proposed
weapon-game-feel + fps-polish-checklist into one re-runnable sweep; no external
library source.
