# FPS Render-Rig Cleanup

**Goal** — The FPS renders through the player's first-person eye-camera at native window resolution, with the outline post-process visible, and the dead orthographic/pixel-art rig removed.

## Context (grounded, verified)
- `main.tscn:13-37` — render root is `SubViewportContainer` (`stretch_shrink=3`) → `SubViewport` (640×360) → holds `CameraRig`, `VfxRoot`/`ScorchPool`, `LevelHost`. HUD `CanvasLayer` already sits outside, direct child of `Main`.
- `camera_rig.tscn:19-28` — `CameraRig`'s `Camera3D` is **orthographic** (`projection=1`); `PostProcessQuad` (outline shader) is parented to that ortho cam → never shows on the FPS view.
- Player eye-cam = `WeaponController/Head/Camera3D` (perspective). `main.gd:60-64` already `make_current()`s it at runtime; ortho cam is inert but still in-tree.
- `CameraRig.target` never wired in `main.gd` → rig fully dead for FPS.
- Outline shader (`shaders/post/post_process.gdshader`) is Forward+, perspective-valid (`INV_PROJECTION_MATRIX`), correct folder — carries over to the FPS cam unchanged.

## Decisions (user, recorded)
1. Outline post-process — **keep, whole screen**; re-parent the quad to the FPS eye-camera.
2. Additional post-process (fog) — user picked light fog, but **parked** (see Later + Out): fog is a per-level WorldEnvironment edit on both levels and conflicts with `day_night_cycle.md` (which explicitly cut fog and animates the firing-yard Environment). Not part of this cleanup slice.
3. Native resolution — **yes**, remove the SubViewport downscale entirely.
4. `camera_rig.tscn`/`.gd` — **delete wholesale** after salvaging the PostProcessQuad.

## Scope (in)
- Remove `SubViewportContainer` + `SubViewport` from `main.tscn`. Re-parent `VfxRoot` (with `ScorchPool`), `LevelHost`, and the salvaged outline quad to be direct children of `Main`. HUD unchanged.
- Salvage `PostProcessQuad` (MeshInstance3D + its `ShaderMaterial` using `shaders/post/post_process.gdshader`, params `depth_threshold=0.5`, `normal_threshold=0.4`, QuadMesh `flip_faces`, `extra_cull_margin=16384`) — re-home it as a child of the player's eye-camera `WeaponController/Head/Camera3D` so it rides the active perspective cam. (Quad self-snaps to full screen via its vertex shader; one quad only.)
- Delete `entities/camera_rig/camera_rig.tscn` and `entities/camera_rig/camera_rig.gd`; remove the `CameraRig` instance + its ext_resource from `main.tscn`.
- Update `main.gd`: drop dead `CameraRig` references/comments (lines ~59); `%LevelHost` / `%VfxRoot` unique-name lookups must still resolve after re-parenting. Keep the player-cam `make_current()`.
- `tools/validate.sh` clean; native-res render verified.

## Scope (out)
- **Distance fog / vignette / any new post-process** — fog is a per-level WorldEnvironment change on both levels and collides with the firing-yard day/night driver; its own slice. Vignette earns its way in with damage feedback later.
- **Enemies-only outline** — needs a render-mask; separate slice if wanted.
- **Editing the outline shader** — it's perspective-correct as-is; no shader work.
- **Touching level WorldEnvironments / builder scripts** — cleanup is shell-only (`main.tscn`, `main.gd`, camera_rig deletion).

## Acceptance
- `godot-verify` (`tools/verify_render.gd`, scene's own camera): scene renders, non-black, no silently-dropped property; render target is full window size (no 640×360 downscale).
- One human F5: world looks crisp/native-res (no chunky pixelation); the black outline/edge effect is visible on geometry and enemies through the FPS view.
- `main.tscn` has no `SubViewportContainer`/`SubViewport`/`CameraRig` nodes; `entities/camera_rig/` is gone; no dangling ext_resource.
- `grep -r CameraRig` returns no live references in `main.gd`/`main.tscn`.
- `tools/validate.sh` clean; existing VFX (scorch pool one-shots) still spawn under `VfxRoot` after re-parent.

## Skill notes
- `godot-main-scene` — shell ownership: `VfxRoot`/`LevelHost`/post-quad become direct `Main` children; one current Camera3D per viewport (player cam). No `change_scene_to_file`.
- `godot-screen-effects` — the outline quad rig: single fullscreen quad, child of the **active** perspective camera; reads depth/normal/screen on Forward+.
- `godot-verify` — Transform3D ban + Sky-resource rule still apply to any `main.tscn` edit; mandatory before done.
- `godot-3d-pixelation` — being **removed** for this game; do not re-introduce the SubViewport.

## Later
- Distance fog (its own slice; per-level WorldEnvironment; reconcile with `day_night_cycle.md` first — that doc owns the firing-yard Environment).
- Enemies-only outline via render-layer/stencil mask.
- Damage vignette (with health/damage feedback).
- CLAUDE.md note: "Pixel-art SubViewport rig removed; FPS renders native. Post-process quad lives on the active first-person camera." (verifier/orchestrator owns the edit.)

## Open questions
None — ready to build.
