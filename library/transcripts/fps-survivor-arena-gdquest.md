# Create a Complete 3D Game (GDQuest survivor-arena FPS) — transcript digest
**Source** — `godot.md` (the raw, now in `transcripts/archive/godot.md`). GDQuest "your first complete 3D game" — a first-person survivor-arena shooter in Godot 4. Transcript ends before the mob-follow section (hosted off-video).
**Why harvested** — we are about to build a first-person shooter (FPS) POC in this project.

**Points**

| # | Point (technique/claim) | Valid for our stack? | Already learned? | Where / gap | Verdict |
|---|---|---|---|---|---|
| 1 | FPS player = `CharacterBody3D` + `CollisionShape3D` (capsule) + child `Camera3D` at eye height; camera child of body so yaw moves it, gun child of camera | holds with caveat — **perspective FPS camera conflicts with our orthographic fixed-angle rig** | gap | `godot-camera-rig` is orthographic-only and explicitly pushes back on perspective; nothing covers a first-person body+camera rig | conflicts (camera convention) + gap |
| 2 | Mouse-look: capture mouse (`Input.set_mouse_mode CAPTURED`), read `InputEventMouseMotion.relative` in `_unhandled_input`, yaw the body / pitch the camera, `clamp` pitch ±80°, release on `ui_cancel` | holds (input handling is renderer-agnostic) | gap | no skill covers `_unhandled_input` mouse-look / mouse-capture | gap |
| 3 | Camera-relative WASD ground movement: `Input.get_vector` → Vector3 on XZ → `transform.basis * dir`, set `velocity.x/.z`, `move_and_slide()`; gravity via `velocity.y -= g*delta`, jump on `is_on_floor()`, variable jump height by zeroing rising velocity on release | holds | gap | first-person/free-look movement controller not covered (we have no player-controller skill at all) | gap |
| 4 | Define input actions `move_*`, `jump`, `shoot` in the Input Map; prefer physical key codes | holds with caveat — our convention already defines move_/jump/cycle_level; this adds **`shoot`** (mouse click) and **mouse-look has no action** | partial | CLAUDE.md "Input actions" lists move_*, jump, cycle_level — `shoot` missing | partial (convention) |
| 5 | Projectile = `Area3D` + `CollisionShape3D` (sphere), moved each frame along `-transform.basis.z * speed * delta`, `queue_free()` past a max range; set `top_level` so it detaches from the camera | holds | gap | no spawn-move-despawn / projectile skill; `godot-composition` covers structure generically but not the projectile pattern | gap |
| 6 | Shooting: `preload` the bullet scene (loaded once), `instantiate()`, `add_child` to a `Marker3D` muzzle, copy `global_transform` from marker; fire-rate gate via a one-shot `Timer` + `is_stopped()` | holds | gap | instancing/spawn pattern + cooldown timer not covered by any skill | gap |
| 7 | Aim reticle = `TextureRect` (not Sprite2D) anchored center; 2D UI mixes freely over 3D | holds with caveat — our UI lives on the **persistent shell over the SubViewport**, not directly in the level (skill `godot-main-scene`) | partial | `godot-main-scene` owns the UI layer; reticle placement fits there but the FPS reticle itself isn't documented | partial |
| 8 | Lighting/look: `DirectionalLight3D` sun + `WorldEnvironment` ambient (warm fill vs blue bg) + **Filmic** tonemap + height fog | holds | covered | `godot-pixel-lighting` already prescribes sun + ambient + Filmic tonemap on the SubViewport Environment | covered |
| 9 | Prototype level with `CSGBox3D` (+ use_collision) and duplicate/scale boxes | holds with caveat — our greybox path is **flat-colour `BoxMesh` primitives / GridMap**, not CSG (CLAUDE.md art-kind table + `godot-gridmap-level`) | covered (different technique) | greybox/level tooling already prescribed; CSG is an alternative we deliberately don't use | conflicts (greybox technique) |
| 10 | Materials: `StandardMaterial3D` albedo + grayscale texture tint, UV1 scale, **triplanar** mapping for seamless tiling across boxes; `make unique`; save as `.tres` | holds with caveat — our walls/floors use tileable texture + `uv1_scale` sized to the face, **opaque, NEAREST/no-mipmap** import (pixel-art); triplanar is a non-pixel-art shortcut | covered | `godot-texture-import-pixel-art` (NEAREST, make-unique gotcha) + CLAUDE.md surface-texture row | covered |
| 11 | Resolution/stretch: set base viewport 1920×1080, **Stretch mode = viewport** to render 3D at a fixed lower res and upscale | holds with caveat — we already render 3D low-res, but via a **SubViewport downscale** (skill `godot-3d-pixelation`), not project stretch=viewport | covered | `godot-3d-pixelation` + `godot-project-conventions` own the low-res rendering path | covered |
| 12 | GLB models imported as read-only scenes; modify via **inherited scene**; `material_override` + `ShaderMaterial` (godotshaders.com) for the bullet trail | holds | covered | `godot-mesh-import-pixel-art` (inherited-scene/override workflow) + `godot-screen-effects`/`shaders/material/` contract | covered |
| 13 | Renderer = Mobile (tutorial default) | conflicts | covered | CLAUDE.md mandates **Forward+** (required by outline shaders) | conflicts (renderer convention) |
| 14 | Disable GDScript type hints to reduce cognitive load | conflicts | covered | CLAUDE.md mandates **strict typed GDScript** (`godot-code-rules`, `validate.sh`) | conflicts (code-rules convention) |

**Recommended next** — gaps the FPS POC needs now:
- First-person player controller (body + capsule + eye camera, mouse-look with capture/clamp, camera-relative move/jump) → **skill-researcher** (no `godot-*` skill covers an FPS/free-look player; note it must coexist with or override the orthographic `godot-camera-rig`).
- Projectile spawn → move → despawn + fire-rate Timer cooldown (preload/instantiate/add_child, `top_level`, `Area3D` hit detection) → **skill-researcher** (reusable shoot pattern, no skill covers it).
- Does an FPS POC override the orthographic-camera + 3D-pixel-art conventions, or do we want a perspective camera *inside* the SubViewport (pixelated FPS)? This is a real convention decision, not a code detail → **game-designer** (resolves before godot-dev builds; ties to points 1, 9, 11).
- Add `shoot` input action (mouse click) to the Input Map / CLAUDE.md convention line → orchestrator (convention edit), surfaced via game-designer scope.

**Later** (valid but not needed to stand up the FPS POC):
- Variable jump-height feel-tuning (point 3) — refine after the controller exists.
- Triplanar material mapping (point 10) — a non-pixel-art shortcut; only if seam issues appear on greybox.
- Mob-follow AI — out of this transcript (hosted off-video); harvest separately when we build enemies.
