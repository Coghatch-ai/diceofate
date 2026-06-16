# Audio Bus + First SFX (Phase P1)

**Goal** — Firing the weapon plays a short punchy shot sound, routed through an SFX bus the project can mix.

**Scope (in)**
- Audio bus layout in `default_bus_layout.tres`: `Master` → child `SFX` bus, `Master` → child `Music` bus (Music empty this phase, defined so P4 needs no rework).
- Set the project's `audio/buses/default_bus_layout` to that resource (project setting; godot-dev's call, not the designer's hand-edit).
- One sourced CC0 fire SFX (short, punchy, retro/lo-fi), imported with loop OFF, on the **SFX** bus.
- Trigger on the existing fire hook: a child `AudioStreamPlayer` on the weapon (or player), played where `Weapon.try_fire()` returns true (so cadence matches the cooldown, not raw input).
- Establish the **one-shot player pattern** the rest of Track P reuses (overlapping shots must not cut each other off — pooled players or `AudioStreamPlayer` per-shot per the adopted `godot-audio` skill).

**Scope (out)**
- All other SFX (hit/death/reset/jump/land) — that's P2.
- Spatial 3D audio — that's P3.
- Music/ambient — that's P4 (bus exists now; no stream).
- Global AudioManager autoload — per-entity player; revisit only if pooling proves it.
- Volume/options UI — out for the whole roadmap.

**Acceptance**
- F5 (human ear-check): clicking fires plays a short shot sound; rapid fire doesn't cut sounds off harshly; cooldown cadence matches the audio.
- Muting/lowering the **SFX** bus silences/lowers the shot (proves routing).
- `godot-verify`: all scenes load + render, no "stream not found"/import errors; `tools/validate.sh` clean on any `.gd` touched.

**Skill notes**
- **BLOCKED until `godot-audio` is adopted** (capability gap — see roadmap). That skill must settle: bus-layout convention, `AudioStreamPlayer` vs `AudioStreamPlayer3D` (here: 2D/global is correct — weapon is always at the camera), SFX import settings (loop off, no stutter), and the one-shot fire-and-free / pooling pattern.
- `godot-composition`: sound node is a child of the firing entity; triggered at the existing event seam, no new manager.
- `godot-verify`: ear-check is human-only; verify covers load/render/no-error, not "sounds good".
- Asset loop: source the fire SFX (CC0, retro/lo-fi) → proposed path `assets/audio/<name>.<ext>` (confirm with `godot-audio`).

**Later**
- Pitch/volume jitter per shot for variation.
- Distinct empty/cooldown "click" when fire is gated.

**Open questions**
- Audio asset path (`assets/audio/`?) and one-shot pattern specifics — resolved by adopting `godot-audio`. Blocks build start.
