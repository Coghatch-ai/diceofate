# Iron Floor — Buildable Design

**Goal** — A walkable static greybox factory: player spawns SW, fights room-by-room through door-gated
teaching encounters (basic → fire-immune → ice-immune → mixed → bubble → boss), each room cleared opens
the next door, ending at a color-cycling Slime boss.

## Build method (decided)

- **STATIC hand-authored greybox** (`godot-greybox`): real `StaticBody3D`+`BoxMesh`+`CollisionShape3D`
  nodes written into `levels/iron_floor.tscn`, selectable in editor. NOT runtime-built, NOT GridMap.
  `position` + `rotation` only — never `Transform3D` literals.
- **Encounter controller = `RoomController`** (NOT WaveManager). main.gd already wires it (lines 81-87).
  Whole level is scripted RoomEncounters → per-room door gating, hint text, archetype-per-room. New room
  = new `RoomEncounter` `.tres`, zero new code.
- **Boss = existing `Boss` color-phase system** + ONE new behaviour (4s color timer — see Slice 5).
- Register `iron_floor.tscn` in `main.gd` (`initial_level` or load path).

## Data-driven foundation (already exists — this is assembly, not new systems)

| Need | Existing system | This level adds |
|---|---|---|
| Per-room scripted encounter + door gate | `RoomController` + `RoomEncounter`/`RoomSpawn` `.tres` | new `.tres` per room |
| Fire-immune / ice-immune teaching enemies | `archetypes/immune_fire.tres`, `immune_ice.tres` | referenced in encounter `.tres` |
| Cyan/bubble enemy | magnetic enemy = `archetypes/tank_magnet.tres` (bubble = magnet behaviour) | referenced |
| Basic grunt | `archetypes/grunt.tres` | referenced |
| Color-cycle boss (color=damage type, wrong=immune, size step, explode) | `Boss` + `BossData` + `BossColorPhase` (`boss_prism.tres` is a working example) | new `boss_slime.tres` |

Damage types: `PHYSICAL=0 FIRE=1 ICE=2 ELECTRIC=3 POISON=4 ACID=5` (`tools/lib/damage_type.gd`).

## Geometry mapping (grid → world)

- Grid 24×16, 2 m/cell, wall height 6 m. Cell (x,y) center → world `(x*2+1, y, y_cell*2+1)` i.e.
  `world_x = x*2+1`, `world_z = y*2+1`. Floor flat at y=0 (no verticality this iteration).
