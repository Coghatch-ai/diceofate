# Open-World Grass — Showcase Level (Slice 1: static field)

**Goal** — A new open-world level reachable with Tab: the player walks a flat grass field with one placeholder tree, where the grass is a dense MultiMesh billboard field that renders correctly in the pixel-art SubViewport.

> **Roadmap note** — OFF the `first_game.md` roadmap (no foliage/showcase phase; Phases 6/7/8 are outlines/assets/characters). The transcript (`library/transcripts/shader-pixel-art.md`) marks every grass technique "Later". Treated as a **sanctioned shader R&D sandbox**, separate from the POC roadmap; does NOT advance any phase and must not be swapped into Phase-7 asset work.

**Scope (in)**
- New scene `res://levels/open_world.tscn`, root `OpenWorld` (Node3D), following `blockout_01.tscn` structure (DirectionalLight3D, WorldEnvironment with ProceduralSky + Filmic tonemap, instanced `Player` at a clear spawn).
- **Ground**: one flat `StaticBody3D` floor — BoxMesh ~40×0.2×40, BoxShape3D collider, green albedo. Open, no walls (player may walk off the edge — acceptable for a sandbox).
- **Tree**: one placeholder `MeshInstance3D` (cylinder trunk + sphere canopy, or a capsule) as set dressing. No collider, no glTF.
- **Grass**: one `MultiMeshInstance3D` — billboard `QuadMesh` blades, alpha-scissor cutout, shadow casting disabled, camera-facing. A spatial **material shader** (NOT a post-process quad). Static this slice — no wind, no animation, no displacement.
- **Population**: a small `GrassField` GDScript with `_ready()` fills the MultiMesh using a deterministic seed. Blade count and area exposed as `@export` vars. No baked transforms in the `.tscn`.
- Append `"res://levels/open_world.tscn"` to `_levels` in `main.gd`; Player wiring uses existing `find_child("Player")` unchanged.

**Scope (out)** — each a separate follow-up slice on the same shader once its skill lands:
- Noise-driven wind (skill `godot-foliage`, not yet built).
- Time quantization / low-framerate look (skill `godot-foliage`, not yet built).
- Player radial displacement (needs player position fed to shader; skill planned).
- Fake-perspective UV scaling (only matters once blades animate; bundle with wind slice).
- Real tree asset, ground texture, walls, more vegetation — Phase 7/later.

**Acceptance** (godot-dev runs `tools/validate.sh` + `godot-verify`; then human F5):
- `tools/validate.sh` passes (properties valid, scene loads headless).
- `godot-verify` render check: `open_world.tscn` renders non-black with visible geometry.
- F5 from Main, Tab to the open-world level: player stands on green ground; dense grass field of upright billboard blades (crisp pixels, no shadow under blades); one tree; player walks (WASD) and jumps; camera follows.
- Grass blades face the camera and don't render edge-on as the player circles them.

**Skill notes**
- `godot-foliage` (being written — gate this build on it existing in `.claude/skills/`) — spawn, billboard orientation, alpha-scissor. This slice cannot be built until it is adopted.
- `godot-3d-pixelation` — renders inside existing SubViewport (nearest, AA off); shader must read crisp at low res.
- `godot-camera-rig` — orthographic fixed angle; billboarding must account for no vanishing point (use camera basis, not look-at).
- `godot-pixel-lighting` — reuse `blockout_01`'s sun + Filmic Environment; grass disables shadow casting.
- `godot-main-scene` — swaps under `%LevelHost`; only edit is appending to `_levels`. Never `change_scene_to_file()`.
- `godot-verify` — hand-authoring .tscn rules (no Transform3D literal, Sky resource required) apply.
- `godot-code-rules` — GrassField GDScript must be strict typed; load before writing.

**Later**
- Wind slice (`godot-foliage`): two-noise non-repeating, rotate quads around wind-perpendicular axis.
- Quantization slice (`godot-foliage`): `mod` per-instance time phase shift, low-framerate look.
- Player-displacement slice: radial mask from player→blade distance; view-space axis split.
- Multi-character displacement: fixed `vec4[64]` + zero-radius sentinel + manager node.
- Hybrid smoothed toon shading (tension with hard-pixel lighting — revisit when characters are added).
- Cloud shadows via global shader var + `.gdshaderinc`.
- Real tree/ground assets (Phase 7).

**Open questions** — none blocking (roadmap framing and grass population confirmed by user).
