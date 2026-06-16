# Art Direction — Firing Yard

**Look in one line** — gritty industrial tech-yard: cool grey steel + worn concrete, value-led, with sparse hazard-stripe and oxidised-rust accents. Muted, low-saturation, readable through the SubViewport downscale.

The problem this fixes: the yard currently reads as untextured greybox — flat `Color()` literals typed straight into `firing_yard.tscn` (walls `#404050`, floor `#141420`, primary-colour prop tags), none of it sourced from `ArtStyle`. This direction gives every surface a textured material identity from one palette so the boxes stop looking like boxes, and re-routes the prop tags to muted palette accents instead of raw primaries.

---

## Palette — new `ArtStyle` swatches

Add these to `tools/art_style.gd`. The existing domestic-interior groups (Wood / Plaster / Tile / Fabric) are **unused by this level** — leave them in place (other scenes may use them), but the firing yard maps onto the **new** groups below only. All values sit inside `[VALUE_MIN, VALUE_MAX]` and under `SATURATION_CEILING`.

### Steel (platforms, metal panels) — ramp dark → light
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `STEEL_DARKEST` | 0.18, 0.19, 0.22 | panel seam / shadow band |
| `STEEL_DARK` | 0.26, 0.28, 0.32 | base metal |
| `STEEL_MID` | 0.36, 0.38, 0.43 | lit face |
| `STEEL_LIGHT` | 0.48, 0.50, 0.55 | top highlight / edge |

### Concrete (walls, floor) — ramp dark → light, cool neutral
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `CONCRETE_DARKEST` | 0.16, 0.17, 0.20 | floor base (replaces `#141420`) |
| `CONCRETE_DARK` | 0.24, 0.25, 0.29 | wall shadow side |
| `CONCRETE_MID` | 0.32, 0.33, 0.38 | wall base (replaces `#404050`) |
| `CONCRETE_LIGHT` | 0.42, 0.43, 0.48 | wall lit face / scuff |

### Rust / oxidised metal (decorative props: barrels, crates)
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `RUST_DARK` | 0.30, 0.17, 0.11 | shadow / pitting |
| `RUST_MID` | 0.45, 0.26, 0.16 | body of a rusted barrel |
| `RUST_LIGHT` | 0.56, 0.36, 0.22 | rim highlight |

### Accents (zone tags — muted, NOT primaries)
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `HAZARD_AMBER` | 0.70, 0.46, 0.12 | id-1 rotating-hazard tag (was raw orange `#e06020`) — desaturated amber |
| `HAZARD_STRIPE_DARK` | 0.14, 0.13, 0.11 | the black of a yellow/black hazard stripe |
| `SIGNAL_TEAL` | 0.18, 0.42, 0.46 | id-2 wall-cling zone (was raw cyan `#208090`) — muted teal |
| `MARKER_PALE` | 0.50, 0.51, 0.50 | id-3 fake-wall passable markers (was `#909090`) — flat warm-grey, no texture so they read as "not real geometry" |

**Why these and not more.** Four material families (steel, concrete, rust) + three accents is the whole vocabulary. That is the constraint: the yard reads by **value** (near-black floor → mid walls → lighter platforms) with hue only carrying the two zone meanings (amber = hazard, teal = cling). Resist adding a fifth material or brightening the accents — saturation is deliberately held down so nothing competes with the targets/player for attention.

---

## Style scalars

Keep the existing scalars; one change.

| Scalar | Value | Why |
|---|---|---|
| `VALUE_MIN` | 0.16 | unchanged — floor base sits right at the floor; nothing pure-black |
| `VALUE_MAX` | 0.90 | unchanged — but nothing in *this* level's palette goes above ~0.55; the bright end stays reserved for highlights/targets so the yard stays moody |
| `SATURATION_CEILING` | **0.55 → 0.50** | nudge down: the industrial look wants greyer accents. Amber/teal tags must read as "tinted grey," not paint. (If other scenes rely on 0.55, leave it and just author the new swatches under 0.50 — they already are.) |
| `RAMP_SHADES` | 3 | unchanged — 3-band ramps per material give the pixel-art read |
| `TEXEL_DENSITY` | 32 | unchanged — walls/floor/platforms share one pixel scale |

---

## Mapping — surface / prop → swatch(es) + generator spec

godot-dev: generate these textures (`gen_textures.gd`) and props (`gen_models.gd`), then bind the textures to the existing scene materials (replacing the flat `Color()` literals) and swap the deco cubes for the props.

