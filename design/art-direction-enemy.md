# Art Direction — Enemy (Firing Yard hostiles)

**Look in one line** — cold blood-crimson humanoid threat: dark body, brighter chest "core", reads as DANGER against the cool-grey yard and away from both the warm rust props and the yellow targets / desaturated NPCs.

The problem this fixes: enemy `Mesh` is a single capsule with one flat `Color(0.42,0.22,0.22)` literal typed straight into `enemy.tscn` — not from `ArtStyle`, and that maroon sits in the SAME warm-red region as `RUST_MID (0.45,0.26,0.16)`. Against rusted barrels/crates an enemy can blend; against the cool concrete it has no silhouette identity. This direction gives the enemy a named crimson ramp + a blocky humanoid silhouette so it reads as a moving threat at a glance.

---

## Read separation (why crimson + humanoid)

Yard hue budget already spent: cool grey (steel/concrete), warm brown (rust), amber/teal (zone tags), yellow (targets), desaturated figure-grey (NPCs). Enemy must NOT collide with any:
- **Hue:** cold, saturated crimson — pushed redder/cooler and more saturated than the warm rust browns, so it never reads as "another barrel."
- **Silhouette:** blocky humanoid (head + torso + 2 legs + 2 arms), NOT a capsule. NPCs are capsules; targets are blocks; an enemy is a *figure with limbs* = the only humanoid-with-arms in the yard.
- **Value:** dark body anchored low in the ramp + one brighter chest "core" band — gives a focal point the eye locks onto and the existing white death-flash reads cleanly off.

---

## Palette — new `ArtStyle` swatches

Add to `tools/art_style.gd`. Crimson ramp dark → light, plus a near-black armor accent. All inside `[VALUE_MIN, VALUE_MAX]`. Crimson sits ABOVE the current `SATURATION_CEILING = 0.50` on purpose — see Scalars.

### Enemy crimson — ramp dark → light
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `ENEMY_CRIMSON_DARK` | 0.34, 0.06, 0.10 | body shadow / lower legs — anchors the dark silhouette |
| `ENEMY_CRIMSON_MID` | 0.56, 0.10, 0.14 | main body (torso, arms) — the dominant read |
| `ENEMY_CRIMSON_LIGHT` | 0.74, 0.16, 0.18 | chest "core" band + head highlight — the focal point |

### Enemy armor accent
| Swatch | Color (r,g,b) | Note |
|---|---|---|
| `ENEMY_ARMOR_DARK` | 0.10, 0.09, 0.11 | head, hands, feet — near-black, ties the figure's extremities together and frames the crimson |

**Why these and not more.** 3-band crimson + 1 dark accent = whole enemy vocabulary. The dark accent on head/hands/feet keeps the silhouette legible against the lit concrete (no light-on-light wash) and makes the crimson core pop. Resist a second hostile hue — one threat colour, used only by enemies, is the readability win. Future enemy *types* should re-use this ramp at different value/scale before introducing a new hue.

---

## Style scalars

One change; the rest unchanged.

| Scalar | Value | Why |
|---|---|---|
| `VALUE_MIN` | 0.16 | unchanged — `ENEMY_ARMOR_DARK ≈ 0.10` is a deliberate *accent* below the floor, framing only; body crimson stays above |
| `VALUE_MAX` | 0.90 | unchanged |
| `SATURATION_CEILING` | 0.50 | unchanged as the *environment* ceiling. **Enemy crimson is an explicit, documented exception** — threats are allowed to break the muted-industrial rule so they read as the one thing in the scene that wants your attention. Keep the ceiling at 0.50 for surfaces/props; do NOT raise it globally. |
| `RAMP_SHADES` | 3 | unchanged — 3-band crimson matches every other material ramp |
| `TEXEL_DENSITY` | 32 | unchanged — N/A to a flat-colour kitbash, but the .glb stays in the same world |

---

## Mapping — enemy mesh → swatch(es) + generator spec

godot-dev: generate one humanoid `.glb` via `gen_models.gd` (box kitbash; `gen_models.gd` supports `box`/`cylinder`/`cone` with per-part `color`), then swap the capsule `Mesh` SubResource in `enemy.tscn` for the model. **Keep the `CollisionShape3D` capsule (r0.35 h1.8) and the `Mesh` node position `(0,0.9,0)` envelope unchanged** — only the visual mesh changes, so nav/perception/hit stay identical.

