---
name: godot-audio
description: Add sound to a 3D-pixel-art FPS POC in Godot 4.6 — a Master→SFX/Music bus layout authored as default_bus_layout.tres, the AudioStreamPlayer (global/UI) vs AudioStreamPlayer3D (spatial enemy) choice, SFX-vs-music import settings (loop off vs loop on, force-mono for 3D), a one-shot "fire-and-free" play pattern triggered at an existing entity seam with NO global AudioManager autoload, and a "despawn SFX" pattern (reparent the player to a surviving node before the owner queue_free()s so the tail isn't cut). Use when a task needs sound — "play a fire SFX", "weapon sound", "audio bus", "SFX bus", "spatial enemy audio", "footstep/hit/death sound", "background music" — when an AudioStreamPlayer plays nothing or on the wrong bus, when overlapping shots cut each other off, when a death/hit/impact sound is cut short because its node frees itself mid-sound, or when deciding positional vs non-positional audio. NO autoload music/SFX manager, NO volume/options UI, NO adaptive-music streams (out of POC scope; parked below).
---

# Godot Audio (bus layout + per-entity one-shot SFX)

Sound is two separable concerns: **routing** (a bus layout the project can mix) and **triggering** (a player node that fires at a gameplay event). We keep both native and composed: the bus layout is a saved `default_bus_layout.tres` resource wired in project settings once, and every sound is an `AudioStreamPlayer` child of the entity that makes it, played at the entity's existing event seam — NOT a global AudioManager autoload. This matches composition-over-inheritance (sound is a component child, triggered where the event already fires) and keeps each entity self-contained. Non-positional `AudioStreamPlayer` for things attached to the listener (weapon/UI/music); `AudioStreamPlayer3D` only when a sound has a world position the player should localise (enemy in the room next door).

## Requirements

- `godot-code-rules` — every `.gd` here is strict typed GDScript: line-1 path header, `class_name`, typed vars/returns, `tools/validate.sh` gate. Load BEFORE writing any file below.
- `godot-composition` — the sound player is a component child of the firing entity; trigger it at the seam that already fires (e.g. where `Weapon.try_fire()` returns `true`), do not add a manager that reaches across entities.
- `godot-verify` — after any `.tscn`/`.gd` change, scenes must load + render with no "stream not found"/import errors. The ear-check ("sounds good", "doesn't cut off") is human-only; verify does not cover it.
- An audio asset on disk: a CC0 one-shot in `assets/audio/<name>.<ext>` (see below). `assets/` is gitignored; the file is sourced via the asset loop.

## Project conventions

- **Audio asset path**: `assets/audio/<name>.<ext>`, snake_case, mirrors `assets/textures/` and `assets/models/`. `assets/` is gitignored. Referenced as `res://assets/audio/<name>.<ext>`. Shared CC0 example audio (if used) resolves under `res://x-shared-assets/audio/<name>.<ext>`, same import rules.
- **Format**: short SFX → **WAV** (16-bit, 44.1 kHz; stored uncompressed in the PCK, zero decode latency, plays instantly). Music/long ambient → **OGG Vorbis**. Avoid MP3 for timing-critical SFX (encoder padding adds silence at the start).
- **Bus layout** (`default_bus_layout.tres` at project root): `Master` → child `SFX`, `Master` → child `Music`. Music bus is defined now even if empty so later music work needs no re-layout. Set `audio/buses/default_bus_layout` in project settings to this resource (godot-dev's call, not a hand-edit by the designer).
- **Bus assignment**: every `AudioStreamPlayer`/`AudioStreamPlayer3D` sets `bus = "SFX"` (or `"Music"`). Case-sensitive, must match a bus name exactly.
- **Node choice**: weapon/UI/music sit at the listener → non-positional `AudioStreamPlayer`. A sound with a world position the player should localise (enemy, environmental) → `AudioStreamPlayer3D` child of that entity. The current `Camera3D` inside the SubViewport rig is the listener by default — no explicit `AudioListener3D` needed unless the listening point must differ from the camera.
- **No autoload**: there is no `AudioManager`/`MusicManager`/`SFXPool` singleton. Players live on entities. Revisit a pool only if overlap-cutoff is actually observed (see step 4).

## Steps

### 1. Author the bus layout

In the editor: bottom panel → **Audio** tab → Add Bus twice → rename to `SFX` and `Music` → leave both routed to `Master` (the default). Then the layout menu → **Save As** → `res://default_bus_layout.tres`.

Wire it once in **Project → Project Settings → Audio → Buses → Default Bus Layout** = `res://default_bus_layout.tres` (sets `audio/buses/default_bus_layout` in `project.godot`).

### 2. Import the SFX with loop OFF

Drop the WAV in `assets/audio/`. Select it → **Import** dock:

- **Loop Mode**: `Disabled` (one-shot SFX must not loop). For **music** OGG instead: **Loop** = On, set Loop Offset at the bar.
- **Force Mono**: On **only** for an `AudioStreamPlayer3D` source (stereo does not spatialise). Leave stereo for non-positional `AudioStreamPlayer`.
- Click **Reimport**.

### 3. Add the player on the entity and trigger at the seam

Add an `AudioStreamPlayer` child to the firing entity (e.g. the `Weapon` node), set its `stream` to the imported WAV and `bus = "SFX"` in the Inspector. Trigger it where the gameplay event already fires — for the weapon, where `try_fire()` returns `true`, so cadence matches the cooldown, not raw input:

```gdscript
# entities/weapon/weapon.gd
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx


func try_fire() -> bool:
	if not _cooldown.is_stopped():
		return false
	_fire()
	_fire_sfx.play()  # restarts from frame 0 each shot — fire-and-free, no manual stop
	_cooldown.start()
	return true
```

`play()` on a one-shot stream plays once and stops itself — "fire-and-free", no cleanup needed. Calling `play()` again restarts it from the start (fine when the cooldown spaces shots out).

For a **spatial** sound (P3 enemy), the only change is the node type and that it lives on the world-positioned entity:

```gdscript
# entities/enemy/enemy.gd
@onready var _attack_sfx: AudioStreamPlayer3D = $AttackSfx  # bus = "SFX", stream = mono WAV
# ...play _attack_sfx in the attack state's enter, same fire-and-free call.
```

### 4. Despawn SFX — when the owner frees itself mid-sound

Fire-and-free assumes the player's owner node stays alive until the sound ends. It does NOT hold when the entity `queue_free()`s itself the *same frame* it triggers the sound — projectile-on-hit, enemy-on-death. The player is freed mid-playback and its tail is cut.

Fix: **detach the player to a surviving node before the owner frees**, and let the player free itself when done. Reparent to `get_tree().current_scene` (the loaded level/scene root — a node guaranteed to outlive this entity), connect `finished` to the player's own `queue_free`, then `play()`. No autoload, no manager: the player just outlives its old parent for the length of one sound, then cleans itself up.

**Non-positional** (`AudioStreamPlayer`) — position is irrelevant, so reparent and play:

```gdscript
# entities/projectile/projectile.gd
@onready var _hit_sfx: AudioStreamPlayer = $HitSfx


func _on_body_entered(body: Node3D) -> void:
	hit.emit(body)
	# ...duck-typed on_hit() notification...
	_play_hit_sfx()
	queue_free()  # owner frees this frame — _hit_sfx already detached, survives


# Reparent the one-shot player to the scene root so it survives queue_free() on this node.
func _play_hit_sfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_hit_sfx.reparent(scene_root)
	# AudioStreamPlayer is non-positional — position irrelevant; just play and auto-free on finish.
	# Idempotent: the seam that calls this (body_entered / on_hit) can fire more than once
	# before the owner frees — re-connecting the same callable throws "Signal already
	# connected to given callable". Guard it (or connect with CONNECT_ONE_SHOT).
	if not _hit_sfx.finished.is_connected(_hit_sfx.queue_free):
		_hit_sfx.finished.connect(_hit_sfx.queue_free)
	_hit_sfx.play()
```

The enemy death sound is the same shape (also stop any looping ambient on that enemy first, so it doesn't get reparented and orphaned):

```gdscript
# entities/enemy/enemy.gd
@onready var _death_sfx: AudioStreamPlayer = $DeathSfx
@onready var _ambient_sfx: AudioStreamPlayer3D = $EnemyAmbientSfx


func on_hit() -> void:        # duck-typed call from the projectile
	_play_death_sfx()
	died.emit(self)
	_flash_and_die()          # tweens, then queue_free()


func _play_death_sfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_ambient_sfx.stop()       # stop the looping ambient that stays with the freed enemy
	_death_sfx.reparent(scene_root)
	# Idempotent — on_hit can run again (multi-hit enemy) before the death frame frees us.
	if not _death_sfx.finished.is_connected(_death_sfx.queue_free):
		_death_sfx.finished.connect(_death_sfx.queue_free)
	_death_sfx.play()
```

**Positional** (`AudioStreamPlayer3D`) — reparenting changes the node's parent, so its `global_position` snaps to the new parent's frame (origin if the scene root sits at origin). Capture the world position **before** reparenting and restore it **after**, so the sound stays where the event happened:

```gdscript
func _play_impact_sfx_3d() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var world_pos: Vector3 = _impact_sfx.global_position  # capture BEFORE reparent
	_impact_sfx.reparent(scene_root)
	_impact_sfx.global_position = world_pos                # restore AFTER reparent — don't snap to origin
	_impact_sfx.finished.connect(_impact_sfx.queue_free)
	_impact_sfx.play()
```

`reparent(scene_root)` (no `keep_global_transform` arg) defaults to keeping the global transform — but the explicit capture/restore is the safe contract: it survives a `top_level` player or a non-identity scene-root transform, both of which break the default. Always capture/restore for the 3D case.

### 5. Only if overlap cutoff is observed — raise polyphony or pool

A single `AudioStreamPlayer.play()` restarts the stream, so very rapid fire can clip the tail of the previous shot. Cheapest fix first: set `max_polyphony` on the player (e.g. `2`–`4`) so a new `play()` layers instead of cutting.

```gdscript
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx


func _ready() -> void:
	_fire_sfx.max_polyphony = 4  # overlapping shots layer instead of cutting off
```

Only if `max_polyphony` is still not enough (many simultaneous distinct sounds across an entity), add a small **per-entity** pool component — a `Node` child holding N `AudioStreamPlayer` children, round-robin on `play()`. Keep it on the entity, NOT a global autoload:

```gdscript
# entities/weapon/sfx_pool/sfx_pool.gd - round-robin one-shot players, owned by one entity.
class_name SfxPool
extends Node

@export var pool_size: int = 4
@export var bus: StringName = &"SFX"

var _players: Array[AudioStreamPlayer] = []
var _index: int = 0


func _ready() -> void:
	for _i: int in pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)


func play(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players[_index]
	_index = (_index + 1) % pool_size
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()
```

### 5b. Voice-cap a sound against spiking (suppress the Nth simultaneous copy)

`max_polyphony` lets overlapping shots **layer** — it does NOT suppress the Nth copy when
dozens of the same SFX collide in one frame (a wave of enemies all dying together, a shotgun
hitting multiple bodies). Layering N copies at once pushes the sum over 0 dBFS → distortion /
clipping that `max_polyphony` cannot fix. Fix: track an **active count** per sound id, suppress
the `play()` call when count ≥ cap, decrement on `finished`.

This is a per-entity component, no autoload. Add a `Node` child — `VoiceLimiter` — to the
entity that owns the `AudioStreamPlayer`(s):

```gdscript
# entities/weapon/voice_limiter/voice_limiter.gd
# Per-entity voice cap — suppresses the Nth simultaneous play() of the same sound id.
class_name VoiceLimiter
extends Node

@export var max_voices: int = 4  # default cap; override per-entity in the Inspector

## Active-count map: sound id (StringName) → how many copies are currently playing.
var _active: Dictionary[StringName, int] = {}


## Try to play `stream` identified by `id` through `player`.
## Returns false and plays nothing if the active count is already at cap.
## Optionally randomises pitch in [min_pitch, max_pitch] for variation.
func try_play(
    id: StringName,
    player: AudioStreamPlayer,
    stream: AudioStream,
    min_pitch: float = 1.0,
    max_pitch: float = 1.0,
) -> bool:
    var count: int = _active.get(id, 0)
    if count >= max_voices:
        return false
    _active[id] = count + 1
    player.stream = stream
    player.pitch_scale = randf_range(min_pitch, max_pitch)
    # Decrement on finish — CONNECT_ONE_SHOT so the callable fires once then auto-disconnects.
    # Guard with is_connected in case the same player is reused before the signal fires.
    var callable := _decrement.bind(id)
    if not player.finished.is_connected(callable):
        player.finished.connect(callable, CONNECT_ONE_SHOT)
    player.play()
    return true


func _decrement(id: StringName) -> void:
    _active[id] = maxi(0, _active.get(id, 0) - 1)
```

Wire it at the seam where the sound fires — replace a bare `player.play()` call with
`_voice_limiter.try_play(...)`:

```gdscript
# entities/weapon/weapon.gd
@onready var _fire_sfx: AudioStreamPlayer = $FireSfx
@onready var _voice_limiter: VoiceLimiter = $VoiceLimiter


func try_fire() -> bool:
    if not _cooldown.is_stopped():
        return false
    _fire()
    # id = stable StringName matching the sound; pitch drifts ±5 % for variety.
    _voice_limiter.try_play(&"weapon_fire", _fire_sfx, _fire_sfx.stream, 0.95, 1.05)
    _cooldown.start()
    return true
```

Key points:

- `Dictionary[StringName, int]` typed dict — strict GDScript compliant.
- `CONNECT_ONE_SHOT` fires the decrement once and removes itself — no manual disconnect, no
  "Signal already connected" risk on the next `try_play` for the same `id`.
- `randf_range(min_pitch, max_pitch)` — pass equal values (both `1.0`) for no pitch drift; widen
  the range (e.g. `0.9`–`1.1`) on repetitive gen_sfx placeholders to reduce robotic repeat.
- Cap is an `@export var max_voices: int` — set per-entity in the Inspector, no hardcoded magic
  number.
- This lives **alongside** the round-robin pool from step 5: pool = no instancing churn (reuses
  N players); voice-cap = suppress the spike (stops N copies of one sound from stacking). Both
  can coexist on the same entity. Pool is optional; voice-cap is the anti-spike fix.
- For a `AudioStreamPlayer3D` spatial source, same pattern — swap the type in the `try_play`
  signature (or add an overload); the count/decrement logic is identical.

### 6. Validate and verify

Run `tools/validate.sh` on any `.gd` touched. Run `godot-verify` — scenes load + render, no "stream not found"/import errors.

## Verification checklist

- Audio dock shows `Master → SFX` and `Master → Music`; `project.godot` has `audio/buses/default_bus_layout="res://default_bus_layout.tres"`.
- F5, fire the weapon: a short shot sound plays, once per shot, at the cooldown cadence (not faster than the fire rate).
- Rapid fire does not harshly cut the previous shot (tail audible, or layered if polyphony was raised).
- In the Audio dock, **mute** (or lower) the `SFX` bus → the shot silences/quietens; muting `Master` silences everything. Proves routing.
- (P3) A spatial `AudioStreamPlayer3D` sound gets quieter with distance and pans with the camera's facing.
- Shoot an enemy / hit something that despawns: the hit/death sound plays to its full tail AFTER the entity has visibly disappeared (not clipped the instant it frees).
- (3D despawn) The detached impact sound still comes from where the event happened, not the world origin.
- No orphaned players accumulate: after several despawns the scene tree has no leftover `*Sfx` nodes under the scene root (they self-free on `finished`).
- No errors in the Output panel about a missing stream or failed import.

## Error → Fix

| Symptom | Fix |
|---|---|
| No sound at all | Player not in the tree when `play()` runs — ensure it's a child added before play; check `stream` is assigned. |
| Plays but silent | `bus` name doesn't match (case-sensitive) or that bus is muted — check `bus = "SFX"` and the dock. |
| SFX loops forever | Import → Loop Mode = Disabled, Reimport (looping is on the stream resource, not the node). |
| Rapid fire cuts the previous shot | Raise `max_polyphony` (step 5); pool only if that's still not enough. |
| Dozens of the same SFX hit in one frame → distortion / clipping | N copies of one sound stack and sum over 0 dBFS. `max_polyphony` layers them — it does NOT suppress. Add a `VoiceLimiter` component (step 5b): tracks `Dictionary[StringName id -> int]` active count, suppresses `play()` when count ≥ `max_voices`, decrements on `finished` via `CONNECT_ONE_SHOT`. |
| Hit/death/impact sound cut short the instant the entity dies | Owner `queue_free()`s mid-sound, taking the player with it — use the despawn pattern (step 4): `reparent(get_tree().current_scene)`, `finished.connect(queue_free)`, then `play()`. |
| `Signal already connected to given callable` on the despawn-SFX connect | The despawn seam (`body_entered` / `on_hit`) ran more than once before the owner froze, re-connecting `finished` → `queue_free`. Guard it: `if not player.finished.is_connected(player.queue_free): ...` (or connect with `CONNECT_ONE_SHOT`). Also fix the multi-fire at its source — see `godot-travelling-projectile-3d`. |
| Despawn 3D sound jumps to the world origin (or to the wrong spot) | Reparent dropped the world position — capture `global_position` BEFORE `reparent`, restore it AFTER (step 4, positional case). |
| Looping ambient keeps playing after the enemy dies / orphaned ambient node | The looping `AudioStreamPlayer3D` got reparented and never stops — `stop()` it before reparenting only the one-shot death player (step 4 enemy example). |
| 3D sound is flat / no spatialisation | Source WAV is stereo — Import → Force Mono = On, Reimport; confirm a current `Camera3D`/`AudioListener3D` exists. |
| "Stream not found" on load | Path typo or `assets/audio/` file missing (gitignored) — re-source the asset; reference `res://assets/audio/<name>.<ext>`. |
| MP3 SFX has a gap at the start | MP3 encoder padding — re-source as WAV for timing-critical SFX. |

## Parked (in the library if needed later)

The GodotPrompter `audio-system` skill also covers, out of this POC's scope: an autoload **MusicManager** with crossfade (conflicts with the no-autoload/composition convention — revisit only if music must survive level swaps under `Main/LevelHost`), a **volume settings menu** with `linear_to_db`/`db_to_linear` slider helpers and `ConfigFile` persistence (options UI is out for the whole roadmap), bus **effects** (reverb/low-pass/compressor) and runtime effect toggling, and **adaptive music** streams (`AudioStreamPlaylist`/`Synchronized`/`Interactive`). Pull these in only when a roadmap phase asks for them.

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
