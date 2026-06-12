# Collision Shapes (Pattern Doc)

**Goal** — Add physics collision to existing MeshInstance3D nodes so other physics bodies (CharacterBody3D, RigidBody3D) interact with them instead of clipping through.

---

## Decisions

### Body type selection

| Use case | Body type | Why |
|----------|-----------|-----|
| Static geometry (floors, walls, furniture that never moves) | `StaticBody3D` | Zero physics cost; collision only. |
| Trigger zones (area damage, pickup radius, room transitions) | `Area3D` | Detects overlap via signals; no blocking. |
| Movable objects (crates, debris, doors with physics) | `RigidBody3D` or `AnimatableBody3D` | Needs mass/forces or kinematic animation. |

Default for level geometry: **StaticBody3D**.

### Shape type selection

| Mesh geometry | Shape type | Notes |
|---------------|------------|-------|
| Box, plane, slab | `BoxShape3D` | Fastest; matches BoxMesh exactly. |
| Capsule, pill | `CapsuleShape3D` | Matches CapsuleMesh; cheaper than convex. |
| Sphere | `SphereShape3D` | Matches SphereMesh. |
| Cylinder | `CylinderShape3D` | Matches CylinderMesh. |
| Simple convex hull (barrel, rock) | `ConvexPolygonShape3D` | Up to ~255 verts; single convex piece. Use `mesh.create_convex_shape()` at runtime or author by hand. |
| Concave / hollow / multi-part (archway, L-shaped corridor) | `ConcavePolygonShape3D` | Expensive; static bodies only. Last resort. |

Default for box placeholders: **BoxShape3D** with `size` matching the mesh.

### Node structure

Two patterns; choose based on whether the mesh already exists as a root:

**Pattern A — Mesh is a child (recommended for new work)**
```
StaticBody3D          <- physics root
  MeshInstance3D      <- visual
  CollisionShape3D    <- collision
```
Body holds the transform; mesh and shape are at local origin with zero transform.

**Pattern B — Wrap existing MeshInstance3D**
When a bare MeshInstance3D already exists and renaming would break references:
```
MeshInstance3D        <- keep original name/position
  StaticBody3D        <- child at local origin
    CollisionShape3D  <- shape matches parent mesh size
```
StaticBody3D and CollisionShape3D have no transform; shape size matches the parent mesh.

This project prefers **Pattern A** for clarity. Use Pattern B only when refactoring cost outweighs restructuring.

---

## Pattern

For each MeshInstance3D that needs collision:

1. **Identify mesh size.** Read the mesh resource (e.g., `BoxMesh.size = Vector3(8, 0.2, 8)`).
2. **Create matching shape resource.** Same type and dimensions (e.g., `BoxShape3D.size = Vector3(8, 0.2, 8)`).
3. **Choose structure.** Pattern A (body as parent) or Pattern B (body as child).
4. **Wire up.**
   - Pattern A: StaticBody3D at world position, MeshInstance3D and CollisionShape3D as children at local `(0,0,0)`.
   - Pattern B: StaticBody3D as child of MeshInstance3D at local `(0,0,0)`, CollisionShape3D as child of that.
5. **Verify.** Run `godot-verify`; then F5/F6 and confirm the player cannot walk through the surface.

---

## Implementation steps (for godot-dev)

Given a target scene path (e.g., `levels/basic_room.tscn`):

1. Open the `.tscn` file; list all MeshInstance3D nodes lacking a sibling or child CollisionShape3D.
2. For each:
   - Determine mesh type and size from the `[sub_resource]` block.
   - Add a `[sub_resource type="<Shape>Shape3D" id="..."]` with matching `size` (or `radius`/`height`).
   - Restructure the node tree per Pattern A or B.
   - Use `position = Vector3(...)` and `rotation_degrees = Vector3(...)` only; never `transform = Transform3D(...)`.
3. Run `godot-verify` (property check + smoke run + render check).
4. Human verification: F5, walk the player into each surface; confirm blocking collision.

---

## .tscn conventions (Godot 4.x)

- Use `position`, `rotation_degrees`, `size` properties; never hand-write `Transform3D` matrices.
- Node names PascalCase (`WallNorth`, `FloorCollision`).
- Sub-resource IDs: descriptive suffix (`BoxShape3D_wall_north`).
- Shape `size` must exactly match mesh `size` for box/capsule/cylinder; visual and collision diverge otherwise.

---

## Out of scope

- Generating collision from imported .glb/.gltf meshes (use Godot's import settings or `create_trimesh_static_body()`; separate pattern doc if needed).
- Runtime procedural collision (e.g., destructible walls) — not a static-scene concern.
- Composite collision (multiple shapes per body) — complexity beyond POC.
- Physics layers/masks — default layer 1 is fine for POC; configure when distinct collision groups are needed.

---

## Later

- Pattern doc for imported-mesh collision (glTF import settings, `create_convex_shape()`, `create_trimesh_static_body()`).
- Collision layers/masks policy when enemies, projectiles, or triggers exist.
- AnimatableBody3D for doors/elevators that move on a path.

---

## Open questions

None — this is a reference pattern; scene-specific decisions (which nodes, which structure) are made at invocation time.
