# Weapon Swap/Use Consistency Overhaul

**Goal** — Player uses any equipped weapon with one button (LMB); Q cycles pistol→rifle→hammer with each weapon visibly held on screen; node/class names match what each weapon actually is.

## Decisions (locked via interview 2026-06-21)
1. **Use** — LMB = use whatever is equipped (gun fires / hammer swings). V removed entirely. RMB (`aim`) aims guns only; no-op when hammer equipped.
2. **Q swap** — keep 3-slot cycle pistol→rifle→hammer→pistol; all 3 always in cycle. Hammer slot fixed to stay visible at rest (held like a real weapon), drawn/holstered like guns.
3. **Naming** — instances `$Head/Pistol`, `$Head/Rifle`, `$Head/Hammer`. Rename class `Weapon`→`Gun` (the shared firing base), class `Melee`→`Hammer`. Files `weapon.gd`→`gun.gd`, `melee.gd`→`hammer.gd`, folder stays `entities/weapon/`.

## Scope (in)
- **Remove quick-melee on V.** Delete the `melee` input branch in `weapon_controller.process_input`; melee only fires via LMB when hammer slot active. Remove `melee` action from `project.godot`.
- **LMB routes to active weapon.** `shoot` pressed → if active is a gun `try_fire()`, if hammer `try_melee()`. Single `_active_weapon` reference covers all 3 slots (no more `null`-means-melee).
- **Hammer slot stays visible.** Hammer view-model held at rest when its slot is active (no self-hide). Remove the `swing_finished`→hide-root logic and the `_ready` self-hide that the old V quick-melee depended on. Hammer draws/holsters on swap like guns.
- **RMB hammer no-op.** `aim` while hammer active does not ADS and does not error.
- **Rename instances + classes** per Decision 3 via godot-refactor; update all references (`weapon_controller.gd` `@onready`/`@export`, `.tscn` node names, `class_name`, any `Weapon`/`Melee` type hints, `design/weapon_ammo_hud.md` mention of `$Head/Weapon` is a doc — leave or note).
- **HUD ammo on hammer.** Hammer has no ammo → HUD shows empty/melee state (reuse existing `_wire_ammo_hud` null path, now keyed on weapon kind not null).

## Scope (out)
- New weapons / 4th slot — not now.
- Scroll-wheel or number-key direct select — Q cycle only this slice.
- Quick-melee on any button — removed by Decision 1, parked.
- Hammer block/parry on RMB — out; RMB is plain no-op for hammer.
- Re-tuning recoil/spread/feel — separate godot-fps-game-feel sweep.
- Model/mesh changes — models already swapped; this is wiring+naming only.

## Acceptance
- F5 Main: spawn holds Pistol visible. Q → Rifle visible, drawn. Q → Hammer visible AND held at rest (NOT empty screen). Q → Pistol.
- LMB with Pistol/Rifle fires; LMB with Hammer swings. No V key does anything.
- RMB aims with a gun; RMB with Hammer does nothing, no error.
- `grep -r "melee" project.godot` → no `melee` input action. `grep -rn "\$Head/Weapon\|class_name Weapon\|class_name Melee"` over `entities/` → no hits (renamed to Pistol/Gun/Hammer).
- `tools/validate.sh` passes (L0+L1). godot-runtime-smoke: assert LMB on hammer slot calls `try_melee` and gun slot calls `try_fire`; assert no `melee` action lookup.
- Human look: one F5, cycle all 3 + use each.

## Skill notes
- **godot-composition** — keep signals-up/calls-down; `_active_weapon` polymorphic over Gun/Hammer (duck-typed `try_fire`/`try_melee` from `process_input`, no base-class merge).
- **godot-fps-enemy-combat** — preserve hit/kill-confirm contract; both Gun and Hammer already emit `hit_confirmed`/`kill_confirmed` — keep wiring intact through rename.
- **godot-runtime-smoke** — add/adjust smoke asserts for use-routing + removed action; validate.sh step.
- **godot-verify** — after rename + .tscn edits, L0 load+render; renames are the silent-drop risk class.
- **godot-code-rules** — load before editing any `.gd`; rename must keep strict typing (update type hints `Weapon`→`Gun`, `Melee`→`Hammer`).
- **godot-main-scene** — `main.gd` wires crosshair/ammo HUD into the controller; verify injection still binds after rename.
- Input action removal lives in `project.godot` (game-designer doc only flags it; godot-dev edits it — allowed, it's project settings the build owns).

## Later
- Scroll-wheel / 1-2-3 direct weapon select.
- Hammer RMB heavy/charged swing.
- Weapon-switch SFX + view-model switch polish (godot-audio / game-feel).

## Open questions
None.
