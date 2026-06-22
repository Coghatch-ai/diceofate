# Level: Blast Court

**Concept** — An exposed industrial courtyard where enemy waves funnel in from all sides; player weaves between two large cover blocks and must avoid hazard trap zones while exploiting ranged elemental combat to survive.

**Source** — `levels/drawn/current.json` (24×16, 384 cells; walls: ~60 cell-1s; item markers: 52 cell-4s across ids 1–6; no rooms defined)

**Scale** — 3 m per cell · wall height 4 m · total footprint 72 m × 48 m (≈2.25× existing arenas)

---

## Layout

Grid north=y=0, south=y=15, west=x=0, east=x=23.

```
N  [SPAWN RING]──[SPAWN STRIP top]──[SPAWN RING]
   │  cover-B(id5)  │  open sky  │               │
W  [SPAWN         open center arena          SPAWN] E
   │  (42×18 m clear combat space)                │
   │  [TRAP strip mid-row13]                       │
   [SPAWN RING]──[SPAWN STRIP btm]──[SPAWN RING]
S
```

**Zones:**
1. **Open Center** (x=4–18, y=5–10) — primary combat arena, ~42×18 m, wide lines of sight for ranged engagements. Two cover blocks break sightlines diagonally.
2. **North Trap Strip** (id=2, x=14–17, y=1) — 4-cell hazard zone near north spawn ring; punishes rushing north edge.
3. **South Trap Strip** (id=2, x=9–13, y=13) — 5-cell hazard zone across center-south, forces detour to pickup cluster.
4. **Cover Block A** (id=1, x=5–8, y=1–2) — 6-cell L-shape top-left interior, ~9×6 m footprint BoxMesh at slight Y-rotation (~8°).
5. **Cover Block B** (id=5, x=19–20, y=2–3) — 2×2 block top-right, ~6×6 m footprint, same spec.
6. **Perimeter Spawn Ring** (id=3, 24 cells) — top-center row, left column y=4–7, both side columns y=11–15, bottom row x=4–7 and x=15–18. All Marker3D fed to WaveManager.
7. **Pickup Cluster** (id=4, x=19–20, y=11–12) — 2×2 reward zone mid-right; `pickup_health.tscn` + `pickup_ammo.tscn`. Reachable only by crossing south trap strip or hugging east wall — deliberate risk/reward.

**Flow:** player spawns center → immediate pressure from all cardinal sides via spawn ring → cover blocks force weaving movement left and right → trap strips punish naive rushes north or south → pickup cluster rewards aggressive play mid-right.

**Pinch points:** wall cells at (x=11,y=2), (x=12,y=3), (x=5–6,y=5–6) create micro-funnels that break open center from perimeter band — enemies cluster there briefly before flooding center.

---

## Tiles

- **wall (code 1):** perimeter + scattered interior partitions. Color `Color(0.22, 0.22, 0.28, 1)` — dark slate. No rotation offset (grid-snapped).
- **door (code 2):** none in this grid.
- **window (code 3):** none in this grid.
- **item id=1 → Cover Block A:** `StaticBody3D` + `BoxMesh` size ~9×4×6 m, `Color(0.30, 0.30, 0.36, 1)` concrete, Y-rotation offset 8° for visual variety. Full-height collision (blocks projectiles and nav).
- **item id=2 → Hazard Trap floor:** flat `Area3D` + `MeshInstance3D` (emissive orange `Color(0.9, 0.35, 0.05, 1)`, slight emission energy 0.8). On `body_entered` → calls `apply_damage(10)` on player via duck-type seam (matches `firing_yard` HazardFloor pattern). Collision mask=2 (player layer).
- **item id=3 → Enemy Spawn Markers:** `Marker3D` only, no mesh. All paths collected into WaveManager `spawn_marker_paths`. 24 markers ring the arena.
- **item id=4 → Pickup Cluster:** `pickup_health.tscn` × 2 + `pickup_ammo.tscn` × 2, placed at the four id=4 cells (x=19–20, y=11–12). Slight Y-rotation offset per ruined_warehouse convention (~7–13°).
- **item id=5 → Cover Block B:** same spec as id=1, 2×2 footprint → `BoxMesh` ~6×4×6 m, Y-rotation 8°.
- **item id=6 → Player Spawn + Waypoints:** id=6 cells at (2,6),(8,8),(6,10),(15,10),(2,13). Cell (8,8) = player spawn (center-ish, clear sight lines in all directions). Cells (2,6),(6,10),(15,10) = `EnemyWP` patrol waypoints (3 points matching existing convention). Cell (2,13) dropped (too close to south spawn ring).