| Target in `firing_yard.tscn` | Current | New look | Generator spec |
|---|---|---|---|
| **Floor slabs** (FloorSlab0–18) | flat `#141420` | tileable worn concrete | texture `concrete_floor`: ramp `CONCRETE_DARKEST → CONCRETE_DARK → CONCRETE_MID`, faint expansion-joint grid lines at cell scale. `uv1_scale` so 1 tile ≈ 2 m (one cell). |
| **Walls** (GridMap `wall` tile) | flat `#404050` | tileable concrete panel | texture `concrete_wall`: ramp `CONCRETE_DARK → CONCRETE_MID → CONCRETE_LIGHT`, subtle vertical panel seams. Bind on the MeshLibrary tile mesh material (not the node). |
| **High + Mid platforms** | flat `#606070` | brushed steel deck | texture `steel_panel`: ramp `STEEL_DARK → STEEL_MID → STEEL_LIGHT`, horizontal brushed striations + corner bolt dots. Platforms read **lighter + cooler** than walls = clear height read. |
| **Ramps** | flat `#606070` | same `steel_panel` | reuse `steel_panel`; add a thin `HAZARD_AMBER`/`HAZARD_STRIPE_DARK` edge stripe at the ramp lip if cheap (walkway-edge marking) — optional. |
| **Hazard placeholder** (id-1, HazardPlaceholder) | raw orange `#e06020` | amber + hazard-stripe slab | recolour to `HAZARD_AMBER`; if textured, `hazard_stripe` texture (`HAZARD_AMBER` / `HAZARD_STRIPE_DARK` diagonal bands). Still reads "danger, don't stand here." |
| **Wall-cling zone** (id-2, WallClingA/B) | raw cyan `#208090` | muted teal panel | recolour to `SIGNAL_TEAL`; optional faint `steel_panel` underlay tinted teal so it reads as a special wall surface, not a flat decal. |
| **Fake walls** (id-3, FakeWall0–23) | `#909090` | flat `MARKER_PALE`, untextured | keep flat (no texture) on purpose — the absence of material texture signals "passable / not solid." |
| **Deco props** (id-6, DecoProp0–4) | flat olive `#4e5010` cubes | low-poly rusted barrels / crates | generate `barrel_rusted` (cylinder + rim rings, `RUST_DARK/MID/LIGHT` + `STEEL_DARK` bands) and `crate_metal` (box + edge-frame, `STEEL_DARK/MID` + `RUST_MID` corner). Instance ~3 of these in place of the 5 cubes; vary rotation. **This is the single biggest "personality" win.** |
| **Targets** (TargetA–D) | (entity scene — out of scope) | leave as-is | not this pass — flag for a later target-stand prop if desired. |

**Texel-density note:** all four textures author at `TEXEL_DENSITY = 32` px/m so wall/floor/platform pixels match. Platforms use a *finer* visual frequency (brushed lines) than walls (broad panels) — that contrast helps the eye separate climbable steel from cover concrete without changing density.

---

## Lighting mood

Hand to **`godot-pixel-lighting`** conventions. The yard already has a full **day/night sun cycle** in `firing_yard.gd` (sunrise warm → midday near-white → sunset orange → cool-blue moonlight). **Do not rewrite the cycle** — it's good and it's the level's signature. Two small tunes so the new muted palette reads:

- **Ambient floor at night** is already lifted (`AMBIENT_ENERGY_NIGHT = 1.0`) — keep it. With the darker concrete floor (`CONCRETE_DARKEST` ≈ 0.16) verify the night phase still shows the floor plane; if it crushes to black, lift `AMBIENT_ENERGY_NIGHT` to ~1.2 rather than brightening the swatch.
- **Tonemap** stays Filmic (`tonemap_mode = 1` on the Environment) — correct for this skill. Keep fixed exposure; do **not** add bloom/glow this pass (the design doc parks per-zone glow as Later). The muted accents are meant to read by hue at full lit value, not by emission.
- **Shadows** stay hard (`shadow_enabled = true`, the existing bias values) — hard shadows under the steel platforms are what sell the height/cover read. No change.
- **Sun colour** keyframes are fine against the cool palette; the warm sunrise/sunset against cool concrete is a deliberate, pleasing contrast — leave the keyframes.

Net: the cycle does the drama, the palette does the cohesion. They were designed to layer.

---

## Later

- Per-zone lighting accents (cyan `SIGNAL_TEAL` glow on id-2 cling zone, amber spot on id-1 hazard) — parked in the level design's Later; do after emission/glow is wired.
- Target-stand prop to replace the flat target geometry (kitbash `steel_panel` + `HAZARD_STRIPE`).
- Animated id-1 rotating hazard mesh (a steel arm) once the mechanic lands.
- Sourced (asset-advisor) low-poly props to replace the procedural barrels/crates if the placeholder look needs upgrading.
- Decal grime / scorch marks on the floor near targets (needs decal support).

---

## Open questions

None — both forks (mood = gritty industrial; props = textures + a few props) are confirmed. Brief is locked for the apply pass.
