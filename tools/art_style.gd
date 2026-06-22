# tools/art_style.gd — single source of truth for the game's palette + style language.
# Both procedural generators preload this; never re-type a swatch's Color elsewhere.
class_name ArtStyle
extends RefCounted

# --- Swatches (named material+value, not hex) ---

# Wood ramp: darkest → lightest
const WOOD_DARKEST: Color = Color(0.28, 0.18, 0.10)
const WOOD_DARK: Color = Color(0.36, 0.24, 0.14)
const WOOD_MID_DARK: Color = Color(0.45, 0.30, 0.18)
const WOOD_MID: Color = Color(0.52, 0.36, 0.22)
const WOOD_LIGHT: Color = Color(0.62, 0.46, 0.30)

# Neutral / accents
const METAL_GREY: Color = Color(0.55, 0.55, 0.58)
const SHADE_CREAM: Color = Color(0.90, 0.86, 0.74)
const LEAF_GREEN: Color = Color(0.30, 0.50, 0.25)

# Plaster (wall) ramp: light → dark
const WALL_PLASTER_LIGHT: Color = Color(0.90, 0.87, 0.80)
const WALL_PLASTER_MID: Color = Color(0.83, 0.79, 0.71)
const WALL_PLASTER_DARK: Color = Color(0.74, 0.70, 0.62)

# Fabric (blue-grey) ramp: light → dark
const FABRIC_BLUEGREY_LIGHT: Color = Color(0.26, 0.38, 0.50)
const FABRIC_BLUEGREY_MID: Color = Color(0.20, 0.30, 0.42)
const FABRIC_BLUEGREY_DARK: Color = Color(0.16, 0.24, 0.34)

# Tile ramp: light → dark + grout
const TILE_LIGHT: Color = Color(0.70, 0.72, 0.74)
const TILE_MID: Color = Color(0.62, 0.64, 0.66)
const TILE_DARK: Color = Color(0.54, 0.56, 0.58)
const TILE_GROUT: Color = Color(0.30, 0.31, 0.33)

# Steel (platforms, metal panels) — ramp dark → light
const STEEL_DARKEST: Color = Color(0.18, 0.19, 0.22)  # panel seam / shadow band
const STEEL_DARK: Color = Color(0.26, 0.28, 0.32)  # base metal
const STEEL_MID: Color = Color(0.36, 0.38, 0.43)  # lit face
const STEEL_LIGHT: Color = Color(0.48, 0.50, 0.55)  # top highlight / edge

# Concrete (walls, floor) — ramp dark → light, cool neutral
const CONCRETE_DARKEST: Color = Color(0.16, 0.17, 0.20)  # floor base
const CONCRETE_DARK: Color = Color(0.24, 0.25, 0.29)  # wall shadow side
const CONCRETE_MID: Color = Color(0.32, 0.33, 0.38)  # wall base
const CONCRETE_LIGHT: Color = Color(0.42, 0.43, 0.48)  # wall lit face / scuff

# Rust / oxidised metal (decorative props: barrels, crates)
const RUST_DARK: Color = Color(0.30, 0.17, 0.11)  # shadow / pitting
const RUST_MID: Color = Color(0.45, 0.26, 0.16)  # body of a rusted barrel
const RUST_LIGHT: Color = Color(0.56, 0.36, 0.22)  # rim highlight

# Accents (zone tags — muted, NOT primaries)
const HAZARD_AMBER: Color = Color(0.70, 0.46, 0.12)  # id-1 rotating-hazard tag
const HAZARD_STRIPE_DARK: Color = Color(0.14, 0.13, 0.11)  # black of hazard stripe
const SIGNAL_TEAL: Color = Color(0.18, 0.42, 0.46)  # id-2 wall-cling zone
const MARKER_PALE: Color = Color(0.50, 0.51, 0.50)  # id-3 fake-wall passable markers

# Enemy crimson ramp: dark → light.
# Documented exception above SATURATION_CEILING — threats must read over muted-industrial palette.
const ENEMY_CRIMSON_DARK: Color = Color(0.34, 0.06, 0.10)  # body shadow / lower legs
const ENEMY_CRIMSON_MID: Color = Color(0.56, 0.10, 0.14)  # main body (torso, arms)
const ENEMY_CRIMSON_LIGHT: Color = Color(0.74, 0.16, 0.18)  # chest "core" + head highlight
const ENEMY_ARMOR_DARK: Color = Color(0.10, 0.09, 0.11)  # head, hands, feet — near-black accent

# Enemy runner orange ramp: dark → light. Documented exception above SATURATION_CEILING — threat
# must read as distinct from crimson grunt at a glance (fast/dangerous read).
const ENEMY_RUNNER_DARK: Color = Color(0.38, 0.18, 0.06)  # body shadow / lower legs
const ENEMY_RUNNER_MID: Color = Color(0.62, 0.30, 0.08)  # main body (primary swatch)
const ENEMY_RUNNER_LIGHT: Color = Color(0.80, 0.44, 0.12)  # chest highlight

