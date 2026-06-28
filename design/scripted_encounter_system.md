# Scripted Encounter System

**Goal** — Hand-placed, progression-gated room spawns: a room's enemies spawn when the player enters, a locked door opens when they're all dead, the next room then arms. Authored as DATA (one resource per room), driven by a small generic controller. New rooms = new `.tres`, no new code branches.

## Scope (in)

- **`RoomEncounter extends Resource`** (`tools/lib/encounter/room_encounter.gd`) — pure data, one per room:
  - `id: StringName`
  - `spawns: Array[RoomSpawn]` — each = `{ archetype: EnemyArchetype, spawn_marker_id: StringName }` (where to place which enemy; hand-placed, NO ratios/randomness).
  - `hint_text: String` — the teach line shown on the HUD when the room arms (e.g. `"FIRE-IMMUNE — try ICE (R)"`). Empty = no hint.
  - `clear_advances: bool = true` — when all spawned enemies of this room are dead, fire `room_cleared(id)`.
- **`RoomSpawn extends Resource`** (`tools/lib/encounter/room_spawn.gd`) — the `{archetype, spawn_marker_id}` pair. Tiny.
- **`RoomController extends Node`** (`entities/encounter/room_controller.gd`) — the generic driver, sits in the level beside (eventually instead of) WaveManager:
  - `@export var encounters: Array[RoomEncounter]` — ordered A.1, A.2, A.M, …
  - `@export var room_trigger_paths: Array[NodePath]` — one `Area3D` trip-wire per room (player enters → arm that room's encounter).
  - `@export var door_paths: Array[NodePath]` — one door node per room (StaticBody3D that hides+disables collision on open).
  - Holds the generic enemy scene + a marker registry (`StringName id → Marker3D`) wired by `@export var spawn_marker_paths: Array[NodePath]` (markers carry their id in a `marker_id` export or node name).
  - On room trip-wire entered (one-shot): instance each `RoomSpawn`'s archetype-driven enemy at its marker; track them; emit `hint_changed(hint_text)`; lock that room's door.
  - On each tracked enemy `died`: decrement; when count hits 0 and `clear_advances`, open the door (hide mesh + `set_deferred("disabled", true)` on its collider) and emit `room_cleared(id)`.
  - Spawn-instancing pattern: assign `enemy.archetype`, layer 8 / mask 1, connect `died` — extract to `tools/lib/enemy/enemy_utils.gd` if duplicated (2nd-duplication rule).
  - Signals UP: `score_changed(total)`, `active_changed(count)`, `run_lost(score)`, `advance_level(score)`, `hint_changed(text)`.
- **HUD hint**: add `set_hint(text: String)` to `ArenaHud` — a transient centered label that fades after ~3 s (reuse the existing Tween pattern). `main.gd` connects `room_controller.hint_changed → _arena_hud.set_hint`.
- **main.gd**: `load_level` wires `RoomController` signals. RoomController is the sole level controller (WaveManager retired).

## Scope (out)

- WaveManager (retired) — not used. RoomController is the sole controller.
- Random spawning, close-ring, escalation, lap-scaling — RoomController is fully scripted; no randomness (cut: that's WaveManager's job; brief forbids randomness pre-boss).
- Boss spawning — boss lives in its own room/encounter, handled in slice 3/4 (cut: separable).
- Checkpoints, backtracking, re-locking doors (cut: linear one-way POC).

## Acceptance

- Headless smoke (`tools/smoke_encounter.gd`): boot a 2-room fixture; trip room 1 → N enemies spawn at the right markers, door locked; kill them → `room_cleared` fires, door collider disabled; trip room 2 → its enemies spawn. Assert spawn counts, `room_cleared` arity, door `disabled == true` after clear.
- `hint_changed` emits the encounter's `hint_text` on arm.
- validate.sh clean (strict typed GDScript; no untyped, no autoload sneak-in).
- No "Signal already connected" across repeated room arms (one-shot trip-wire).

## Skill notes

- `godot-data-driven-effect-composition` — RoomEncounter/RoomSpawn are the Resource-graph; RoomController is the generic consumer. New room = new `.tres`.
- `godot-resource-registry` — markers/encounters addressed by `StringName` id (the registry convention); a full ResourceRegistry subclass is optional, an `@export Array` is enough for v1.
- `godot-runtime-smoke` — the smoke fixture is the gate; mirror WaveManager's seams.
- `godot-composition` — RoomController signals up; main.gd owns wiring. Door = data the controller toggles, not a new system.
- `godot-code-rules` — strict typed; guard duck-typed enemy `died`/`archetype` seams with `@warning_ignore`.

## Later

- Promote shared spawn-instancing to `enemy_utils`.
- ResourceRegistry subclass for encounters if id-lookup from save/level data is needed.
- Re-lockable doors / two-way corridors.

## Open questions

(none — defaults applied.)
