---
name: godot-verify
description: Verify Godot scenes and scripts actually load and run cleanly, including invalid property names that Godot silently drops. Use this skill after ANY change to .tscn/.gd files and before claiming work is done or verified — never assert "the scene runs" without running these checks. Also use it when a scene loads but looks wrong (missing material, wrong lighting), which is the signature of a silently dropped property.
---

# Godot Verify (headless checks)

Two-layer verification, both required. Run from the project root (where `project.godot` is).

The Godot binary on this machine: `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH — `which godot` fails). Define `GODOT=/Applications/Godot.app/Contents/MacOS/Godot` once per shell call.

## Why two layers (verified behavior, Godot 4.6)

- **Exit codes lie.** Godot exits 0 even when `SCRIPT ERROR:` parse failures are printed. Never trust `$?`; grep the output.
- **Unknown properties are silently dropped.** A `.tscn` with `energy_multiplier = 1.5` on a DirectionalLight3D (Godot 3 name) or `material/0` on a MeshInstance3D loads and runs with zero warnings — the property just vanishes. Runtime checks cannot catch this class of bug; only layer 1 does.

## Layer 1 — property validation (catches silent drops)

```bash
$GODOT --headless --path . --script tools/verify_scene.gd                      # all scenes
$GODOT --headless --path . --script tools/verify_scene.gd -- scenes/main.tscn  # one scene
```

`tools/verify_scene.gd` instantiates each scene and checks every property assignment in the `.tscn` text against the live object's `get_property_list()`. Output:

- `VERIFY-FAIL <scene> [<node|sub_resource>] <reason>` — one line per problem
- `VERIFY: OK — N scene(s) clean` or `VERIFY: FAIL — N problem(s)`
- Exit code is meaningful here: 0 clean, 1 problems.

Loading the scenes also surfaces `SCRIPT ERROR:` parse errors in attached scripts and missing ext_resource files.

Known blind spots: `shader_parameter/*` and `metadata/*` are whitelisted (dynamic); property *values* are not checked, only names.

## Layer 2 — smoke run (catches runtime errors)

```bash
$GODOT --headless --path . --quit-after 3 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"
```

Runs the main scene for 3 frames. Catches `_ready()`/`_process()` crashes, autoload failures, missing main scene. **Any matched line = failure**, regardless of exit code (grep exiting 1 = no matches = pass).

## Pass criteria (both required)

1. Layer 1 prints `VERIFY: OK` and exits 0.
2. Layer 2 grep finds nothing.

Only then may you report the change as verified. If you cannot run the binary (no Godot on the machine), say so explicitly — do not claim verification.

## Error → Fix

| Symptom | Fix |
|---|---|
| `VERIFY-FAIL ... unknown property "X"` | Godot 3 name or typo; find the Godot 4 name (e.g. `material/0` → `surface_material_override/0`, `energy_multiplier` → `light_energy`) |
| `VERIFY-FAIL ... could not resolve node` | `parent=`/`name=` path in the .tscn doesn't match the tree — check section order and parent paths |
| `SCRIPT ERROR: Parse Error` during layer 1 | The attached .gd fails to compile; fix the script, not the scene |
| `ERROR: ... Invalid UID` | Hand-written uid string; remove the `uid="..."` attribute and let the editor assign one on save |
| Layer 2 hangs | Scene waits on input/window; `--quit-after N` missing or a script blocks `_ready` — check for infinite loops |

## RTK note

When invoking from Claude Code Bash, prefix the binary call with `rtk` as usual (`rtk $GODOT --headless ...` passes through unfiltered). Do **not** pipe into `rtk grep` — it summarizes matches to a count and hides the `VERIFY-FAIL` lines; use plain `grep` inside the pipe. Never reference rtk inside `.gd` files — it is a shell-side proxy, not part of the project.