# Enemy tank steel-violet ramp: dark → light. Documented exception above SATURATION_CEILING —
# cool/heavy hue reads as "armoured"; clearly distinct from crimson grunt and orange runner.
const ENEMY_TANK_DARK: Color = Color(0.22, 0.18, 0.32)  # body shadow / lower legs
const ENEMY_TANK_MID: Color = Color(0.36, 0.28, 0.52)  # main body (primary swatch)
const ENEMY_TANK_LIGHT: Color = Color(0.50, 0.40, 0.68)  # chest highlight / edge

# Enemy magnet electric-cyan ramp: dark → light. Documented exception above SATURATION_CEILING —
# electric cyan is maximally distinct from crimson/orange/violet; reads as "magnetic/electric".
const ENEMY_MAGNET_DARK: Color = Color(0.08, 0.34, 0.42)  # body shadow / lower legs
const ENEMY_MAGNET_MID: Color = Color(0.12, 0.54, 0.66)  # main body (primary swatch)
const ENEMY_MAGNET_LIGHT: Color = Color(0.20, 0.74, 0.86)  # chest highlight / edge

# Enemy shooter acid-yellow/green ramp: dark → light. Documented exception above SATURATION_CEILING
# — acid-yellow/green maximally distinct from crimson/orange/violet/cyan; reads as "toxic/ranged".
const ENEMY_SHOOTER_DARK: Color = Color(0.22, 0.34, 0.06)  # body shadow / lower legs
const ENEMY_SHOOTER_MID: Color = Color(0.38, 0.58, 0.08)  # main body (primary swatch)
const ENEMY_SHOOTER_LIGHT: Color = Color(0.54, 0.78, 0.14)  # chest highlight / edge

# Enemy stinger grey-violet ramp: dark → light + bright cyan-white edge highlight.
# Documented exception above SATURATION_CEILING — desaturated grey-violet reads "metallic/flying";
# distinct from crimson/orange/tank-violet/cyan/acid. Cyan-white edge highlight adds airborne read.
const ENEMY_STINGER_DARK: Color = Color(0.22, 0.20, 0.30)  # body shadow / lower chassis
const ENEMY_STINGER_MID: Color = Color(0.38, 0.34, 0.50)  # main body (primary swatch)
const ENEMY_STINGER_LIGHT: Color = Color(0.82, 0.88, 0.96)  # edge highlight — cyan-white "metallic"

# Pickup ammo — muted brass/olive: distinct from enemies, reads as "military supply".
# Documented: sat ≈ 0.30, value range 0.30–0.55, within SATURATION_CEILING.
const PICKUP_AMMO_DARK: Color = Color(0.30, 0.26, 0.12)  # shadow band / base
const PICKUP_AMMO_MID: Color = Color(0.46, 0.38, 0.18)  # main crate body (primary swatch)
const PICKUP_AMMO_LIGHT: Color = Color(0.58, 0.50, 0.26)  # top cap / edge highlight

# Pickup health — muted green: distinct from ammo brass and enemy hues; reads as "medkit".
# Documented: sat ≈ 0.28, value range 0.22–0.48, within SATURATION_CEILING.
const PICKUP_HEALTH_DARK: Color = Color(0.18, 0.30, 0.18)  # shadow band / base
const PICKUP_HEALTH_MID: Color = Color(0.26, 0.44, 0.24)  # main crate body (primary swatch)
const PICKUP_HEALTH_LIGHT: Color = Color(0.36, 0.56, 0.32)  # top cap / edge highlight

# Rescue "saved" halo — bright celebratory green; intentionally above SATURATION_CEILING
# (this is a positive hero beat, not an industrial texture; must read clearly over the palette).
const SAVED_GREEN_CORE: Color = Color(0.18, 0.72, 0.28)  # inner glow / OmniLight colour
const SAVED_GREEN_MID: Color = Color(0.22, 0.58, 0.26)  # particle mid-life colour
const SAVED_GREEN_FADE: Color = Color(0.18, 0.40, 0.20)  # particle fade-out colour

# --- Style scalars (the look's dials) ---
const VALUE_MIN: float = 0.16  # darkest a shade should go (keep silhouette readable)
const VALUE_MAX: float = 0.90  # brightest (avoid blown highlights in the SubViewport)
const SATURATION_CEILING: float = 0.50  # industrial look: greyer accents (nudged from 0.55)
const RAMP_SHADES: int = 3  # shades per material ramp (pixel-art banding)
const TEXEL_DENSITY: int = 32  # px per metre for tileable surface textures
