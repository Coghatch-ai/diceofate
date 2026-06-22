# Bullet Types (Cast composition proof)

**Goal** — Each gun slot fires a visibly distinct bullet (own colour + own Effect mix) authored entirely as a `CastData` `.tres` — same Gun/Projectile machinery, different data → different bullets. Proves the Cast system composes.

## The set — 3 bullet types (one per existing gun-slot)

3, not 4: maps 1:1 to the project's existing projectile slots (Pistol=slot0, Rifle=slot1) + one new third gun. Hammer (slot2) is melee → no projectile → excluded. A 4th type would need a 4th weapon slot beyond Q's existing 3-slot cycle → scope creep, cut.

| # | Name | Colour (albedo / emission) | Effect mix | Resolver | CastData `.tres` | Weapon |
|---|------|------|------|------|------|------|
| 1 | Light Bolt | yellow `Color(1,1,0)` / amber `Color(1,0.8,0)` | `[DamageEffect(1)]` | HitTargetResolver | `pistol_cast.tres` (exists — add colour) | Pistol (slot 0) |
| 2 | Heavy Slug | red `Color(1,0.2,0.15)` / red `Color(1,0.25,0.1)` | `[DamageEffect(3), KnockbackEffect]` | HitTargetResolver | `heavy_cast.tres` (exists — add colour) | Rifle (slot 1) |
| 3 | Stun Dart | cyan `Color(0.2,0.8,1)` / cyan `Color(0.3,0.9,1)` | `[DamageEffect(1), KnockbackEffect]` | HitTargetResolver | `stun_cast.tres` (NEW) | Carbine (slot 2 — NEW gun) |

Composition proof per part: **Effect-list length differs** (1 vs 2 effects) → list-iteration exercised; **Effect mix differs** (Damage-only vs Damage+Knockback; amount 1 vs 3) → Effect×data exercised; **CastData differs** (3 distinct `.tres`, distinct colour) → CastData itself exercised; **Resolver** is wired + asserted per bullet but the SAME `HitTargetResolver` (see cut below).

## Scope (in)
- **Colour on CastData** — add `@export var bullet_color: Color = Color(1, 1, 0)` to `tools/lib/cast/cast_data.gd` (typed, default = current yellow). Small typed addition, acceptable.
- **Projectile reads it** — `projectile.gd`: when `cast_data` is stamped (gun.gd `_fire()` line 326 already sets it), tint the `MeshInstance3D` material from `cast_data.bullet_color`. Set albedo + emission to the colour on the projectile's own material instance (make-unique so instances don't share one resource). Null cast_data → leave the scene's default yellow material untouched (no regression).
- **`pistol_cast.tres`** — add `bullet_color = Color(1, 1, 0, 1)`. Effects/resolver unchanged.
- **`heavy_cast.tres`** — add `bullet_color = Color(1, 0.2, 0.15, 1)`. Effects/resolver unchanged (already `[Damage(3), Knockback]`).
- **`stun_cast.tres`** (NEW) — `effects = [DamageEffect(1), KnockbackEffect]`, `resolver = HitTargetResolver`, `bullet_color = Color(0.2, 0.8, 1, 1)`. Mirror pistol_cast.tres `.tres` format.
- **`carbine.tscn`** (NEW) — inherited scene from `weapon.tscn` (same pattern as `rifle.tscn`): own `*ViewModel` node + Muzzle/MuzzleFlash, `cast_data = stun_cast.tres`, distinct `fire_rate`/`ammo_max` (suggest fire_rate 0.15, ammo_max 20, caliber `&"light"`). Reuse `scifi_pistol.glb` or `scifi_smg.glb` view-model — no new model.
- **Wire slot 2 = Carbine** — `weapon_controller.gd` currently: slot2=Hammer, Q cycles 3. Add Carbine so Q cycles slots and each gun shows its tinted bullet. Minimal: either replace Hammer in slot 2 with Carbine, OR extend to a 4-slot cycle. **Default: replace Hammer at slot 2 with Carbine** (keeps the 3-slot cycle the controller already documents; Hammer-melee is orthogonal to this projectile-composition proof). State in code header.