- ONE floor `StaticBody3D`+BoxMesh spanning ~48×32 m (dark grey #2a2a2a), one collider.
- Perimeter + interior walls from the `cells` array (value `1` = wall) in `levels/drawn/current.json`
  — mid grey #4a4a4a, 6 m tall, 2 m wide segments. **Author walls per-cell as boxes via position+rotation;
  do NOT collapse the grid into hand-typed Transform3D spans.** (118 wall cells — fine as static boxes.)
- Two door cells (value `2`) at grid (19,10) and (19,11): build as `StaticBody3D` doorframe with a
  MeshInstance3D + CollisionShape3D so RoomController can open them (hide mesh + disable collider).
- Copy `levels/drawn/current.json` → `levels/drawn/iron_floor.json` (provenance; not loaded at runtime).
- Room zones (grid → world band), from brief table:
  - R1 spawn SW cols1-3 rows12-14 · R2 corridor cols4-7 rows8-13 · R3 cols1-5 rows5-8 (fire-immune)
  - R4 cols1-8 rows0-4 (ice-immune) · R5 cols9-12 rows0-8 (wave) · R6 hub cols6-11 rows6-11 (bubble)
  - R7 cols13-17 rows4-8 (wave) · R8 cols14-17 rows1-3 (wave) · R9 cols15-19 rows8-12 (wave)
  - R10 cols12-16 rows10-14 (wave) · R11 boss cols20-23 rows7-14 (behind doors).

## Scope (in) — ordered slices

Each slice is one godot-dev task, verified with `godot-verify` (load+render, no Transform3D, scene
present in editor) before the next.

- **Slice 1 — Floor + perimeter + interior walls.** Author `levels/iron_floor.tscn`: one floor node,
  all `cells==1` as wall boxes (position+rotation), two `cells==2` as openable doorframe StaticBody3Ds
  named `Door_R10`, `Door_R11` (or per gate). Copy json. NO enemies/markers yet. Register in main.gd.
  Verify: F5 walks the whole footprint, rooms enclosed, doors are solid blocks, no clipping/drift.
- **Slice 2 — Lighting + Player + nav + spawn markers.** Add Player at R1 spawn (world ≈ `(5,1,27)`,
  facing into level), dim cool-white DirectionalLight3D + standard Sky, one `NavigationRegion3D` (group
  `nav_region`) baked over the floor, a `FallZone` Area3D pattern only if a hole is wanted (none in grid
  → skip, park). Add named `Marker3D` spawn points: ≥2 per combat room (R2,R3,R4,R5,R6,R7,R8,R9,R10) +
  one boss marker `BossSpawn` centered in R11. Name markers `Spawn_R2_a` etc. Verify: player walks, nav
  baked covers floor, markers visible in editor.
- **Slice 3 — RoomController + teaching encounters (R2,R3,R4,R6).** Add `RoomController` node + per-room
  trigger Area3Ds (`Trigger_R2`…) at each room entry + door nodes where rooms gate. Author `.tres`:
  - `encounters/iron_r2.tres` — 3× `grunt`, hint "Shoot to clear the room."
  - `encounters/iron_r3.tres` — 3× `immune_fire`, hint "Fire won't hurt these — switch ammo type."
  - `encounters/iron_r4.tres` — 3× `immune_ice`, hint "Ice won't hurt these — switch again."
  - `encounters/iron_r6.tres` — 3× `tank_magnet` (bubble), hint "Cyan enemies pull your bullets."
  Wire `RoomController.encounters` / `room_trigger_paths` / `door_paths` / `spawn_marker_paths` /
  `enemy_scene` (generic enemy.tscn). Verify: enter room → enemies spawn at markers, clear → door opens,
  hint shows.
- **Slice 4 — Wave-room encounters (R5,R7,R8,R9,R10).** Author one `.tres` each with **5 mixed enemies**
  (grunt + immune_fire + immune_ice + tank_magnet mix) at that room's markers, `clear_advances=true`,
  door to next. (Fixed count; endless "+1 per kill" escalation is PARKED — see Later.) Add their triggers
  + doors to RoomController arrays (index-matched). Last cleared room (R10) opens the R11 boss doors.
  Verify: each wave room spawns 5, clears, gates correctly.
- **Slice 5 — Slime boss (DOMAIN: godot-enemy, NOT godot-dev).** Author `archetypes/boss_slime.tres`
  (`BossData`) with 2 `BossColorPhase` × `phase_hp=10` (=20 hits to kill), `body_scale` ramp
  (e.g. 1.5 → 2.5 → grows one step per phase), `explode_radius>0` so final phase = death/explode, distinct
  albedo/emission per phase. **Plus a NEW behaviour: advance color phase on a 4-second timer** (brief
  decision) — color cycles every 4s independent of damage; only the currently-shown color's damage type
  hurts it. This is the ONE new bit of boss code: a timer on `Boss` (or a small `BossColorTimer` seam)
  that calls the existing `_advance_color_phase()` / re-enters phases on a 4s tick while keeping the
  10-correct-hits-per-step and 20-total-to-die HP gating. Spawn the boss in R11 via RoomController's
  `complete_run()` path (boss is outside the encounter array; level script spawns it when R11 doors open,
  connects `boss.died` → `room_controller.complete_run(score)`). Verify: boss cycles color every 4s,
  correct-color bullets damage/grow it, wrong color does nothing, dies+explodes at 20 correct hits.

## Scope (out)

- Endless "+1 enemy per kill" wave escalation — replaced by fixed 5/room (RoomController has no global
  escalation; would need WaveManager which can't door-gate). Parked.
- Verticality / raised zones — brief says flat this iteration.
- Sourced textures, per-zone wall tints, decals — post-greybox art pass.
- FallZone hazards — grid has no holes; park.
- Locked-until-cleared R11 gate beyond the natural door gating — door opens when R10 clears (covers it).

## Acceptance

- `levels/iron_floor.tscn` opens in editor with every wall/floor/door/marker selectable (NOT empty-until-Play).
- `tools/validate.sh` passes; no `Transform3D` literals; render OK.
- F5: player spawns R1, walks the whole level; each room's enemies spawn on entry, clear opens its door,
  hint appears; R3 enemies survive fire ammo, R4 survive ice ammo, R6 are bubble/magnet.
- Boss in R11 cycles color every 4 s; correct-color hits damage + grow it (size step per 10), wrong color
  = no damage; explodes/dies at 20 correct hits → run completes.

## Skill notes

- `godot-greybox` (slices 1-2): static nodes in saved `.tscn`, one floor, position+rotation, nine spatial
  principles by eye (note: this is a teaching maze of rooms, not an open arena — P1 loop relaxed to the
  linear door-gated flow the brief intends).
- `godot-verify` (every slice): Transform3D ban, Sky resource required, load+render gate.
- `godot-main-scene`: level loads under Main/LevelHost; register in main.gd; never `change_scene_to_file()`.
- `godot-resource-registry` / data-driven: encounters & boss are `.tres` data over existing systems.
- Slice 5 only: `godot-enemy` / `godot-enemy-archetype` + Boss color-phase — domain agent, NOT godot-dev.

## Later

- Per-room endless wave escalation (+1 per kill) as an opt-in `RoomEncounter` field or a hybrid controller.
- Verticality / mezzanine (+1 m) for spatial variety.
- Per-zone wall colour tint + decals; sourced concrete/rust/metal textures.
- R11 hard-lock (no doors open until ALL rooms cleared), boss death VFX/screen effect.

## Open questions

None — buildable.
