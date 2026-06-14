# Level: Shared Apartment

**Concept** — A lived-in three-person apartment: kitchen, living room, shared bedroom, bathroom, a hallway corridor, and a separate main bedroom to the south — the player moves through a plausible domestic space at human scale.

**Source** — levels/drawn/current.json (24×16 grid · 73 wall · 4 door · 5 window · 19 item tiles · 6 numbered markers)

**Scale** — 1.5 m per cell · wall height 2.8 m

---

## Room map (numbered markers from the grid)

| Marker | Cell (col, row) | Room |
|--------|-----------------|------|
| 5 | col 5, row 6 | Kitchen (left room, cols 3–7, rows 4–10) |
| 4 | col 9, row 7 | Living room (center narrow zone, cols 8–12, rows 4–9) |
| 3 | col 14, row 7 | Shared bedroom (left half of right zone, cols 13–17, rows 4–9) |
| 1 | col 20, row 6 | Bathroom (far-right of right zone, cols 18–23, rows 4–9) |
| 6 | col 15, row 11 | Corridor / hallway (south passage, cols 3–15, rows 10–12) |
| 2 | col 21, row 10 | Main bedroom (south of structure, cols 16–23, rows 10–12+) |

---

## Tiles

**Wall (1)** — solid BoxMesh + BoxShape3D collision. Per-zone wall colours (flat StandardMaterial3D):
- Kitchen + Bathroom: cool off-white `Color(0.85, 0.87, 0.88)`
- Shared bedroom: warm cream `Color(0.9, 0.87, 0.78)`
- Living room + Corridor: mid grey `Color(0.6, 0.6, 0.62)`
- Main bedroom: warm cream `Color(0.9, 0.87, 0.78)`

**Door (2)** — passable gap (no collision block at that cell) + a thin BoxMesh door-frame placed in the opening. No rotation offset (clean domestic look). Doors at: row 10 col 3 (kitchen→corridor), row 10 col 5 (second kitchen exit), row 11 col 3 (corridor side), row 12 col 8 (corridor→main bedroom).

**Window (3)** — half-height wall segment (sill, ~1.0 m tall) with no collision above sill height. No rotation offset. Windows at: row 4 cols 8–10 (living room / shared bedroom north face), row 4 cols 19–20 (bathroom north face).

**Item tiles — props (placeholder BoxMesh, no collision blocking):**

| Code | Count | Prop | Material colour | Rotation |
|------|-------|------|-----------------|----------|
| 4 | 8 | Bed (double-cell footprint, 0.3 m tall) | Soft blue-grey `Color(0.5, 0.55, 0.7)` | Axis-aligned |
| 5 | 4 | Bathtub / shower cubicle (single 1.5×0.8 m box) | White-blue `Color(0.8, 0.88, 0.95)` | Axis-aligned |
| 6 | 5 | Nightstand (small 0.5×0.5×0.6 m box) | Medium brown `Color(0.55, 0.42, 0.3)` | Axis-aligned |
| 7 | 2 | Fridge (0.6×1.8×0.6 m tall box) | Bright white `Color(0.95, 0.95, 0.95)` | Axis-aligned |

**Floor** — single merged slab, light wood-tone `Color(0.75, 0.65, 0.5)`.

---

## Verticality

- **Bathroom** (marker 1 zone, cols 18–23, rows 4–9): floor raised +0.1 m — a standard wet-room step. The floor slab in that zone sits 0.1 m higher than the rest.
- All other rooms: base floor at Y = 0.

---

## Space contrast

Narrow living room (4 cells wide) opens into the wider shared bedroom (5 cells) then the bathroom — contrast amplified by wall colour change at each zone boundary (see Tiles above). The corridor is darker, creating a pinch-point before the main bedroom.

---

## Spawn

Auto — centre of the playable floor area (approximately col 13, row 7, at floor level). No explicit spawn cell required; godot-dev places the Player at the geometric centre of the interior floor.

---

## Look

- Floor: light wood-tone `Color(0.75, 0.65, 0.5)`
- Walls: per-zone flat colours (see Tiles)
- Props: flat StandardMaterial3D, colours per prop type (see Tiles)
- Lighting: standard `DirectionalLight3D` (same settings as blockout_01.tscn) + `WorldEnvironment` with `ProceduralSkyMaterial`, `ambient_light_source = 3`, `ambient_light_energy = 1.0`, `tonemap_mode = 3` (Filmic), `tonemap_exposure = 1.0`

---

## Build

Standard baked .tscn: `levels/shared_apartment.tscn` (root node `SharedApartment`), same pattern as `blockout_01.tscn` — explicit `StaticBody3D` + `MeshInstance3D` + `CollisionShape3D` nodes per wall run / floor slab / prop, Player instanced directly in the scene, `DirectionalLight3D` + `WorldEnvironment`.

Grid JSON at `levels/drawn/current.json` is godot-dev's **spatial reference only** — NOT loaded at runtime. Use it to determine wall run positions, room boundaries, door/window cell locations, and prop placement cells; convert cell coordinates to world coordinates with `col * 1.5` (X) and `row * 1.5` (Z).

Register `shared_apartment` in `main.gd`'s `_levels` array. Run `tools/validate.sh` + `godot-verify`.

---

## Later (parked)

- Main bedroom walls not fully enclosed in the current grid — godot-dev should close them as a simple rectangle matching the marker-2 area; exact boundary left to builder judgement.
- Door props with actual door-leaf geometry (swinging or sliding).
- Bathroom tile floor texture (needs asset-sourcing loop).
- Kitchen counter / appliance props (stove, sink) — no tile code painted; add in a second pass.
- Furniture for living room (couch, TV) — no type-5 tiles in that zone; park for v2.
- Collision on prop meshes (beds, fridge) if gameplay requires it.
