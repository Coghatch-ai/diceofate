# Interaction System

**Goal** — Player can interact with objects by pressing a button while overlapping them; message objects print text, inventory objects add to a list and disappear.

**Scope (in)**
- New input action `interact` (keyboard: E).
- New entity `res://entities/interactable/interactable.tscn`: root `Interactable` (Area3D), children `CollisionShape3D` (BoxShape3D, default 1x1x1), `MeshInstance3D` (BoxMesh placeholder, same size, flat color material).
- New script `res://entities/interactable/interactable.gd` attached to root:
  - Enum `Type { MESSAGE, INVENTORY }`.
  - Exports: `type: Type`, `message_text: String` (used when MESSAGE), `item_name: String` (used when INVENTORY).
  - Tracks overlapping bodies in a Set (use `body_entered` / `body_exited` signals, filter for Player group).
  - On `_input` when `interact` just pressed and player is overlapping:
    - MESSAGE: `print(message_text)`.
    - INVENTORY: `print("Picked up: ", item_name)`, call `player.add_item(item_name)`, then `queue_free()` self.
- Add Player to group `"Player"` in `player.tscn` (node Groups property).
- Add to `player.gd`:
  - `var inventory: Array[String] = []`
  - `func add_item(item: String) -> void: inventory.append(item); print("Inventory: ", inventory)`
- Place two test instances in `basic_room.tscn`:
  - One MESSAGE at `(2, 0.5, 0)` with `message_text = "Hello from the box"`.
  - One INVENTORY at `(-2, 0.5, 0)` with `item_name = "Key"`.

**Scope (out)**
- Visual indicator for interactables (outline, prompt) — deferred; pure logic this slice.
- Proximity prints ("Near: X") — noise, cut.
- Inventory UI — console print only.
- Persistence / save — in-memory Array only.
- Multiple items per object, stacking, quantities — one item_name string, no count.
- Interaction priority when overlapping multiple objects — first in Set wins (undefined order acceptable for POC).

**Acceptance**
- `$GODOT --headless --path . --script tools/verify_scene.gd -- entities/interactable/interactable.tscn entities/player/player.tscn levels/basic_room.tscn main.tscn` prints `VERIFY: OK`.
- Smoke run: `$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR"` finds nothing.
- F5:
  - Walk into the MESSAGE box, press E — console prints "Hello from the box".
  - Walk into the INVENTORY box, press E — console prints "Picked up: Key" then "Inventory: [Key]", box disappears.
  - Press E while not overlapping anything — nothing happens, no error.

**Skill notes**
- `godot-verify`: mandatory after scene/script changes.
- `godot-composition`: Interactable is its own entity; inventory Array lives on Player (single responsibility). No component extraction — first consumer.
- CLAUDE.md conventions: use `position = Vector3(...)` in .tscn; node names PascalCase; input action must be added to `project.godot` Input Map.

**Later**
- Visual indicator (glow, outline, or floating prompt) when player is near.
- Interaction priority system (closest object, or explicit priority export).
- Inventory UI (list panel, slot grid).
- Item data resource (icon, description, stack size).
- Sound effect on pickup.
- Re-enable picked-up objects (respawn, or prevent double-pickup without queue_free).

**Open questions** — none.
