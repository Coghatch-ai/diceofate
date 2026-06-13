# Importing pixel-art textures onto 3D models in Godot — transcript digest
**Source** — `godot-import-pixel-art.md` (raw now in `transcripts/archive/godot-import-pixel-art.md`). YouTube tutorial: applying a pixel-art tileset to a 3D cube (Blender → FBX → Godot), dev of "Lone Knight".
**Why harvested** — about to build `godot-texture-import-pixel-art` skill (.import sidecar + `StandardMaterial3D.texture_filter` enum + `filter_nearest` shader hint + `assets/textures/` convention). Known bug to prevent: `texture_filter = 3` (NEAREST_WITH_MIPMAPS) used where `1` (NEAREST) was meant.

**Points**

| # | Point (technique/claim) | Valid for our stack? | Already learned? | Where / gap | Verdict |
|---|---|---|---|---|---|
| 1 | A pixel-art texture imported onto a 3D mesh renders **blurry by default** — the material's texture sampling must be set to nearest, not linear-mipmap. | holds — this is the exact problem the skill targets | partial | asset-sources.md states "Filter = Nearest, Mipmaps = Off" as a directive; no skill explains the *mechanism* or the material-side enum | gap |
| 2 | In Godot's material inspector the sampling/filter field is **grayed out** until you `make unique` both the imported mesh resource *and* the surface material (open as inherited scene, make-unique the mesh, then the surface_0 material). | holds — real Godot 4.x gotcha for `.glb`/`.fbx`-imported materials | not learned | nothing covers imported-scene material editing; this is the practical blocker | gap |
| 3 | Once unique, set the material sampling from "Linear Mipmap" to **Nearest** for crisp pixels (per surface). | holds — maps directly to `StandardMaterial3D.texture_filter`; correct enum = `1` NEAREST, the trap value `3` NEAREST_WITH_MIPMAPS still re-blurs at distance | partial | the value lives in CLAUDE.md asset loop as prose; the `1` vs `3` enum trap (the recent bug) is undocumented | gap |
| 4 | Set the in-Blender image node interpolation to **Closest** before exporting (so the source mesh carries nearest intent). | holds with caveat — Blender step is upstream of our pipeline; we don't author meshes in Blender for blockout, and Godot's import/material settings are authoritative regardless of the Blender node | out of scope (for the skill) | n/a — Blender-side, not a Godot setting we control | out of scope |
| 5 | Export FBX with **custom properties kept** and **+Z forward** (not -Z) so textures/orientation import correctly into Godot. | holds with caveat — only relevant if/when we import external FBX/GLB; orthographic fixed-angle camera makes axis orientation matter | not learned | no model-import-pipeline doc; not needed for current SubViewport blockout build | out of scope (now) |
| 6 | Delete the default Blender startup cube/camera/light and add a fresh cube — the default cube carries "bad" leftover data; lights/cameras pollute the import. | unverifiable folklore; Godot import dialog lets you exclude lights/cameras anyway | not learned | n/a — Blender hygiene, not our stack | out of scope |
| 7 | Per-face material assignment via Smart UV / Cube Projection in Blender to get correct pixel scale per face. | out of scope — Blender UV workflow | n/a | n/a | out of scope |

**Verification note (the recent bug):** the video's "set sampling to Nearest" is the material-inspector path; the equivalent the build got wrong is `StandardMaterial3D.texture_filter`. Correct value is `1` (TEXTURE_FILTER_NEAREST); `3` is `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`, which *looks* nearest but re-introduces mipmap blur at distance/glancing angles — exactly the regression the skill must lock out. The video does NOT cover the `.import` sidecar (`mipmaps/generate=false`, `compress/mode=0`) at all — that half of the skill comes from elsewhere.

**Recommended next**
- Build the `godot-texture-import-pixel-art` skill → **skill-researcher**. Genuine gap (points 1–3): no current skill covers per-texture import settings, the `StandardMaterial3D.texture_filter` enum (`1` NEAREST vs the `3` NEAREST_WITH_MIPMAPS trap), or the imported-mesh "make unique" gotcha. The video supplies the material-inspector workflow and the make-unique gotcha; researcher should pair it with the `.import` sidecar keys (`mipmaps/generate=false`, `compress/mode=0`) and the `filter_nearest` shader-sampler hint to make the skill whole.

**Later**
- Model-import pipeline (FBX/GLB export axis = +Z forward, keep custom properties) — points 4/5. Park until we actually import external 3D models; current builds are SubViewport blockout, not imported art.
