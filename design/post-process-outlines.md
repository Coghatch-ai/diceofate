# Post-Process Outlines

**Goal** — Dark pixel-art outlines appear at depth and normal discontinuities, giving the 3D scene a hand-drawn look.

**Scope (in)**
- New folder `res://shaders/post/` (project convention).
- New shader `res://shaders/post/post_process.gdshader` with depth/normal edge detection (single pass).
- New node `PostProcessQuad` (MeshInstance3D with 2x2 QuadMesh, flip faces on) as child of `CameraRig/Camera3D` in `entities/camera_rig/camera_rig.tscn`.
- ShaderMaterial on PostProcessQuad referencing the shader.
- Shader samples 4 neighbors (cross kernel), computes depth delta and normal dot, draws black when either exceeds threshold.
- Two uniform floats exposed: `depth_threshold` (default 0.5), `normal_threshold` (default 0.4). Tuning happens later, not in this slice.
- Renders inside SubViewport (before upscaling), so outlines are crisp single-pixel at internal 640x360.

**Scope (out)**
- Diagonal samples / 8-tap kernel — adds complexity, defer until basic outlines prove insufficient.
- Outline color customization — black only this slice.
- Outline thickness — single pixel; multi-pixel requires dilation pass (separate slice).
- Color grading, bloom, any second effect — one shader pass only.
- Sky masking — sky depth/normal is undefined; artifacts there are acceptable for POC.

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- entities/camera_rig/camera_rig.tscn` prints `VERIFY: OK`.
- `$GODOT --headless --path . --script tools/verify_render.gd -- 3` prints `RENDER: OK` (scene renders non-black).
- Smoke run (headless 3s, grep for ERROR) finds nothing.
- F5 run: basic_room geometry shows black outlines at cube edges and where floor meets walls. Outlines remain 1-pixel thick after window resize (they render at internal resolution).

**Skill notes**
- `godot-postprocess-quad`: follow exactly for MeshInstance3D setup (size 2x2, flip faces, cull margin 16384, POSITION snap in vertex()).
- `godot-screen-textures`: use exact uniform names (`depth_texture`, `normal_texture`) and helpers (`get_linear_depth`, `get_normal`). Pass `INV_PROJECTION_MATRIX` to helper. Use `filter_nearest` for pixel-art.
- Renderer is Forward+ (confirmed in CLAUDE.md) so `hint_normal_roughness_texture` is available.
- Quad lives inside SubViewport via the camera rig instance — effect applies before upscaling, which is correct.

**Later**
- Tune threshold values once more geometry exists.
- Outline color uniform (artist control).
- Multi-pixel outlines via dilation.
- Sky/background masking to avoid edge artifacts at infinity.
- Second pass for color grading or bloom.

**Open questions** — none.
