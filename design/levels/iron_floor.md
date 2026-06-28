# Level: Iron Floor

**Concept** — Abandoned factory used as a tutorial. Player learns enemy types and color mechanics room by room, escalating from basic encounters to a color-cycling boss. Each zone introduces one new challenge before the player commits to the next.

**Source** — `levels/drawn/current.json` (24×16, 118 walls, 2 doors, 0 windows, 0 items, 234 room cells across 11 rooms). Saved grid to be copied to `levels/drawn/iron_floor.json`.

**Scale** — 2 m per cell · wall height 6 m (tall warehouse, industrial feel). Grid footprint at scale: 48×32 m.

**Layout** — Rooms flow left-to-right and top-to-bottom in a loose L-shape. Entry from SW corner (room 1) pushes east through a corridor (room 2), then opens into the large upper floor (rooms 3, 4, 5). Center hub (room 6) is the crossroads connecting upper and lower halves. Right side (rooms 7, 8, 9, 10) fans out from the hub. The far-right strip (room 11) is sealed behind two door cells at x=19 rows 10–11 — the only explicit doors, creating a gating moment before the boss.

**Room zones and meaning:**

| Room | Grid area (approx) | Zone / purpose |
|------|--------------------|----------------|
| 1 | SW 3×3, cols 1–3 rows 12–14 | Player spawn / entry point |
| 2 | Center-left ~4×6, cols 4–7 rows 8–13 | Tutorial combat — basic (grunt-type) enemies, one enemy type, teaches shooting |
| 3 | Left side ~5×4, cols 1–5 rows 5–8 | Enemies immune to fire damage — teaches ammo type selection |
| 4 | Upper-left ~8×5, cols 1–8 rows 0–4 | Enemies immune to ice damage — teaches second ammo type |
| 5 | Center-top ~4×8, cols 9–12 rows 0–8 | Wave escalation begins — random enemy mix, wave manager active, enemy count +1 per kill, fixed spawn markers |
| 6 | Center hub ~6×6, cols 6–11 rows 6–11 | Cyan/bubble enemies — teaches elemental bubble mechanic; crossroads, highest traffic |
| 7 | Right-center ~5×5, cols 13–17 rows 4–8 | Wave escalation continues (+1 per kill), fixed spawns, random enemy types |
| 8 | Upper-right alcove ~4×3, cols 14–17 rows 1–3 | Wave escalation continues (+1 per kill), fixed spawns |
| 9 | Lower-right ~5×5, cols 15–19 rows 8–12 | Wave escalation continues (+1 per kill), fixed spawns |
| 10 | Lower-center ~3×5, cols 12–16 rows 10–14 | Wave escalation continues (+1 per kill), connector to door |
| 11 | Far-right strip ~4×8, cols 20–23 rows 7–14 | Boss arena — slime boss (see boss spec below) |

**Boss spec (room 11 — Slime):**
- Changes color every 4 seconds
- Each color = a damage type that can hurt it; wrong color = no damage
- Every 10 correct-color bullets: size increases one step
- At 20 correct-color bullets total: explodes / dies
- Boss is the only encounter in room 11; no other enemies

**Tiles:**
- Wall: mid-grey flat-colour BoxMesh, 6 m tall
- Door (x=19 rows 10–11): passable gap + simple doorframe mesh; no blocking collision
- Window: none in grid
- Items: none in grid
- Floor: dark grey flat-colour BoxMesh

**Rooms → theme:**
- Room 1: neutral entry, no enemies
- Rooms 2–4: intro zone, one enemy type per room, clearly distinct by enemy behaviour (not wall colour)
- Room 5 onward: wave escalation active — fixed SpawnMarker3D positions per room, wave_manager wires them
- Room 6: cyan/bubble enemy variant — mark this room for wave_manager with bubble-only enemy archetype
- Room 11: boss arena — isolated behind doors, no wave_manager, bespoke boss node

**Wave escalation rule (rooms 5, 7, 8, 9, 10):** per kill, spawn one additional enemy (starts at 1, increments). Fixed spawn markers in each room. wave_manager handles this; exact implementation is game-designer's call.

**Spawn** — Room 1 (SW corner, cols 1–3 rows 12–14), central-most empty cell in that zone.

**Look** — Floor: dark grey (#2a2a2a flat colour). Walls: mid grey (#4a4a4a flat colour). Lighting: dim DirectionalLight3D (low energy, cool-white) + warm point fill lights placed in each zone to differentiate them. Standard Sky. Greybox quality — no sourced textures at this stage.

**Verticality** — All floors flat for this tutorial (user unfamiliar with height splits; park raised zones for a later iteration).

**Build intent** — Hand-authored STATIC greybox blockout. Real `StaticBody3D` + `BoxMesh` nodes written directly into `levels/iron_floor.tscn` (selectable/movable in the editor). Position + rotation only, never Transform3D literals. Skill: `godot-greybox`. Then registered in `main.gd` and verified with `godot-verify`. Do NOT build with a runtime generator or GridMap.

**Handoff** — To game-designer: turn this level design into the buildable design. Decide how to split into per-area build slices (each buildable and verifiable on its own). Dispatch godot-dev per slice. Boss mechanic (color cycle, size step, explode trigger) needs its own design slice — it is a new entity with significant logic, not just geometry. Wave escalation rule (rooms 5, 7, 8, 9, 10) also needs a design decision on how the wave_manager is configured per room.

**Later:**
- Raised zone (+1 m mezzanine) for spatial variety — park until basic blockout verified
- Visual differentiation per zone (wall colour tint, decals) — post-greybox
- Door trigger / lock (room 11 entry locked until rooms 5–10 cleared) — if desired, park for now
- Sourced textures (concrete, rust, metal grating) — post-POC art pass
- Boss death VFX (explosion, screen effect) — after boss logic works
