---
name: godot-art-style
description: Single source of truth for a 3D-pixel-art game's palette + visual style language in Godot 4.6 — a shared tools/art_style.gd const module of NAMED swatches and style scalars that both procedural generators (gen_textures.gd, gen_models.gd) preload() and read, so textures and models cohere by construction instead of drifting from hand-copied Color() literals. Use when placeholder art looks incoherent across textures/models, when the same colour is typed into more than one generator, before adding a new procedural texture/model spec, or when an art-director needs one place to set the look. NOT an asset-sourcing or import skill (that is asset-advisor / godot-mesh-import-pixel-art / godot-texture-import-pixel-art).
---

# Godot Art Style (one palette, one style language)

The procedural generators each hard-code their own colours: `tools/gen_textures.gd` inlines per-spec `PackedColorArray` palettes and `tools/gen_models.gd` declares its own `const WOOD_DARK = Color(0.36, 0.24, 0.14)`. They cohere today **only because the numbers were hand-copied to match** — `WOOD_DARK (0.36,0.24,0.14)` and `WOOD_MID (0.52,0.36,0.22)` are literally duplicated across both files. Edit one and the other silently drifts; there is nothing for the import skills or an art-director to point at.

The fix is one shared, named source of truth: a `tools/art_style.gd` const module (named swatches + a few style scalars) that **both** generators `preload()` and read by name. Then a texture's "wood" and a model's "wood" are byte-identical by construction, adding a spec means picking a named swatch (not eyeballing RGB), and the whole game's look has a single dial. This is the backing config for the art-director flow: the art-director's direction maps onto these named swatches/scalars, and godot-dev re-runs the unchanged generators.

## Requirements

- `godot-procedural-texture` — `tools/gen_textures.gd` is one of the two consumers; it reads swatches instead of inline palettes.
- `godot-procedural-model` — `tools/gen_models.gd` is the other consumer; it reads swatches instead of local `const` colours.
- `godot-code-rules` — `tools/art_style.gd` is strict typed GDScript: file header, typed `const`s, no `Variant`.

## Project conventions

- One module: `res://tools/art_style.gd`, `class_name ArtStyle`, a pure const container (no instance state). Both generators `preload("res://tools/art_style.gd")` and reference `ArtStyle.WOOD_DARK` etc.
- Swatches are `const ... : Color`. Style scalars are typed `const`s. Names are descriptive material+value (e.g. `WOOD_MID`, `TILE_GROUT`), not hex.
- A generator must NOT introduce a new inline `Color(...)` literal for a material that has (or should have) a named swatch — add the swatch to `ArtStyle` first, then reference it. Genuinely one-off accent colours may stay local but should be rare.
- This is the placeholder/style source of truth; sourced/final art still goes through the asset-advisor loop, but should respect the same palette + style language.
- ONLY godot-dev creates/edits `tools/art_style.gd` and the generators (it is game/tools code). This skill documents the pattern; the art-director agent emits direction that maps onto it.

## Seeded palette (extracted from the current generators)

The initial `ArtStyle` content, taken from the de-facto swatches already in use so nothing changes visually on first adoption:

| Group | Swatch | Color (r,g,b) |
|---|---|---|
| Wood | `WOOD_DARKEST` | 0.28, 0.18, 0.10 |
| Wood | `WOOD_DARK` | 0.36, 0.24, 0.14 |
| Wood | `WOOD_MID_DARK` | 0.45, 0.30, 0.18 |
| Wood | `WOOD_MID` | 0.52, 0.36, 0.22 |
| Wood | `WOOD_LIGHT` | 0.62, 0.46, 0.30 |
| Neutral | `METAL_GREY` | 0.55, 0.55, 0.58 |
| Neutral | `SHADE_CREAM` | 0.90, 0.86, 0.74 |
| Neutral | `LEAF_GREEN` | 0.30, 0.50, 0.25 |
| Plaster | `WALL_PLASTER_LIGHT` | 0.90, 0.87, 0.80 |
| Plaster | `WALL_PLASTER_MID` | 0.83, 0.79, 0.71 |
| Plaster | `WALL_PLASTER_DARK` | 0.74, 0.70, 0.62 |
| Fabric | `FABRIC_BLUEGREY_LIGHT` | 0.26, 0.38, 0.50 |
| Fabric | `FABRIC_BLUEGREY_MID` | 0.20, 0.30, 0.42 |
| Fabric | `FABRIC_BLUEGREY_DARK` | 0.16, 0.24, 0.34 |
| Tile | `TILE_LIGHT` | 0.70, 0.72, 0.74 |
| Tile | `TILE_MID` | 0.62, 0.64, 0.66 |
| Tile | `TILE_DARK` | 0.54, 0.56, 0.58 |
| Tile | `TILE_GROUT` | 0.30, 0.31, 0.33 |

Style scalars: `VALUE_MIN = 0.16`, `VALUE_MAX = 0.90`, `SATURATION_CEILING = 0.55`, `RAMP_SHADES = 3`, `TEXEL_DENSITY = 32`.

## Steps

1. Create `tools/art_style.gd`:

