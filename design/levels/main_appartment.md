# Level: main_appartment

**Source** — `levels/drawn/current.json` (24×16, 61 wall · 5 door · 6 window · 17 items [4×wardrobe, 5×beds, 3×electronic, 4×nightstand, 4+1 split across codes])

**Tile counts (exact)**
- Code 0 floor: 295
- Code 1 wall: 61
- Code 2 door: 5
- Code 3 window: 6
- Code 4 wardrobe: 5 tiles (middle + east chambers, rows 6–7, cols 14/17/20)
- Code 5 beds: 5 tiles (all three chambers, rows 5–7)
- Code 6 electronic: 3 tiles (east chamber, rows 5–6, col 22; row 7 col 21)
- Code 7 nightstand: 4 tiles (west + middle chambers, rows 5–7)

**Layout read**
Enclosed compound occupying cols 5–23, rows 4–11 of the 24×16 grid.
- **North perimeter wall** (row 4, cols 5–23): three window pairs at cols 10–11, 15–16, 20–21.
- **West perimeter wall** (col 5, rows 4–11): solid.
- **East perimeter wall** (col 23, rows 4–11): solid.
- **Interior dividers** at col 8 (rows 4–8) and col 13 (rows 4–8): create three narrow bedroom chambers in the upper half.
- **Horizontal divider** (row 8, cols 13–23): separates chambers from the lower hall; has two door gaps at cols 17 and 19.
- **Lower hall** (rows 9–10, cols 6–22): large open living/corridor space.
- **South perimeter wall** (row 11, cols 5–23): two door openings at cols 16–17.
- **Door count breakdown**: 2 in row-8 divider (chamber→hall), 2 in south wall (entry), 1 in east side of lower hall (col 19 row 9 area).

**Scale** — 2 m per cell · wall height 3 m · no elevation change (flat throughout)

**Tiles**
- **Wall**: full-height (3 m) merged runs; never one StaticBody per cell.
- **Door (code 2)**: passable gap + simple frame mesh, slightly rotated 5° around Y for worn look; no blocking collision.
- **Window (code 3)**: half-height wall segment (1.5 m) + sill mesh with a slight 5° angle offset; blocks movement, visually open above.
- **Wardrobe (code 4)**: flat box prop, placed at 15° Y rotation; tint Color(0.55, 0.4, 0.25) — dark wood.
- **Beds (code 5)**: flat box prop (wider than tall), axis-aligned; tint Color(0.8, 0.75, 0.85) — soft linen.
- **Electronic (code 6)**: thin flat-screen box, axis-aligned, upright; tint Color(0.2, 0.2, 0.25) — dark screen.
- **Nightstand (code 7)**: small box prop, slight 5° Y lean; tint Color(0.6, 0.5, 0.35) — medium wood.

**Zones and contrast**
- **Bedroom chambers** (rows 4–8, three zones separated by cols 8 and 13): wall colour warm beige — Color(0.85, 0.78, 0.65). Each chamber ~6 m × 8 m at 2 m/cell.
- **Lower hall / living area** (rows 9–10): wall colour cool grey — Color(0.65, 0.65, 0.70). Space ~26 m × 4 m. The door gaps in row 8 are the funnel moment between the tight chambers and the open hall.
- **Floor** (entire interior): warm tan — Color(0.75, 0.65, 0.45).

**Spawn** — Auto: central-most empty cell in the lower hall, approximately col 12 row 9 (world position ~(24m, 0, 18m) at 2 m/cell, origin at grid (0,0)).

**Look** — Flat ambient only (no DirectionalLight3D, no shadow casting). ProceduralSky + WorldEnvironment with ambient_light_source = Sky, ambient_light_energy = 1.0, tonemap_mode = Filmic, tonemap_exposure = 1.0. Matches existing blockout material pattern (flat StandardMaterial3D, no textures).

**Build** — Named scene `levels/main_appartment.tscn` (root node `MainAppartment`) via the reusable guided-level builder `levels/guided_level.gd` (`class_name GuidedLevel extends Node3D`, `@export var grid_path: String`), reading the saved grid `levels/drawn/main_appartment.json`. Merge contiguous wall runs (no StaticBody per cell). Auto Player spawn at central lower-hall cell. Register `res://levels/main_appartment.tscn` in `main.gd`'s `_levels` array. Run `tools/validate.sh` + godot-verify (3-layer check) before reporting done.

**Later**
- Elevation: lower hall raised +0.5 m for grander entry feel (deferred — flat build first).
- Functional doors: hinge animation / toggle collision on interact.
- Actual furniture meshes: swap box placeholders for .glb models once art is sourced.
- Ceiling mesh (currently open-top).
- Interior point lights to simulate apartment lamps.
