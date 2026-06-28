# Art Direction — HD Asset-Import Direction (standard-HD FPS)

**Look in one line** — muted-industrial, value-led, cool; **stylized-PBR** (real PBR maps, but
flattened — high roughness, low metal, mild normals) so the existing limited palette stays
dominant and combat readability never loses to gloss. This is the import-direction call that
unblocks the HD asset push; the palette identity itself is unchanged (see `art-direction-enemy.md`).

This is a **POC moving from a 3D-pixel-art prototype to a standard-HD FPS.** This doc decides ONLY
how sourced HD `.glb`/textures import and shade. It does **not** retire the placeholder-art pipeline
(`gen_textures.gd` / `gen_models.gd` keep their flat-shade path) and does **not** delete any skill —
the HD path is a NEW sibling alongside the pixel-art import skills, each used where it applies.

---

## The decision (import settings — the gate)

For **sourced HD assets** (real `.glb` models + their textures, tileable surface textures):

| Setting | Decision | Why (FPS + perf) |
|---|---|---|
| **Texture filter** | **LINEAR** (`texture_filter` = Linear w/ mipmaps; Godot import `Filter = On`) | First-person stands right next to walls at grazing angles; NEAREST aliases/stair-steps HD detail and crawls when the camera moves. |
| **Mipmaps** | **ON** (`mipmaps/generate = true`) | Mandatory for HD. Without mipmaps, oblique/distant surfaces shimmer; mipmaps also recover perf (fewer texel fetches at distance). |
| **Material** | **Full PBR `StandardMaterial3D`** — wire all maps a source ships: albedo / metallic / roughness / normal / AO (`ORMMaterial3D` when channel-packed) | Real assets ship these maps; flat-albedo discards work you already have and breaks lighting consistency across assets. |
| **Look bias (stylized-middle)** | Push **roughness high**, **metallic low**, **normals mild**; keep albedo within the palette's value/saturation language | Keeps the muted-industrial palette reading over gloss; forgiving of mixed-source assets; combat stays readable. NOT photoreal-realism, NOT flat-toon. |
| **Normal maps** | OpenGL-style → **invert-Y on import** when a source is DirectX-style; smooth-map (inverted roughness) → invert before import | The S3 traps; wrong-handed normals light "inside-out." |
| **Albedo color space** | sRGB; **non-color** (linear) for normal / roughness / metallic / AO | Standard PBR correctness; a roughness map read as sRGB shades wrong. |

**Placeholder generators are unchanged** — `gen_textures.gd` keeps NEAREST + `mipmaps=false`
(flat pixel placeholders), `gen_models.gd` keeps flat `albedo_color`. The two paths coexist: flat
placeholders for prototype gaps, stylized-PBR for sourced finals. They cohere because **both read
the same `ArtStyle` palette** (below) — same hues/values, different import tech.

---

## Palette — unchanged; `ArtStyle` stays the single source of truth

No swatch or scalar changes this pass. The HD direction is import tech, not a re-palette. Sourced
assets must **respect the existing `tools/art_style.gd` language** so a sourced concrete wall and a
generated concrete placeholder read as the same material:

- Surfaces/props live within `SATURATION_CEILING = 0.50`, value range `[0.16, 0.90]`.
- Map sourced albedo to the nearest existing swatch family (concrete → `CONCRETE_*`, steel →
  `STEEL_*`, rust props → `RUST_*`, wood → `WOOD_*`, wall → `WALL_PLASTER_*`).
- Enemy/threat hues keep their documented saturation exceptions (crimson/orange/violet/cyan/acid).
- **Stylized-middle means:** when a sourced albedo is louder/glossier than the palette, dial it
  toward the swatch — push roughness up / metallic down — rather than admitting a new bright hue.

---

## Style scalars — note for HD