### Generator spec — `enemy_grunt` (humanoid, ~0.7 W × 1.8 H × 0.4 D, Y-min = 0)
Box kitbash, all parts flat-colour from the swatches above:

| Part | shape | size (x,y,z) | pos (x,y,z) | color |
|---|---|---|---|---|
| Head | box | 0.34, 0.34, 0.34 | 0.0, 1.60, 0.0 | `ENEMY_ARMOR_DARK` |
| Torso | box | 0.50, 0.60, 0.30 | 0.0, 1.15, 0.0 | `ENEMY_CRIMSON_MID` |
| Chest core | box | 0.30, 0.20, 0.32 | 0.0, 1.25, 0.0 | `ENEMY_CRIMSON_LIGHT` |
| Arm L | box | 0.14, 0.55, 0.16 | -0.32, 1.12, 0.0 | `ENEMY_CRIMSON_MID` |
| Arm R | box | 0.14, 0.55, 0.16 | 0.32, 1.12, 0.0 | `ENEMY_CRIMSON_MID` |
| Hand L | box | 0.16, 0.16, 0.18 | -0.32, 0.80, 0.0 | `ENEMY_ARMOR_DARK` |
| Hand R | box | 0.16, 0.16, 0.18 | 0.32, 0.80, 0.0 | `ENEMY_ARMOR_DARK` |
| Leg L | box | 0.18, 0.70, 0.20 | -0.13, 0.42, 0.0 | `ENEMY_CRIMSON_DARK` |
| Leg R | box | 0.18, 0.70, 0.20 | 0.13, 0.42, 0.0 | `ENEMY_CRIMSON_DARK` |
| Foot L | box | 0.20, 0.10, 0.28 | -0.13, 0.05, 0.0 | `ENEMY_ARMOR_DARK` |
| Foot R | box | 0.20, 0.10, 0.28 | 0.13, 0.05, 0.0 | `ENEMY_ARMOR_DARK` |

Notes:
- Faces -Z (arms/legs forward axis = Z), matching the enemy's forward; figure is ~1.77 m tall, fits the capsule envelope.
- Value gradient bottom→top: dark legs → mid torso/arms → light chest core + framed by dark extremities. Eye lands on the bright chest core.
- The white death-flash in `enemy.gd` (`_flash_and_die`) drives albedo+emission to white on surface 0 — works on the kitbash's merged material as on the capsule; no change needed.
- The attack telegraph (`perform_attack` scale-lunge on `_mesh_instance`) reads BETTER on a limbed figure than a capsule — no change needed.

**Fallback (if the .glb swap is deferred):** at minimum recolour the existing capsule material from the maroon literal to `ENEMY_CRIMSON_MID` so it stops clashing with rust. The humanoid kitbash is the real win; the recolour is the floor.

---

## Lighting mood

No new lighting. The yard's day/night sun cycle + Filmic tonemap + hard shadows (per `art-direction-firing-yard.md`) already serve the enemy:
- Hard shadow under the figure sells it standing ON the floor (matches the targets/props read) — keep.
- Crimson at full saturation reads by hue at any lit value across the cycle; do NOT add enemy emission/glow this pass (the white death-flash is the only emission moment, and it's intentional and brief).
- Verify the enemy still reads at the **night phase** (cool-blue moonlight, lifted ambient): crimson can go muddy under blue light. If the body crushes, lift `AMBIENT_ENERGY_NIGHT` (already the firing-yard lever) rather than brightening the crimson swatches.

---

## Later

- Per-enemy-type recolour using the SAME crimson ramp at different value/scale (heavy = darker/bigger, fast = lighter/smaller) before any new hue.
- Sourced animated enemy `.glb` (idle/walk/attack) via `godot-mesh-import-pixel-art` + `godot-animation-libraries`, swapping the kitbash — same node seam.
- Aggro-state tell: a faint `ENEMY_CRIMSON_LIGHT` emissive pulse on the chest core when chasing (needs emission wiring; parked with the level's glow Later).
- Death VFX beyond the white flash (crimson shard burst).

---

## Open questions

None — autonomous pass. Crimson-threat + humanoid-kitbash chosen against the established yard palette; no fork blocks the apply pass.
