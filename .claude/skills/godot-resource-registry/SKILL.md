---
name: godot-resource-registry
description: Build a typed id-keyed catalog over a family of custom Resources in Godot 4.6 — a generic ResourceRegistry base (extends Resource) that dir-scans a folder at boot into {StringName id -> Resource}, push_errors on a duplicate or empty id, hard-asserts on a missing id, and is subclassed per family by a THIN child that sets FOLDER + adds a typed convenience accessor. Use when a task needs string-id lookup of authored .tres — "get_archetype(\"grunt\")", "look up a CastData/EnemyArchetype/LevelConfig by id", "registry/catalog of resources", "load all .tres in a folder", "reference an archetype by name from save data", "id-indexed resource table" — or when direct @export slots can't address a Resource by a data-portable string id. NOT the Resource-authoring/composition pattern (that is godot-data-driven-effect-composition / godot-data-driven-enemy / cast-system) — this is the id-indexed RETRIEVAL layer over Resources those skills author.
---

# godot-resource-registry

A registry is a thin `{StringName id -> Resource}` lookup over one family of authored `.tres` files. We build it as a **generic `ResourceRegistry` base (extends Resource) that dir-scans its folder once at boot**, with each family adding a **thin subclass** — not an autoload, not a `ResourcePreloader` node — because a scanned registry needs zero per-file upkeep (drop a new `.tres` in the folder, it appears), keeps the catalog out of global singleton state (composition over autoloads), and stays a typed value a consumer holds by `@export` or `preload`. The base owns ALL shared mechanism once (scan, dict, duplicate/empty-id `push_error`, fail-fast lookup); a family subclass only sets the `FOLDER`, names the expected type, and exposes a typed accessor. GDScript has no real generics, so the base getter returns `Resource` and each subclass adds a typed wrapper that casts — no `Variant` leak. The registry is **additive**: direct typed `@export` slots stay for Inspector-draggable, type-checked wiring; the registry adds string-id addressing for data-portable references (save files, wave/level data, console). Lookups **fail fast** — a duplicate id `push_error`s at scan, a missing id is a hard `assert` — so a typo never silently returns `null`.

## Requirements

- `godot-code-rules` applied — strict typed GDScript, no untyped/Variant leak, explicit return types.
- The Resource family already authored as typed `.tres` (`godot-data-driven-effect-composition` / `godot-data-driven-enemy` / `cast-system`). This skill indexes them; it does not author them.
- Each indexed Resource class carries an `@export var id: StringName` field, unique within its folder.

## Project conventions

- Resource families + folders: `EnemyArchetype` (`tools/lib/enemy/enemy_archetype.gd`) → `.tres` in `archetypes/`; `BossData` (`tools/lib/enemy/boss_data.gd`); `CastData` (`tools/lib/cast/cast_data.gd`); `LevelConfig` (`tools/lib/level/level_config.gd`). All `extends Resource`.
- The base `ResourceRegistry` lives in `tools/lib/resource_registry.gd` (reusable cross-entity glue belongs in `tools/lib/`). Each subclass lives beside the family it indexes (e.g. `tools/lib/enemy/archetype_registry.gd`).
- One registry SUBCLASS per family — keep families separate (an archetype registry ≠ a cast registry), don't build one god-catalog.
- `id` is `StringName` (cheap compare, hashes well as a dict key), authored in the Inspector on each `.tres`. snake_case ids (`"grunt"`, `"tank_shooter"`).
- Registry is a value, not a singleton: a consumer holds it via `@export var registry: ArchetypeRegistry` or `preload`s the registry `.tres`. NO autoload (godot-composition).
- Coexistence: existing direct `@export` slots (e.g. `wave_manager.spawn_archetype: EnemyArchetype`) stay as-is — type-checked, Inspector-draggable. Use the registry only where a string id is the natural key (save data, level/wave tables, debug commands). Both reference the SAME `.tres` on disk.

## Steps

1. Author the generic base ONCE — holds every shared mechanism; subclasses override `FOLDER` and read `_by_id`:

```gdscript
# tools/lib/resource_registry.gd
class_name ResourceRegistry
extends Resource

## Generic {StringName id -> Resource} catalog over a folder of .tres.
## Subclass per family: override FOLDER + add a typed accessor wrapping get_by_id().
## Not an autoload: a consumer holds this via @export or preload.

## Subclass MUST override with its family's folder, e.g. "res://archetypes/".
const FOLDER: String = ""

var _by_id: Dictionary[StringName, Resource] = {}
var _loaded: bool = false


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var folder: String = _folder()
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		push_error("ResourceRegistry: cannot open '%s'" % folder)
		return
	for file_name: String in dir.get_files():
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var res: Resource = ResourceLoader.load(folder.path_join(file_name))
		if res == null:
			continue
		var rid: StringName = _id_of(res)
		if rid == &"":
			push_error("ResourceRegistry: '%s' has empty id" % file_name)
			continue
		if _by_id.has(rid):
			push_error("ResourceRegistry: duplicate id '%s' (%s)" % [rid, file_name])
			continue
		_by_id[rid] = res


## Reads the subclass's FOLDER const through the script (const is not virtual).
func _folder() -> String:
	var script: GDScript = get_script() as GDScript
	var folder: String = script.get_script_constant_map().get("FOLDER", FOLDER)
	return folder


## Pulls the id off a scanned Resource via the duck-typed `id` field.
func _id_of(res: Resource) -> StringName:
	if not (&"id" in res):
		return &""
	return res.get(&"id")


## Fatal on a missing id — a typo must never silently yield null.
## Subclasses wrap this with a typed cast (get_archetype, get_cast, ...).
func get_by_id(id: StringName) -> Resource:
	_ensure_loaded()
	assert(_by_id.has(id), "ResourceRegistry: unknown id '%s'" % id)
	return _by_id[id]


func has_id(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)


func ids() -> Array[StringName]:
	_ensure_loaded()
	return _by_id.keys()
```