| Scalar | Value | HD note |
|---|---|---|
| `VALUE_MIN` / `VALUE_MAX` | 0.16 / 0.90 | Unchanged. PBR + Filmic tonemap already clamp highlights; keep albedo inside this range so AO/shadow have headroom. |
| `SATURATION_CEILING` | 0.50 | Unchanged. The stylized bias enforces it on sourced albedo too. |
| `RAMP_SHADES` | 3 | N/A to PBR-shaded surfaces (real gradients); still governs flat placeholders. |
| `TEXEL_DENSITY` | 32 px/m | **Now a floor, not a ceiling.** Sourced HD textures will exceed 32 px/m — keep them *consistent* across surfaces (one density family) so walls/floors share a scale; tune `uv1_scale` to match. |

---

## Mapping — which path each asset kind takes

| Asset kind | Path | Filter / mipmaps / material |
|---|---|---|
| Sourced prop / furniture `.glb` (greybox→asset swap) | HD mesh-import (new sibling skill) | LINEAR + mipmaps; PBR StandardMaterial3D, stylized bias; nested-instance (NOT inherited), auto-gen collider + Make-Unique |
| Sourced tileable surface texture (wall/floor) | HD texture-import (new sibling skill) | LINEAR + mipmaps; PBR maps; `uv1_scale` for density match |
| Placeholder texture (`gen_textures.gd`) | Existing pixel-art path | NEAREST + no-mipmap (unchanged) |
| Placeholder model (`gen_models.gd`) | Existing procedural path | flat albedo (unchanged) |
| Enemy/pickup kitbash | Existing procedural path | flat albedo, `ArtStyle` swatches (unchanged) |

---

## Lighting mood

No change required by this pass; `godot-pixel-lighting` already lands the FPS rig (Filmic +
fixed exposure + hard sun + sky/color ambient). Two HD nudges for **godot-dev / godot-pixel-lighting**:

- PBR surfaces react to ambient and reflection — verify the muted palette doesn't go muddy now that
  roughness/metal are live; tune `ambient_light_energy`, not the swatches.
- Keep **Filmic + fixed exposure** (no auto-exposure, no ACES/AgX) so live PBR highlights don't
  bloom past the clamped value range. An HD lighting re-tune (SSAO, reflections) is a separate Later
  sweep, not this pass.

---

## CLAUDE.md change recommended (orchestrator / godot-dev makes the edit)

This is a recommendation; I do not edit CLAUDE.md. The change is **additive** — it resolves the
open decision and adds the HD path WITHOUT deleting the pixel-art path (per the user: each skill
goes where it applies).

1. **Lines 27–28 (the open-decision NOTE):** replace the "open art decision pending" wording with
   the resolved call:

   > **Sourced HD assets** import with **LINEAR filter + mipmaps ON** and shade via **full PBR
   > `StandardMaterial3D`** (albedo/metallic/roughness/normal/AO; `ORMMaterial3D` when packed),
   > biased **stylized-flat** (high roughness, low metal, mild normals) to keep the muted palette
   > dominant. Normal maps invert-Y if DirectX-style; non-color space for non-albedo maps. The
   > NEAREST / no-mipmap pixel-art import rows below apply ONLY to the **procedural placeholder
   > generators** (`gen_textures.gd` / `gen_models.gd`), which keep that path.

2. **Line 42 (the "Large flat surface" row):** for **sourced** textures, point at the new HD
   texture-import skill (LINEAR + mipmaps + PBR) instead of `godot-texture-import-pixel-art`; leave
   the `gen_textures.gd` placeholder reference on the pixel-art skill.

3. **Discrete-prop row:** for **sourced** `.glb`, point at the new HD mesh-import skill; leave the
   `gen_models.gd` placeholder reference as-is.

Net: pixel-art import skills survive (placeholder generators), HD sibling skills own sourced finals.

---

## Later

- HD lighting re-tune sweep (SSAO, reflection probes, env reflections) — separate pass.
- Per-material density audit once several HD surfaces ship (lock one texel-density family).
- Decal/normal detail on hero surfaces.
- Consider whether `ArtStyle` should gain a small set of PBR scalar defaults (roughness floor,
  metal ceiling) so the stylized bias is enforced in config, not by eye — park until 2nd HD surface.

---

## Open questions

None — the aesthetic fork (stylized-middle) was answered; import settings decided. Apply pass is unblocked.
