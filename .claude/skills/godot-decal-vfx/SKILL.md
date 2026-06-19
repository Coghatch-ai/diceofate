---
name: godot-decal-vfx
description: >-
  Pooled, surface-projected Decal VFX for a first-person shooter POC in Godot
  4.6 Forward+ — a Node3D pool of N reused Decal slots (round-robin index) that
  project an albedo-mask texture onto whatever surface a hit reports, fade out
  over a tunable duration, and recycle. Covers the clustered (NOT deferred) cost
  model, a degenerate-safe normal→basis orientation that never collapses on
  floor/ceiling/wall, the fire-and-fade lifecycle with Tween.kill before reuse,
  and the decal-specific texture import contract (premult OFF, fix_alpha_border
  ON, mipmaps ON). Use when an impact must leave a mark on a surface — "scorch",
  "bullet hole", "blood splat", "decal on hit/impact", "pooled decal", "project
  texture on wall/floor" — when a decal flickers/leaks, when a decal is skewed
  or gapped on a vertical wall, when decals vanish past a count, or when a decal
  texture shows a white fringe or shimmers at distance. NOT the fire-and-free
  particle/mesh one-shots (muzzle/impact spark/death burst/shockwave — that is
  godot-oneshot-vfx) and NOT the projectile trail (godot-travelling-projectile-3d).
---

# Godot decal VFX (pooled, surface-projected)

A decal is a persistent mark left where an impact lands: a scorch, a bullet
hole, a blood splat. Unlike the particle one-shots in `godot-oneshot-vfx`
(spawned, emit once, free), a decal lingers and fades, and there can be many
alive at once — so the lifecycle is **pooled fire-and-fade**, not spawn-per-hit.
A `Decal` node projects its albedo-mask texture down its **local -Y axis** onto
whatever geometry sits under it, so the whole technique is: (1) bound the live
count with a fixed pool of reused slots, and (2) orient each slot's local Y to
the surface normal of the hit so the projection lies flat on the surface instead
of skewing through it.

**Cost model (verified, Godot 4.6):** Godot uses **clustered** decals — "stored
in cluster data and drawn when the mesh is drawn, they are not drawn as a
post-processing effect." Each visible Decal is **one clustered element** sharing
the **512-element budget with lights + reflection probes** (Forward+). The old
"each decal = one deferred pass" claim is FALSE — do not repeat it. Pooling is
right anyway: it bounds the live element count (so decals never silently vanish
past the 512 budget) and avoids per-hit `Decal.new()` / `queue_free()` alloc
churn — NOT because each decal is a deferred pass.

## Requirements

- Renderer **Forward+** (per `project.godot` `config/features`). `Decal` is
  Forward+/Mobile only — it renders nothing under Compatibility.
- `godot-composition` — the router that fires decals off combat seams is a plain
  component (signals up / calls down), NOT an autoload. A decal manager
  singleton contradicts CLAUDE.md.
- `godot-code-rules` — strict typed GDScript; loaded before any `.gd` edit.
- A hit normal is supplied by the combat seam. The projectile hit-signal
  (`godot-travelling-projectile-3d`) / `godot-fps-enemy-combat` carries the
  collision normal; the decal only *consumes* it — it changes no contract.

## Project conventions

- Pool + effect/pool scenes live at `entities/vfx/<name>.tscn` /
  `<name>.gd` (snake_case files). Nodes are PascalCase (`ScorchDecalPool`).
- The pool node is a child of a surviving `VfxRoot` Node3D (Main-level or
  level-local) — same survivor used by `godot-oneshot-vfx`. The pool must
  outlive any single projectile/enemy that triggers it.
- Routed off the `hit` / `died` combat seams via a **component**, never an
  autoload.