---

## Spawn

**Player:** (8, 8) in grid coords → world (24, 1, 24) at 3 m/cell. Central cell with open sight lines N/S/E/W.

**Enemy spawn markers:** all 24 id=3 cells → WaveManager with all enemy archetypes (runner, tank, magnetic, shooter, flying) matching existing `wave_manager.gd` multi-scene setup.

**Patrol waypoints:** (2,6), (6,10), (15,10) → 3 EnemyWP Marker3D.

---

## Look

- **Floor:** `Color(0.16, 0.16, 0.20, 1)` dark concrete. Trap tiles override with emissive orange slab on top.
- **Walls:** `Color(0.22, 0.22, 0.28, 1)` slate. Cover blocks slightly lighter `Color(0.30, 0.30, 0.36, 1)`.
- **Sky + lighting:** warm directional sun (matches firing_yard: `Color(1, 0.6, 0.2, 1)`, energy 0.6, shadows on) + ProceduralSky warm orange horizon. Glow enabled (levels 3–5, intensity 0.6) — makes emissive trap zones read clearly.
- **Space contrast device:** open center floor slightly lighter tint vs near-wall band (darker). No ceiling — outdoor feel, maximises vertical read on cover block silhouettes.

---

## Systems exercised

| System | How used |
|---|---|
| Ranged combat (rifle + elemental bullets Q–T–Y) | Wide open center → long sight lines, elemental switching tactically useful |
| Wave/archetype enemy system | WaveManager fed 24 perimeter spawn markers; all 6 archetypes eligible |
| HealthComponent (player damage) | Hazard trap Area3D calls `apply_damage` on player body_entered |
| Pickup system | pickup_health + pickup_ammo at id=4 cluster |
| Navigation | Open floor with cover blocks as nav obstacles; 3 patrol waypoints |

---

## Assumptions (autonomous decisions — no user input)

1. `cell_size` 3 m chosen (not default 1 m) to make level genuinely larger than existing 2 m/cell arenas.
2. id=3 read as spawn ring because cells ring the perimeter — most natural interpretation for "enemy spawns via wave system."
3. id=6 as player spawn + waypoints — only 5 scattered singles, fits neither cover block (needs area) nor hazard (needs strip) nor spawn ring (already id=3). Cell (8,8) chosen as spawn by centrality.
4. id=1 L-shape treated as single merged cover block (not 6 individual pillars) — user said "big blocks."
5. id=2 dual strips (y=1 top, y=13 mid-south) form two trap barriers — top discourages north-rushing, south forces detour to pickups.
6. id=4 as pickup cluster — 2×2 block, good reward-node placement near east side.
7. id=5 as second cover block (2×2 top-right) — symmetric counterpart to id=1.
8. No verticality — user constraint honored strictly; single flat floor at y=0.
9. Wall height 4 m (vs existing 3.5 m) — slightly taller for more enclosed perimeter feel despite open top.
10. Cover block Y-rotation 8° — shape variety per gd-utilities-level-design §3; functional collision unchanged.

---

## Handoff

To **game-designer**: turn this level design into the buildable design — decide construction method (GridMap vs baked boxes vs hybrid), split into per-area build slices if needed, then dispatch godot-dev. Brief path: `design/levels/blast_court.md`. Level scene target: `levels/blast_court.tscn`, root node `BlastCourt`.

---

## Later

- Per-zone floor color variation (center vs perimeter band) — cheap but not critical for POC.
- Animated trap pulses (emissive flicker via Tween) — parked.
- Navigation mesh bake spec — game-designer to decide with build method.
- Cover block surface texture (currently flat color) — asset-advisor if HD art needed.