2. Add the `id` field to each indexed Resource class (once per family) — the registry key:

```gdscript
# tools/lib/enemy/enemy_archetype.gd
class_name EnemyArchetype
extends Resource

@export var id: StringName = &""    # unique within archetypes/; the registry key
@export var display_name: String = "Grunt"
# ... existing stats ...
```

3. Author the THIN per-family subclass — set `FOLDER`, add a typed accessor that casts the base result. Worked example, `ArchetypeRegistry` over `archetypes/`:

```gdscript
# tools/lib/enemy/archetype_registry.gd
class_name ArchetypeRegistry
extends ResourceRegistry

const FOLDER: String = "res://archetypes/"


## Typed wrapper over ResourceRegistry.get_by_id() — GDScript has no generics,
## so the base returns Resource and we cast to the family type here.
func get_archetype(id: StringName) -> EnemyArchetype:
	return get_by_id(id) as EnemyArchetype
```

That is the WHOLE subclass — no scan, no dict, no fail-fast logic duplicated; all inherited.

4. Author one registry `.tres` (`archetypes/archetype_registry.tres`, or wherever the consumer expects it) so it can be `@export`-wired or `preload`ed. The registry holds no Inspector data — it scans — so the `.tres` is just a typed handle of the subclass type.

5. Wire a consumer by id WITHOUT removing its existing slot:

```gdscript
# a consumer that resolves a string id (e.g. from save/level data)
@export var registry: ArchetypeRegistry
@export var spawn_archetype: EnemyArchetype   # existing direct slot — keep it

func spawn_by_id(id: StringName) -> void:
	var arch: EnemyArchetype = registry.get_archetype(id)
	_spawn(arch)
```

6. Add another family the same way — a new thin subclass only (e.g. `CastRegistry extends ResourceRegistry`, `FOLDER = "res://entities/weapon/"`, `func get_cast(id) -> CastData`). Never merge families into one registry; never re-implement the scan.

## Verification checklist

- A fresh `.tres` dropped in the folder is returned by `get_archetype()` with no code change.
- `get_archetype("grunt")` returns the same object as the direct `@export` slot pointing at `grunt.tres` (one `.tres`, two reference paths).
- Two `.tres` with the same `id` → a `duplicate id` error in the Output log at first lookup; second is skipped, not silently overwritten.
- `get_archetype(&"typo")` halts in a debug build (assert) rather than returning `null` and crashing later.
- The subclass file holds ONLY `FOLDER` + the typed accessor — no scan/dict/fail-fast code (it all lives in the base).
- `tools/validate.sh` passes (typed dict, explicit return types, no Variant leak — the cast is contained in the typed wrapper).
- A headless `tools/smoke_*.gd` boots, calls `get_archetype()` for a known id, and asserts the returned type + a field — registry resolves at runtime (godot-runtime-smoke).

## Error → Fix

| Symptom | Fix |
|---|---|
| `cannot open 'res://…/'` | Subclass `FOLDER` wrong/empty or folder absent — set the subclass const / create the folder. |
| Scan reads the base `FOLDER` ("") not the subclass's | `_folder()` reads the const via `get_script()` — confirm the subclass declares its own `const FOLDER`. |
| `get_archetype` returns wrong/empty type | `.tres` not the expected class, or `as Type` cast nulled it — confirm `class_name` + `@export var id`. |
| `duplicate id` error | Two `.tres` share an `id` — make ids unique within the folder. |
| Lookup returns `null` instead of asserting | A subclass bypassed `get_by_id` — always wrap the base getter; the assert lives there. |
| `id` empty / not matching | `id` left at `&""` in the Inspector — author it on each `.tres`. |
| `UNTYPED_DECLARATION` at `_by_id` | Type the dict on the BASE: `Dictionary[StringName, Resource]`; cast only in the subclass wrapper. |
| Scan finds nothing | Resource lacks an `id` field — `_id_of` returns `&""` and skips; add `@export var id: StringName`. |
| Registry as autoload feels tempting | Don't — hold it via `@export`/`preload`; autoload violates composition-over-autoloads. |

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