- Pool size **8**, fade **10 s** — `@export` so the art-director can tune.
- Albedo-mask texture: `res://assets/textures/scorch_decal.png` (placeholder
  from `tools/gen_textures.gd`). Import settings for a **decal mask** (its own
  contract — NOT the NEAREST/no-mip tileable-surface contract in
  `godot-texture-import-pixel-art`, NOT generation in `godot-procedural-texture`):

  | Import setting | Value | Why |
  |---|---|---|
  | `process/premult_alpha` | **FALSE** | Premult needs a Premul-Alpha blend-mode material; a `Decal` node exposes no blend-mode control → cannot consume premult correctly. |
  | `process/fix_alpha_border` | **TRUE** | Kills the white/dark fringe on alpha edges under filtering. |
  | `mipmaps/generate` | **TRUE** | Decal is projected at varying distance/angle → mipmaps stop shimmer. (The tileable pixel-art template leaves this FALSE — override it here.) |
  | `compress/mode` | Lossless | VRAM compression adds artifacts in the alpha mask; keep lossless. |

  Filter (NEAREST vs linear) is a material/project setting, not import — defer to
  the open pixel-art-residue art decision in CLAUDE.md; do not hardcode.

## Steps

### 1. Import the albedo-mask texture

Set the decal-mask import settings from the table above on
`assets/textures/scorch_decal.png` (premult OFF, fix_alpha_border ON, mipmaps
ON, Lossless), then reimport. The texture's **alpha channel is the projection
mask** — opaque pixels project, transparent pixels show nothing.

### 2. Build the fixed Decal pool — `entities/vfx/scorch_decal_pool.gd`

A `Node3D` that on `_ready` creates `pool_size` reused `Decal` children, each
preassigned the albedo texture, hidden, alpha 0. Round-robin `_index` picks the
next slot. Per-slot `Tween` array so a slot's running fade can be killed before
reuse.

```gdscript
class_name ScorchDecalPool
extends Node3D
## Round-robin pool of reused Decal nodes for impact/death scorches.
## Decal is Forward+/Mobile only — each is ONE clustered element sharing the
## 512-element budget with lights/reflection probes (NOT a deferred pass).

const _SCORCH_TEX: Texture2D = preload("res://assets/textures/scorch_decal.png")

@export var pool_size: int = 8
@export var fade_duration: float = 10.0
@export var decal_extents: Vector3 = Vector3(0.6, 0.5, 0.6)
@export var peak_albedo_mix: float = 0.85

var _decals: Array[Decal] = []
var _index: int = 0
var _tweens: Array[Tween] = []

func _ready() -> void:
	_tweens.resize(pool_size)
	for i: int in range(pool_size):
		var d: Decal = Decal.new()
		d.texture_albedo = _SCORCH_TEX
		d.size = decal_extents * 2.0
		d.modulate = Color(1.0, 1.0, 1.0, 0.0)
		d.visible = false
		add_child(d)
		_decals.append(d)
```

`size` is full extents (the `Vector3` here is half-size → `* 2.0`); the **Y**
component is the projection depth, how far the decal reaches down its -Y axis.

### 3. Degenerate-safe `place(pos, normal)` — orient -Y to the surface

The Decal projects along local -Y, so build a basis whose Y column = the surface
normal. A naive `look_at` / `Basis.looking_at(-normal, Vector3.FORWARD)`
collapses whenever the normal is parallel to the chosen reference axis — exactly
the floor/ceiling case (±Y) or a ±Z wall. Pick the tangent seed by an `abs(dot)`
test so the cross products never degenerate:

```gdscript
func place(world_pos: Vector3, surface_normal: Vector3 = Vector3.UP) -> void:
	var d: Decal = _decals[_index]

	# Kill any running fade on this slot before reusing it.
	if _tweens[_index] != null and _tweens[_index].is_valid():
		_tweens[_index].kill()

	# Seed the tangent with a vector never parallel to the normal.
	var up_hint: Vector3 = (
		Vector3.RIGHT if absf(surface_normal.dot(Vector3.UP)) > 0.9 else Vector3.UP
	)
	var right: Vector3 = surface_normal.cross(up_hint).normalized()
	var forward: Vector3 = right.cross(surface_normal).normalized()
	# Columns: x = right, y = normal (projection out of the surface), z = forward.
	# Use +forward, NOT -forward: Basis(right, normal, -forward) has determinant -1
	# (a left-handed reflection) and can cause rendering artifacts. +forward -> det +1.
	var surface_basis := Basis(right, surface_normal, forward)
	d.global_transform = Transform3D(surface_basis, world_pos)
	d.size = decal_extents * 2.0
	d.modulate = Color(1.0, 1.0, 1.0, peak_albedo_mix)
	d.visible = true
```

