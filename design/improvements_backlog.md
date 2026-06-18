# Improvements Backlog — FPS POC (Track H candidates)

**Purpose** — 10 prioritized, small, buildable improvements that deepen the existing FPS POC loop
(fire → kill → escalate → win/lose). Incorporates the user's 5 seed ideas (ammo, reload, reload
viz, new weapon, magnetic enemy) + 5 designer additions. Each is one godot-dev task + verify + one
human F5. **Easiest first** — early items lay seams later ones reuse.

**POC guardrails honored** — no networking, no save/load, no inventory UI, no weapon-switch *economy*.
The roadmap's "Out of scope" line bans an **ammo/reload economy** and **weapon inventory/switching UI**;
Track H must be brought IN scope by user decision the same way Track C/F/G were (see roadmap note).
Items here stay minimal: ammo is a single counter, not a resource economy; the 2nd weapon is a swap on
one key, not an inventory.

## Build order (easiest → hardest)

| # | Improvement | Effort | Systems touched | Doc |
|---|---|---|---|---|
| 1 | **Bullet limit (ammo cap)** — weapon holds N rounds; firing decrements; empty blocks fire (dry click). | easy | `weapon.gd` | `design/weapon_ammo_limit.md` ✅ scoped |
| 2 | **Reload (cooldown refill)** — `reload` key (R) or auto-on-empty refills to cap over a timer; can't fire mid-reload. | easy | `weapon.gd`, `project.godot` (input) | `design/weapon_reload.md` ✅ scoped |
| 3 | **Ammo on HUD** — `AMMO  n / max` line + `RELOADING…` state on the existing ArenaHud surface. | easy | `arena_hud.gd`, `weapon.gd` (signal), `player.gd`, `main.gd` (wire) | `design/weapon_ammo_hud.md` ✅ scoped |
| 4 | **Reload animation (view-model dip)** — PistolViewModel tweens down+back during reload as visual feedback. | easy | `weapon.gd` (tween on existing `PistolViewModel`) | paragraph below |
| 5 | **Low-ammo / empty SFX** — dry-click sound on empty trigger; reload-complete click. | easy | `weapon.gd`, `default_bus_layout` already exists; 2 CC0 SFX | paragraph below |
| 6 | **Hitmarker + kill confirm tick** — crosshair already has `hit_pop()`; add a distinct kill-confirm pop on `died`. | easy-med | `weapon.gd`/`crosshair.gd` (kill signal), `enemy.gd` already emits `died` | paragraph below |
| 7 | **Muzzle flash (view-model)** — brief emissive quad/light pulse at Muzzle on fire (no particles — light pulse only). | medium | `weapon.tscn` (OmniLight3D at Muzzle), `weapon.gd` (pulse on fire) | paragraph below |
| 8 | **Second weapon: burst/auto rifle (swap on key)** — `equip_weapon` key cycles between pistol + a faster, lower-damage-per-shot rifle (own fire_rate/ammo/reload). | medium | `player.gd` (hold 2 Weapon nodes, swap active), `weapon.gd` (already data-driven), `project.godot` (input) | paragraph below |
| 9 | **Magnetic enemy (projectile-attractor)** — a 4th enemy type that bends nearby player projectiles toward itself (a bullet-magnet), so you must lead/flank it. | medium-hard | `enemy.gd` (new `magnetic` flag + pull region), `projectile.gd` (steer toward magnet), `wave_manager.gd` (4th roll), `art_style.gd` (swatch) | paragraph below |
| 10 | **Per-type kill scoring + win-by-score** — runner/tank/magnetic worth more; win target becomes a score, not a flat kill count. | medium | `wave_manager.gd` (score map, win on score), `arena_hud.gd` (SCORE line) | paragraph below |

### Why this order

- **1→2→3 is the seed-idea spine and a strict dependency chain.** Ammo (1) adds the `_ammo` counter
  + `can_fire` gate. Reload (2) is meaningless without a counter to refill → builds on 1. HUD (3)
  surfaces both — pure display, no new gameplay, safest once the data exists. Each is genuinely the
  smallest next step, all `easy`.
- **4 & 5 are feedback polish on the reload that 2 introduced** — they need the reload state to exist,
  but add no logic, only a tween / a sound. Cheap, low-risk, do them while the weapon file is fresh.
