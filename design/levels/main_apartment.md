# Level: main_apartment

**Concept** — The player's home apartment: a lived-in domestic space with a living room, half-corridor, kitchen, shared bedroom (2 single beds + nightstand), master bedroom (double bed, wardrobe, chair, nightstand), and bathroom. The player explores and familiarises themselves with the space.

**Source** — levels/drawn/current.json (24×16, 308 wall cells, 308 floor cells, 0 door/window/item cells). The grid gives the outer perimeter only; internal walls for the room layout are godot-dev's to author from the concept description below.

**Scale** — 1.5 m per cell · wall height 2.8 m. Interior footprint: ~33 m × 21 m at perimeter wall inner faces. Individual rooms should feel 3–6 m across — believable domestic scale.

**Room layout (godot-dev to author from this description, using the grid perimeter as the outer boundary):**

The grid perimeter (columns 0 and 23, rows 0 and 15) forms the apartment walls. Inside, add internal walls to create:

- **Shared bedroom** — upper-left zone (approx grid x=1–7, y=1–7). Two single beds + one nightstand. Marker 1 (x=5, y=5) sits inside this room — place a small placeholder cylinder (0.3 m radius, 0.5 m tall, yellow material) to mark it; label it "Marker1_TBD".
- **Master bedroom** — upper-right zone (approx grid x=17–23, y=1–7). Double bed, large wardrobe (tall box), chair, nightstand.
- **Bathroom** — small cell, lower-left or upper area corner (approx grid x=1–5, y=9–15). Keep compact.
- **Kitchen** — adjacent to living room, one side (approx grid x=1–8, y=9–15 or as space allows). Counter-height boxes as stand-ins.
- **Living room + half-corridor** — centre of the apartment (approx grid x=8–16, y=4–12). Open space with a narrow corridor passage connecting bedroom wing to living area. Marker 2 (x=10, y=8) sits in this zone — place a small placeholder cylinder (0.3 m radius, 0.5 m tall, blue material); label it "Marker2_TBD".

Internal walls are simple BoxMesh StaticBody3D slabs, same pattern as the perimeter walls. Door openings (no mesh, no collision) between rooms wherever logical. No door geometry needed — just a gap in the wall.

**Tiles** — wall: perimeter only in grid; door: N/A (not drawn — use open gaps between rooms); window: N/A; item: N/A. Numbered markers: Marker1_TBD at (x=5,y=5) = placeholder cylinder, yellow; Marker2_TBD at (x=10,y=8) = placeholder cylinder, blue. Both parked as TBD — no gameplay logic.

**Spawn** — Player spawns at approximately grid cell (x=11, y=8), world position (16.5, 1.0, 12.0) at 1.5 m/cell — centre of the living room area.

**Look** — Floor: warm off-white / light beige (Color 0.85, 0.80, 0.72). Perimeter and internal walls: soft warm grey (Color 0.70, 0.67, 0.63). Placeholder furniture: simple BoxMesh blocks — beds in pale blue (Color 0.6, 0.7, 0.85), wardrobe in medium brown (Color 0.45, 0.32, 0.22), kitchen counter in light grey (Color 0.75, 0.75, 0.75). DirectionalLight3D: warm white (Color 1, 0.95, 0.88), energy 1.0, rotation (-40, -30, 0), shadows enabled. WorldEnvironment: ProceduralSky, ambient from sky, Filmic tonemap, exposure 1.0.

**Build** — standard baked .tscn: `levels/main_apartment.tscn` (root node `MainApartment`), same pattern as blockout_01.tscn — explicit StaticBody3D + MeshInstance3D + CollisionShape3D nodes for every wall/floor/furniture piece, Player instanced directly, DirectionalLight3D + WorldEnvironment. Grid JSON at `levels/drawn/current.json` is godot-dev's spatial reference for the perimeter, NOT a runtime data source. Register in main.gd `_levels`. Run godot-verify.

**Later** — Real furniture meshes / imported assets to replace placeholder boxes. Door frames with collision-free gap geometry. Named room zones for gameplay triggers. Marker 1 and Marker 2 wired to actual gameplay events once the game concept is settled. Window openings in perimeter walls.
