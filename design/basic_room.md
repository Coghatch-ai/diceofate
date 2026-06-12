# Basic Room

**Goal** — A single static room you can open and look at: floor, four walls, and three box placeholders standing in for a bed, a wardrobe, and a chair.

**Scope (in)**
- New level scene `res://levels/basic_room.tscn`, root `BasicRoom` (Node3D).
- Floor: a `StaticBody3D` + `MeshInstance3D` (BoxMesh or PlaneMesh) flat on the ground, ~8×8 world units.
- Four walls around the floor perimeter (BoxMesh on MeshInstance3D), ~3 units tall, forming a closed room with one corner left open is NOT required — close all four.
- Three furniture placeholders, each a single `MeshInstance3D` with a BoxMesh, sized and positioned to read as: `Bed` (low wide box against a wall), `Wardrobe` (tall narrow box against a wall), `Chair` (small cube near the room center).
- Distinct flat StandardMaterial3D albedo colors per element group (floor / walls / each furniture piece) so they're visually separable — no textures.
- One `DirectionalLight3D` and a `WorldEnvironment` so the room is lit and not black.
- One `Camera3D` placed at a fixed 3/4 angle (pitch −30°, yaw 45° per camera-rig convention), **Projection = Orthogonal, Size ≈ 10**, framing the whole room. This is a plain in-scene camera so the scene is viewable on its own.

**Scope (out)**
- SubViewport pixelation rig — own slice; this scene renders at native res for now (own slice: godot-3d-pixelation).
- Camera rig entity / follow behavior — no player to follow yet (own slice: godot-camera-rig).
- Player / movement / input — not requested; nothing to drive.
- Collision on walls/furniture beyond the floor — nothing moves, so no need yet.
- Doors, windows, textures, real furniture models — placeholders only.
- Post-process / outlines — separate skills, not requested.

**Acceptance**
- `godot --headless --path . --script tools/verify_scene.gd -- levels/basic_room.tscn` prints `VERIFY: OK` (no VERIFY-FAIL lines).
- Opening `levels/basic_room.tscn` in the editor and pressing Play (F6) shows a lit room: a floor, four enclosing walls, and three distinguishable boxes (bed/wardrobe/chair), all on screen at once with no perspective vanishing point (parallel wall edges stay parallel).
- The three furniture boxes are visually distinct from each other and from the walls/floor by color.

**Skill notes**
- `godot-camera-rig`: Camera must be **Orthogonal**, not Perspective (texel-snapping requirement). Use the convention angle pitch −30° / yaw 45°. Camera rotation lives on the camera here (no pivot rig yet); that is acceptable for a static scene.
- `godot-verify`: mandatory after authoring the scene; run before handoff.
- Conventions: node names PascalCase (`BasicRoom`, `Floor`, `WallNorth`, `Bed`…); file snake_case (`basic_room.tscn`) under `levels/`. Forward+ renderer (already set).

**Later**
- Wrap this room in the SubViewport pixelation rig (godot-3d-pixelation).
- Replace the in-scene camera with the camera_rig entity and have it follow a player (godot-camera-rig).
- Add a player entity with movement using the existing move_* / jump input actions.
- Give walls/furniture collision once something moves in the room.
- Swap box placeholders for real low-poly furniture meshes.

**Open questions** — none.