`|normal·UP| > 0.9` (floor/ceiling) → seed with `RIGHT`; otherwise seed with
`UP`. Never collapses on floor, ceiling, or wall.

### 4. Fade tween with kill-before-reuse

Tween the slot's `modulate:a` to 0 over `fade_duration`, then hide, and store the
tween so step 3 can `kill()` it if the slot is recycled before the fade ends.
Advance the round-robin index.

```gdscript
	var t: Tween = create_tween()
	t.tween_property(d, "modulate:a", 0.0, fade_duration)
	t.tween_callback(d.hide)
	_tweens[_index] = t

	_index = (_index + 1) % pool_size
```

The `kill()` in step 3 is what makes reuse safe — without it the previous fade
keeps writing `modulate:a` and fights the new placement.

### 5. Wire the router component to combat seams

A plain component (the `godot-oneshot-vfx` `VfxRouter` or a sibling) calls
`pool.place(hit_pos, hit_normal)` on the projectile `hit` / enemy `died` seam,
passing the **collision normal** the seam reports. The pool lives under
`VfxRoot`; the component only holds a reference and calls down — no autoload, no
contract change on the combat skills.

## Verification checklist

- Scorch appears **flat** on the floor AND on a vertical wall — no skew, no gap
  between mark and surface (degenerate basis would skew/flip it).
- On a ceiling hit (normal ≈ -Y) the mark still lies flat (RIGHT-seed path).
- The 9th hit recycles slot 1 — open the running Remote tree: exactly
  `pool_size` Decal nodes, no accumulating leak.
- A placed decal fades to nothing over ~`fade_duration` s, then is hidden.
- Recycling a slot mid-fade snaps it back to full opacity (old tween killed),
  no flicker-fight.
- Texture edges show no white/dark fringe; no shimmer when viewed at a shallow
  angle / distance.
- Scene runs under **Forward+** — decals render, not silently empty.
- `tools/validate.sh` passes on all touched `.gd` / `.tscn`.

## Error → Fix

| Symptom | Fix |
|---|---|
| Decal invisible (nothing projected) | Running **Compatibility** renderer (Decal is Forward+/Mobile only) — switch to Forward+; or the albedo texture's alpha is all-zero (the alpha IS the mask). |
| Decal skewed / flipped / gapped on a wall | Degenerate basis — the normal is parallel to the tangent seed (±Z with a hardcoded FORWARD, or ±Y with UP). Use the `abs(normal·UP) > 0.9 → RIGHT else UP` seed and build `Basis(right, normal, forward)` (use +forward — `-forward` gives a det -1 left-handed basis that renders wrong). |
| White / dark fringe on the decal edges | `process/fix_alpha_border` is OFF on the texture import — set TRUE and reimport. |
| Decal shimmers / grainy at distance or shallow angle | `mipmaps/generate` is OFF (inherited from the tileable pixel-art template) — set TRUE and reimport. |
| Decal washed out / wrong blend | `process/premult_alpha` is ON — a Decal node has no premult blend mode; set premult FALSE and reimport. |
| Decals stop appearing past N on screen | Exceeded the 512 clustered-element budget shared with lights + reflection probes — lower `pool_size` or cut other clustered elements (NOT a deferred-pass cost). |
| Recycled slot flickers / fades wrong | Previous fade tween not killed before reuse — `kill()` the slot's tween before re-placing. |

Adapted from GodotPrompter (https://github.com/jame581/GodotPrompter), MIT License, Copyright (c) GodotPrompter Contributors.
