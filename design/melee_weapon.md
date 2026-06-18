# Melee Weapon (Knife) + Magnet Kill Rule

**Goal** — Player has an always-available close-range knife (key V) that reliably kills any enemy in front of them; the magnetic enemy (H9) now takes 0 damage from bullets and can ONLY be killed by melee — so the survival loop never stalls on an unkillable magnet.

## The problem this fixes
H9 magnet bends bullets toward itself → shots at enemies behind it get stolen, and the magnet itself is effectively unkillable with the gun. Win is by SCORE (75); magnets are ~10% of spawns worth 4 pts. Unkillable magnets pile up → loop stuck, can't reach win score. Melee is the guaranteed counter.

## Decisions (applied defaults — override here if wanted)
- **Melee is a SEPARATE always-available button, NOT a third swappable weapon.** Rationale: if the knife were in the Q swap cycle, a player holding the gun would have no way to kill a magnet without first swapping — and the swap animation (other doc) blocks fire, so a magnet could reach you mid-swap → deadlock. A dedicated melee key means the magnet is *always* killable regardless of active weapon. This is the cut that guarantees loop progress.
- **Magnet bullet rule: bullets deal 0 damage to the magnet (immune), they still curve.** Chosen over "fully deflect" (reads as invincible-from-front, no clear tell) and over "just curve, still killable" (current — too unreliable, the user's complaint). The bullet still bends (existing H9 steer stays — it's the readable visual tell that says "shoot won't work here"), but `on_hit()` from a projectile is ignored. Melee `on_hit()` always lands. Every other enemy type is unchanged (bullets kill them normally).

## Scope (in)
- **Input action `melee`** (key V) added to `project.godot`. Separate from `shoot`/`reload`/`equip_weapon`.
- **Knife component** `entities/weapon/melee.gd` + `melee.tscn` under `Head` (sibling of `Weapon`/`Rifle`), with an `Area3D` ("MeleeHitbox", short box ~1.6 m reach in front of Head, monitoring, on the enemy collision layer/mask). Always present; the gun/rifle view-model stays visible — knife is a quick stab, not a held swap.
- **Attack on `melee` press:** `try_melee()` runs a one-shot Timer-gated cooldown (~0.45 s). On press: brief knife thrust view-model tween (reuse the dip/restore tween shape from `weapon.gd`), then query `MeleeHitbox.get_overlapping_bodies()`; for each body with `on_hit()`, call it once. Call `on_hit()` on the enemy seam (`enemy.gd` line 134) — same contract as projectiles → hit flash / death flash / death SFX / `died` all keep working.
- **Magnet immunity:** add `@export var projectile_immune: bool = false` to `enemy.gd`; `enemy_magnet.gd` sets it true in `_ready()`. In the **projectile** hit path (`projectile.gd._on_body_entered`), before calling `body.on_hit()`, skip the call if the body reports `projectile_immune` true (duck-typed, like the existing `has_method` guard) — projectile still despawns + plays hit SFX (reads as "deflected/absorbed"), but no damage. Melee calls `on_hit()` directly and ignores the flag → magnet dies in melee.
- **Kill-confirm / score still fire:** melee must drive the same feedback as a bullet kill. `melee.gd` emits `hit_confirmed` (any body hit) and `kill_confirmed` (a hit body whose `died` fires this swing) — reuse the exact duck-typed `died` + `CONNECT_ONE_SHOT` seam already in `weapon.gd` (lines 157–174). Player connects melee's `hit_confirmed`/`kill_confirmed` to the existing crosshair pops (`_connect_weapon_signals` pattern). Enemy `died` already feeds WaveManager → escalation / HUD / SCORE unchanged.

## Scope (out)
- Knife as a swappable weapon / on the Q cycle — would re-create the deadlock; melee stays its own button.
- Melee ammo, durability, charge, combo — knife is free + instant-ready, only gated by its cooldown.
- Melee VFX beyond the view-model thrust tween (no slash particle — roadmap VFX ban).
- Bullets doing *partial* / reduced damage to the magnet — it's binary immune, simplest readable rule.
- Magnet ever killable by bullets — intentionally never; melee is the sole counter (that's the mechanic).
- A dedicated knife `.glb` model — placeholder thrust on a sourced/placeholder mesh is fine for the POC; final knife art is Later.

## Acceptance (F5 + godot-verify)
- Press V near a grunt/runner/tank in front → it takes a hit (flash, or dies); crosshair shows hit/kill pop; SCORE increments on kill exactly as a bullet kill does.
- Press V with no enemy in reach → thrust animation plays, nothing dies, cooldown still applies.
- Shoot the magnet directly → bullet curves in, impacts, plays hit SFX, magnet does NOT die (no health loss, no death flash).
- Melee the magnet → it dies, death flash + SFX + `died` fire, SCORE +4, WaveManager respawns as normal.
- Run never stalls: a wave full of magnets is fully clearable with V; reaching win_score (75) still triggers YOU WIN.
- godot-verify: all scenes load/render clean; validate.sh passes; no "Signal already connected" on repeated melee on a surviving tank (CONNECT_ONE_SHOT + is_connected guard, as in weapon.gd).

## Skill notes
- `godot-fps-enemy-combat` (load-bearing) — melee plugs into the SAME `on_hit()` / `died` / `hit_confirmed` / `kill_confirmed` contract; do NOT invent a new damage path. The `projectile_immune` skip lives on the projectile side only; melee never checks it.
- `godot-composition` — `melee.gd` is a sibling component under `Head`; signals up to player, player calls down `try_melee()`. No inheritance.
- `godot-first-person-controller` — `melee` input action; player routes the press.
- `godot-code-rules` — typed GDScript; gate `tools/validate.sh`.
- `godot-verify` — scene load/render + the no-double-connect smoke.
- **No melee skill exists.** Not a gap requiring skill-researcher: godot-dev can build this from `godot-fps-enemy-combat` (the contract) + a plain `Area3D` + `get_overlapping_bodies()` + the existing weapon tween/kill-confirm patterns. Flag only — no new skill warranted for one Area3D melee.

## Later
- Knife as a real sourced `.glb` with its own thrust animation.
- Melee on other enemies as a stagger/knockback rather than instant kill.
- Heavy-attack / charged melee, melee combo timing.
- A reason to melee non-magnets (e.g. ammo-saving) via a damage-value model.

## Open questions
None blocking. (Both forks — separate-button melee, binary bullet-immunity — resolved with documented defaults; override in Decisions above if undesired.)