## Scope (out)
- **A second TargetResolver** (radius/AoE/self) — the only non-Hit resolvers are AoE and instigator-self, both explicitly parked. With no third resolver available, all 3 bullets use `HitTargetResolver`; composition is proven on the Effect-mix + CastData + colour axes instead. Resolver-variation parked until an AoE/chain bullet earns it.
- **4th bullet / 4th weapon slot** — no slot exists; adding one is its own slice.
- **Per-bullet trail colour, SFX, impact-VFX colour** — projectile mesh tint is enough to read 3 distinct bullets; tinting the trail/decal/VFX is polish, parked.
- **New Effect subclasses** (Slow/DoT/Pierce) — Stun Dart reuses Damage+Knockback; a real status effect is a new `Effect` slice, parked.
- **Hammer removal/relocation** — only its slot index changes; melee logic untouched.

## Acceptance
- `tools/validate.sh` passes (strict-typed; `bullet_color` typed; 3 `.tres` + carbine.tscn load).
- `$GODOT --headless --path . --script tools/smoke_cast.gd` → all asserts PASS, exit 0 (extended asserts below).
- godot-verify: `weapon.tscn`, `rifle.tscn`, `carbine.tscn` load + render; projectile renders.
- Human F5 in `firing_yard`: Q-cycle the 3 guns, fire each → bullets are visibly **yellow / red / cyan**; Light Bolt does NOT one-shot a 3-health tank, Heavy Slug does; Heavy + Stun knock the enemy back, Light does not.

## Smoke asserts to add (extend `tools/smoke_cast.gd`)
Keep all 10 existing. Add, driven from loaded `.tres` (reuse `_make_ctx` + resolve/apply loop mirroring projectile.gd 99-110, existing `Enemy`/`died` + `StubTarget` patterns):
- **9. colour load** — each of `pistol_cast`/`heavy_cast`/`stun_cast` loads as `CastData` with expected `bullet_color` (yellow / red / cyan) and expected effect-count (1 / 2 / 2).
- **10. stun_cast shape** — `stun_cast.tres`: 2 effects, `effects[0] is DamageEffect` amount==1, `effects[1] is KnockbackEffect`, `resolver is HitTargetResolver`.
- **11. Light Bolt vs tank (health=3)** — load `pistol_cast`, resolve+apply loop vs tank → `died` NOT emitted (amount 1 < 3); apply once more twice → dies on 3rd. Proves authored amount=1 does not one-shot.
- **12. Heavy Slug vs tank (health=3)** — load `heavy_cast`, one cast → `died` once AND `_stun_timer > 0` (knockback reached). Distinct outcome from Light from same engine.
- **13. Stun Dart vs grunt (health=1)** — load `stun_cast`, one cast → `died` once AND `_stun_timer > 0`. Proves Damage+Knockback mix fires from 3rd authored `.tres`.

## Skill notes
- `godot-code-rules` — `bullet_color` typed `Color`; projectile material tint via make-unique `StandardMaterial3D`; new `.tres` sub_resources strict-typed. No untyped/unsafe beyond existing guarded seams.
- `godot-runtime-smoke` — extend existing `tools/smoke_cast.gd`; data-chain driven (NO physics frames); reuse `Enemy`+`died` and `StubTarget`.
- `godot-fps-enemy-combat` — unchanged; relies on existing `apply_damage`/`apply_knockback`/`died` contract.
- `godot-travelling-projectile-3d` — projectile gains only a colour-tint read on stamp; firing/despawn untouched.
- `godot-mesh-import-pixel-art` — carbine.tscn reuses an existing `.glb` view-model; no new model sourced.

## Later
- AoE/chain bullet → second `TargetResolver` (proves the resolver axis).
- Real status `Effect` (Slow/Burn/Pierce) for a 4th bullet identity.
- Per-bullet trail / impact-VFX / SFX colour tint.
- Restore Hammer as a 4th Q slot alongside the 3 guns.

## Open questions
- None blocking.