- **6 reuses the crosshair pop seam already built** for fire/hit — only a new signal on `died`.
- **7 (muzzle flash)** is the first item touching `weapon.tscn` structure (a light node) — slightly
  more than a script edit, hence after the script-only polish.
- **8 (second weapon)** is the first item that changes the *player's* node layout (two weapons) and
  input map; it leans on weapon.gd already being fully data-driven (`fire_rate`, and after #1–2,
  `ammo`/`reload_time` exports) so the rifle is a re-tuned `weapon.tscn` instance, not new code.
- **9 (magnetic enemy)** touches the most systems (enemy + projectile + spawn + palette) and needs a
  new projectile-steering behaviour — the heaviest. Done after the weapon work so there's variety in
  *what* you shoot it with.
- **10 (scoring)** is last because it only pays off once there are several enemy types worth different
  amounts (needs tank/runner/magnetic present) and it reframes the win condition built in G2.

## Items 4–10 — one-paragraph specs (full docs later)

**4. Reload animation (view-model dip).** When a reload starts (see #2), tween `PistolViewModel`
(already a `Node3D` at `position = (0.12,-0.12,-0.25)` in `weapon.tscn`) down and slightly rotated,
then back up over `reload_time`, so the gun visibly "racks". Pure cosmetic `create_tween()` in
`weapon.gd`'s reload-start path; restore to base transform on finish. No new nodes. Skill:
`godot-code-rules` (typed), `godot-verify` (tween runs, gun returns to rest, no drift). Acceptance:
F5 — pressing reload dips the gun for `reload_time` then returns; firing blocked during the dip.

**5. Low-ammo / empty SFX.** On a fire attempt with `_ammo == 0`, play a short "dry-click" SFX
(no projectile); on reload-complete, play a "rack/click" SFX. Reuse the existing `Master→SFX` bus
and the fire-and-free one-shot pattern from `godot-audio` (FireSfx is already an `AudioStreamPlayer`
on bus `SFX`). Two CC0 clips into `assets/audio/`. Skill: `godot-audio` (no AudioManager autoload,
loop off, SFX bus). Acceptance: F5 ear-check — empty trigger clicks instead of firing; reload ends
with an audible click.

**6. Hitmarker + kill-confirm tick.** `crosshair.gd` already exposes `hit_pop()` (wired via
`weapon.hit_confirmed`). Add a distinct `kill_pop()` (different colour/size) fired when a shot kills
an enemy. Seam: `enemy.on_hit()` already runs the death path and emits `died`; forward a
"killed by this projectile" up through `projectile.hit` → `weapon.hit_confirmed` is per-hit, so add a
`weapon.kill_confirmed` that fires when the hit body died (check after `on_hit()` whether the body is
queued for deletion, or have `Projectile` listen for the body's `died`). Simplest: `projectile.gd`
checks `body.is_queued_for_deletion()` after calling `on_hit()` and emits a `killed` flavour. Skill:
`godot-composition` (signals up), `godot-verify`. Acceptance: F5 — a non-lethal tank hit shows the
normal hitmarker; a lethal hit shows a distinct kill tick.

**7. Muzzle flash (light pulse).** Add an `OmniLight3D` (or a small emissive `MeshInstance3D` quad)
as a child of `Muzzle` in `weapon.tscn`, default `visible=false` / `light_energy=0`. On
`weapon.fired`, pulse it bright for ~0.04 s via a tween, then off. No particles (roadmap bans VFX
beyond the outline pass — a single light pulse is the minimal, in-style readout; flag it to the
verifier as the one sanctioned light, not a particle system). Skill: `godot-pixel-lighting`
(hard/short pulse, don't blow out the SubViewport exposure), `godot-verify` (renders, no lingering
light). Acceptance: F5 — each shot briefly lights the muzzle; no light persists between shots.

**8. Second weapon: rifle (swap on key).** `weapon.gd` is already fully data-driven (`fire_rate`,
`projectile_scene`, and after #1–2 `ammo_max`/`reload_time`). Author a second `weapon.tscn` instance
(or an inherited scene) tuned as a rifle: faster `fire_rate`, larger `ammo_max`, its own
`projectile_scene` (reuse the existing projectile, maybe faster). `player.gd` holds **two** Weapon
child nodes under `Head`; an `equip_weapon` input (key `Q` or `1`/`2`) toggles which is active +
visible; `try_fire()` routes to the active one. This is a **swap, not an inventory UI** — exactly two
weapons, one key, no menu (stays inside the POC guardrail). HUD ammo (#3) reads the active weapon.
Skill: `godot-composition` (player owns both, calls down to the active), `godot-first-person-controller`
(input), `godot-code-rules`, `godot-verify`. Acceptance: F5 — press the swap key, the view-model
changes, fire-rate/ammo differ, reload works per-weapon, HUD tracks the active weapon. Needs a
`project.godot` input action (allowed: input-map edits are sanctioned for godot-dev).

**9. Magnetic enemy (projectile-attractor).** *Chosen interpretation:* a **bullet-magnet** — the most
buildable + fun reading. The enemy is a normal slow-ish enemy, but **player projectiles within a
radius curve toward it**, so shots fired at a *different* enemy near it get "stolen", and you must
either flank it or get close for a straight shot. (Rejected alternatives: pulling the player —
fights the FPS controller and risks motion-sickness; deflecting projectiles — reads as "invincible
from the front", frustrating with no counter.) Build: new `enemy_magnet.tscn` (inherited) +
`enemy_magnet.gd` (code-tint via `set_surface_override_material`, per `godot-mesh-import-pixel-art` —
NOT a `.tscn` override, copy `enemy_runner.gd`); a new `ENEMY_MAGNET_*` swatch (cool electric-cyan)
in `art_style.gd`; a `magnetic` flag + an `Area3D` "pull field" on the enemy that registers it in a
group `magnet`. `projectile.gd` each `_physics_process`: find the nearest node in group `magnet`
within `pull_radius`, steer its `-Z` heading a few degrees/frame toward it (clamped so it can still
miss). `wave_manager.gd` adds `enemy_scene_d` + `magnet_ratio` as a 4th roll branch. Skills:
`godot-mesh-import-pixel-art` (code recolour — load-bearing), `godot-art-style` (new swatch),
`godot-enemy-ai` (reuses FSM, slower profile), `godot-travelling-projectile-3d` (the steer is a new
per-frame heading adjust on the existing travel loop), `godot-verify` (projectiles visibly bend, can
still miss, no infinite-orbit lock). Acceptance: F5 — cyan magnet enemy in waves; bullets fired past
it visibly curve toward it; flanking/close shots still hit your intended target; magnet dies + feeds
escalation/HUD/win like other types. *Note:* this is the heaviest item — projectile-steering is new
behaviour; consider splitting into 9a (enemy+swatch+spawn, magnetism off) and 9b (projectile steer)
if it doesn't fit one task.

**10. Per-type kill scoring + win-by-score.** Replace the flat 25-kill win with a **score**: each
enemy type carries a `score_value` (grunt 1, runner 2, tank 3, magnet 3); `wave_manager.gd` sums
score on `died` and wins at `win_score` instead of `win_target` kills. `arena_hud.gd` gains a
`SCORE  n` line (KILLS can stay or be replaced). Reframes G2's win condition; touch/lives unchanged.
Skill: `godot-composition` (score on the enemy as an export, summed up in the manager),
`godot-code-rules`, `godot-verify`. Acceptance: F5 — killing a tank adds more to SCORE than a grunt;
reaching `win_score` triggers the existing YOU WIN panel. Last because it only matters once 3–4 types
with different values exist (#9) and it edits the win logic shipped in G2.

## Later (parked beyond these 10)

- Weapon recoil/spread patterns, ADS (aim-down-sights) zoom.
- Pickups (ammo crates, health) on the arena floor.
- Per-weapon damage values + multi-hit interplay (currently 1 dmg vs `health`).
- Ranged enemy (fires back) — bigger new FSM state.
- Difficulty curve: ratios/score thresholds that escalate with progress.
- Pixel-font HUD theme; styled ammo/score panel.
- Weapon inventory >2 with a real selection UI (explicitly out of POC scope).

## Open questions

None blocking the top 3. For #9 (magnetic) the interpretation is decided (bullet-magnet) and split
guidance is given. For #8/#10, bringing **ammo/reload economy** and a **2-weapon swap** in scope is a
roadmap-scope decision — recorded as a Track H proposal for the user to ratify (mirrors how C/F/G
were pulled in); does not block building items 1–7, which are pure depth on existing systems.
