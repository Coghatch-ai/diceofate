# Level: Firing Yard

**Concept** — A compact sci-fi FPS arena where the player moves through open but obstacle-filled space, using cover, jumping to elevated platforms, and eventually interacting with hazard props and special gravity walls. The space is small enough that the far end is always visible, keeping tension tight and readable.

**Source** — levels/drawn/current.json (24x16, 51 wall cells, 52 item cells across 6 ids, 0 rooms, 0 doors, 0 windows)

**Scale** — 2 m per cell · wall height 4 m · arena footprint 48 m x 32 m

**Layout** — No sealed perimeter; the arena is an open field of internal cover obstacles (wall fragments) with a soft visual boundary defined by passable fake-wall props (id 3). No doors or corridors — the player reads the whole space from spawn.

Flow: player enters at the bottom-center edge (col 12, row 15), moves north through mid-arena scattered cover (wall fragments + id-6 decorative props), encounters the id-2 special-wall row near the bottom (row 13) and the id-2 top line (row 1) as the far objective edge. Two elevated platforms on the right side break the flat floor plane and offer height advantage:
- id-5 platform: top-right (cols 19-20, rows 2-3), +2 m above floor — high tier
- id-4 platform: right-center (cols 19-20, rows 11-12), +1 m above floor — mid tier

Each platform has a ramp/step on its south face. The id-1 hazard cluster sits in the upper-left quadrant (cols 5-8, rows 1-2), drawing players who push into the far corner.

Space contrast: the entry area (south half) is relatively clear — the wall fragments thin out. The north half is tighter with more wall cells clustered. The transition from open south to cover-dense north is the main pinch.

**Tiles**

- wall: solid collision, flat-colour dark concrete box, 4 m tall — cover obstacle. No rotation offset.
- id 1 (6 cells, cols 5-8, rows 1-2): ROTATING HAZARD placeholder — greybox as a bright-coloured (orange) BoxMesh prop on the floor. No mechanic yet. The prop marks the position of a future spinning push-out obstacle. No collision required for greybox.
- id 2 (9 cells — row at cols 14-17, row 1; row at cols 9-13, row 13): WALL-CLING ZONE placeholder — greybox as a flat wall-surface prop, distinct colour (cyan tint) so the zone reads as special. No gravity mechanic yet; wall has no collision for B1. Mark as zone only.
- id 3 (18 cells, perimeter lining): FAKE WALLS — visual only, zero collision. Thin flat quad or low bollard mesh, slightly warm grey to signal passability. Player can walk through.
- id 4 (4 cells, cols 19-20, rows 11-12): MID PLATFORM — raised 1 m above floor. Solid collision surface. Ramp on south face. Flat grey/metal colour.
- id 5 (4 cells, cols 19-20, rows 2-3): HIGH PLATFORM — raised 2 m above floor. Solid collision surface. Ramp on south face. Flat grey/metal colour.
- id 6 (5 cells, sparse singles at (2,6), (8,8), (6,10), (15,10), (2,13)): DECORATIVE PROPS — random barrels/crates placed diagonally for shape variety. No collision. Break visual monotony.
- rooms: none tagged — the entire grid is one arena zone.

**Spawn** — Bottom-center edge, col 12 row 15 (southernmost open floor cell at horizontal midpoint). Player faces north into the arena.

**Look** — Floor: near-black with faint grid-line texture or flat dark (#141420). Walls: mid dark grey (#404050). Platforms: slightly lighter grey/metal (#606070). Fake walls (id 3): translucent-hinted pale grey (#909090, no collision). Hazard placeholder (id 1): solid orange (#e06020). Wall-cling zone (id 2): solid cyan (#208090). Decorative props (id 6): dark olive/rust. Lighting: one DirectionalLight3D, cool blue-white (color ~#8888ff, energy 1.2), angle from upper-north. Ambient: dark blue (#101020). Sky: WorldEnvironment with a dark solid sky (no horizon visible) — the arena reads as a closed indoor-outdoor tech yard. No bloom or post-process for B1 greybox.

**Handoff** — To game-designer: turn this level design into the buildable design. Decide whether to build this as a GridMap + MeshLibrary (skill godot-gridmap-level) or hand-placed greybox boxes. The level is 24x16 cells — consider whether to build it as one pass or split north/south halves. Dispatch godot-dev to build the greybox scene at levels/firing_yard.tscn, register it in main.gd under LevelHost, and verify with godot-verify. The two placeholder mechanics (id 1 rotating hazard, id 2 slow-gravity wall) are NOT in scope for this build — props only.

**Later**
- id 1 mechanic: spinning platform/arm that physically pushes the player out of the arena (physics body, angular velocity, contact force)
- id 2 mechanic: slow-gravity / wall-cling zone (gravity override on contact, Spider-Man movement)
- Per-zone lighting accent (the id-2 zone glows cyan, the platform areas get a subtle spot)
- Enemy spawn system keyed to this arena layout
