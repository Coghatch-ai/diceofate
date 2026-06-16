# Firing Yard — Day/Night Sun Cycle

**Goal** — In the firing yard, a sun moves across the sky over a ~7-minute loop (sunrise → overhead → sunset → night → repeat), so the arena visibly cycles from warm bright day to cool dark-but-playable night.

## Placement
New atmosphere/polish scope, not in the current roadmap. Slots as **Track C — Atmosphere** (new short track) in `docs/roadmap/fps_poc.md`, after the SHOOTABLE gate and independent of Track B targets. The verifier owns adding/flipping the roadmap row; this doc is the first (and for now only) Track C slice. One godot-dev task.

## Scope (in)
- A **cycle driver script** on the level (`firing_yard.gd`, attached to the `FiringYard` root) that, in `_process`, advances a normalized day-time `t` (0..1) on a fixed period and drives the existing `Sun` `DirectionalLight3D` + `WorldEnvironment` already baked into `levels/firing_yard.tscn`. No new lights/nodes — it animates what's there.
- **Timing:** ~5 min daylight arc (sunrise→sunset) + ~2 min night = ~7 min full period. Loops forever. Starts at **sunrise** on level load. Expose period seconds as `@export` so it can be sped up for verification.
- **Sun rotation over the daylight arc:** pitch sweeps the sun from low at sunrise, through high overhead at midday, to low at sunset — a real arc so a low sun can shine toward the player (visual only). During night the sun is below the horizon (off / energy 0) and the moonlight floor takes over.
- **Brightness + colour arc (lerped each frame):** day = bright, neutral/warm; night = dark, cool blue. Drive `Sun.light_energy`, `Sun.light_color`, `Environment.ambient_light_color`, `Environment.ambient_light_energy`, and the sky colour so day is clearly bright/playable and night is clearly darker but **still readable** (moonlight floor — targets remain hittable). Keep Filmic tonemap + fixed exposure (no auto-exposure — it fights the pixel grid).
- **Colour targets:** warm sunrise/sunset (orange-ish low sun), neutral-bright midday, cool blue night. Smooth transitions, no hard pops between phases.
- All values authored as constants/exports in the driver script; the builder `scripts/build_firing_yard.gd` is updated to attach the script and leave the baked sun/env as the sunrise starting state.

## Scope (out)
- **Sun-in-eyes as a gameplay mechanic** (glare overlay, accuracy penalty) — cut; purely visual atmosphere this slice (user decision).
- **Near-black night** — cut; night keeps a moonlight floor so the shoot loop stays alive (user decision).
- **Moon disc, stars, clouds, fog, god rays, lens flare** — not needed for the cycle; park.
- **Per-level / shell-wide cycle** — driver lives on the firing yard only; not generalized into the shell yet.
- **Saving time-of-day, pausing the cycle, day-count** — not needed for an endless arena.

## Acceptance
Verify via `godot-verify` (`tools/verify_render.gd` — the scene's own camera, not the editor viewport) and one human F5:
- **Bright day renders:** at the midday point the scene is clearly bright/playable — measurably higher average luminance than the current static look (current avg ~0.026); targets and platforms plainly readable.
- **Dark-but-readable night renders:** at the night point average luminance is clearly lower than midday yet the four targets are still distinguishable/hittable (moonlight floor present, not near-black).
- **Sun angle changes over time:** sampling the scene at two different times shows the `Sun.rotation_degrees` (pitch) differ — the sun has visibly moved; at night the sun contributes ~no direct light.
- **Loops:** with the period temporarily shortened (e.g. export set low) a single F5 shows sunrise→midday→sunset→night→sunrise without a hard color/brightness pop or error.
- No black-screen, no silently-dropped Environment property (Sky background still references a real `Sky` resource), validate.sh clean.

## Skill notes
- **godot-pixel-lighting** is the base — same rig (one `DirectionalLight3D` sun, Sky/Color ambient, Filmic + fixed exposure, hard shadows). This slice **animates** that rig over time rather than the skill's static fixed angle. Keep shadows hard (no `shadow_blur`); keep exposure pinned (no auto-exposure).
- **godot-3d-pixelation** — the sun + WorldEnvironment being tuned are inside the SubViewport; readability is judged on the downscaled image.
- **godot-code-rules** — new `firing_yard.gd` must be strict typed GDScript; gate with `tools/validate.sh`.
- **godot-verify** — mandatory before done; luminance day-vs-night is the headline check.
- Build path: edit `scripts/build_firing_yard.gd` to attach the new `firing_yard.gd` and set the baked sun/env to the sunrise start state, then re-run the builder to regenerate `levels/firing_yard.tscn`. Do NOT hand-edit the generated .tscn.

## Later
- Sun-in-eyes glare as a real aiming-difficulty mechanic (own slice).
- Moon disc / stars / drifting clouds for night mood.
- Generalize the cycle into the shell so every level shares one time-of-day.
- Light-driven gameplay (targets only spawn at night, etc.).

## Open questions
None — ready to build.