```gdscript
# tools/art_style.gd — single source of truth for the game's palette + style language.
# Both procedural generators preload this; never re-type a swatch's Color elsewhere.
class_name ArtStyle
extends RefCounted

# --- Swatches (named material+value, not hex) ---
const WOOD_DARKEST: Color = Color(0.28, 0.18, 0.10)
const WOOD_DARK: Color = Color(0.36, 0.24, 0.14)
const WOOD_MID_DARK: Color = Color(0.45, 0.30, 0.18)
const WOOD_MID: Color = Color(0.52, 0.36, 0.22)
const WOOD_LIGHT: Color = Color(0.62, 0.46, 0.30)
const METAL_GREY: Color = Color(0.55, 0.55, 0.58)
const SHADE_CREAM: Color = Color(0.90, 0.86, 0.74)
const LEAF_GREEN: Color = Color(0.30, 0.50, 0.25)
const WALL_PLASTER_LIGHT: Color = Color(0.90, 0.87, 0.80)
const WALL_PLASTER_MID: Color = Color(0.83, 0.79, 0.71)
const WALL_PLASTER_DARK: Color = Color(0.74, 0.70, 0.62)
const FABRIC_BLUEGREY_LIGHT: Color = Color(0.26, 0.38, 0.50)
const FABRIC_BLUEGREY_MID: Color = Color(0.20, 0.30, 0.42)
const FABRIC_BLUEGREY_DARK: Color = Color(0.16, 0.24, 0.34)
const TILE_LIGHT: Color = Color(0.70, 0.72, 0.74)
const TILE_MID: Color = Color(0.62, 0.64, 0.66)
const TILE_DARK: Color = Color(0.54, 0.56, 0.58)
const TILE_GROUT: Color = Color(0.30, 0.31, 0.33)

# --- Style scalars (the look's dials) ---
const VALUE_MIN: float = 0.16          # darkest a shade should go (keep silhouette readable)
const VALUE_MAX: float = 0.90          # brightest (avoid blown highlights in the SubViewport)
const SATURATION_CEILING: float = 0.55 # limited-palette feel; no neon
const RAMP_SHADES: int = 3             # shades per material ramp (pixel-art banding)
const TEXEL_DENSITY: int = 32          # px per metre for tileable surface textures
```

2. Refactor `tools/gen_models.gd`: delete its local colour `const`s, `preload("res://tools/art_style.gd")`, and replace each `Color(...)` with the matching `ArtStyle.<SWATCH>`.
3. Refactor `tools/gen_textures.gd`: replace inline per-spec `PackedColorArray` palette literals with arrays built from `ArtStyle` swatches; drive shade count off `ArtStyle.RAMP_SHADES` and tiling off `ArtStyle.TEXEL_DENSITY` where applicable.
4. Regenerate both: re-run the generators headless, then `$GODOT --headless --path . --import`.
5. Gate: `tools/validate.sh`, then `godot-verify` — the regenerated placeholders must render identically to before this refactor (same colours, now sourced from one place).

> Adding a new material later: add the swatch(es) to `ArtStyle` FIRST, then reference the name in the generator spec. Never re-type a `Color(...)` a second generator will also need.

## Style language (the look this palette serves)

- **Limited palette, value-led.** Materials read by VALUE contrast, not hue — keep saturation under `SATURATION_CEILING`. Silhouette and readability through the SubViewport downscale come first.
- **Banded ramps.** Each material is ~`RAMP_SHADES` discrete shades (dark → mid → light), not a smooth gradient — that is the pixel-art read.
- **Value range clamped.** Stay within `[VALUE_MIN, VALUE_MAX]`; nothing pure-black (kills silhouette) or pure-white (blows out under Filmic tonemap).
- **Consistent texel density.** Tileable surfaces author at `TEXEL_DENSITY` px/m so walls/floors share a pixel scale.

## Verification checklist

- [ ] `tools/art_style.gd` exists, is `class_name ArtStyle`, strict-typed, and `validate.sh` passes.
- [ ] Both generators `preload` it; neither contains an inline `Color(...)` for a material that has a named swatch.
- [ ] Regenerating both produces visually identical placeholders to before the refactor (the seed values match what was hand-copied).
- [ ] Changing one swatch in `ArtStyle` and regenerating changes that material in BOTH a texture and a model (single source of truth proven).
- [ ] No duplicated colour literal remains across the two generators (grep for `Color(0.36, 0.24, 0.14)` etc. returns only `art_style.gd`).

## Error → Fix

| Symptom | Fix |
|---|---|
| Texture "wood" and model "wood" don't match | A generator still has an inline `Color(...)` — replace with `ArtStyle.WOOD_*` |
| `class_name ArtStyle` collides | Name is project-unique; rename only if a real clash exists, update both `preload` references |
| Placeholders changed appearance after the refactor | A swatch was mistyped vs the seed table — diff against the Seeded-palette values above |
| Want to restyle the whole game | Edit `ArtStyle` swatches/scalars once + regenerate; do NOT touch the generators' logic |
| New material needs a colour | Add the named swatch to `ArtStyle` first, then reference it — never inline it in the generator |

---

Authored in-house for DiceOfFate (no external skill fit). Seed palette extracted from `tools/gen_textures.gd` + `tools/gen_models.gd`.
