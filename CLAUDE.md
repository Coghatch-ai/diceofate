# DiceOfFate — game conventions

This repo is the **game** (a first-person shooter (FPS) POC on Godot 4.6). The AI framework that
builds it — the agents, the `godot-*` skills, the verify/gen tools, and the design→build→verify
pipeline — is **not** in this repo: it loads from the **xenodot** Claude Code plugin (the single
source of truth). Its working files appear here only as gitignored, generated paths:
`tools/` (copied from the plugin) and `library/` (a symlink to the plugin's knowledge base).

This file records only **this game's** conventions — keep it thin (record new project-wide
decisions here, not in chat). Game-specific skills/agents you haven't promoted to the framework
live in this repo's `.claude/`; everything else comes from the plugin.

## Project conventions

- Engine: Godot-family — runs on Godot, Redot or Blazium (shared project format / GDScript / CLI);
  this game is pinned to **Godot 4.6** (reversed-Z; per `project.godot` `config/features`). Renderer:
  Forward+ (required by outline shaders). Switch engines by pointing `$GODOT` at the fork binary
  (see the xenodot plugin's `docs/engines.md`).
- Art style: standard-HD 3D, first-person. This game began as a 3D-pixel-art POC and has **moved to
  an FPS**; the pixel-art SubViewport-downscale look (`godot-3d-pixelation`) is **superseded for this
  game**. If that downscale rig is still wired in `main.tscn`, treat removing/bypassing it as cleanup.
  Post-process effects attach to the active first-person camera.
- Camera: first-person perspective eye-camera (skill `godot-first-person-controller`). The orthographic
  follow rig (`godot-orthographic-follow-camera`) belonged to the prior top-down/iso POC and does not
  apply to this FPS.
- NOTE (pixel-art residue): the asset-import rows below and the `*-import-pixel-art` skills still assume
  NEAREST-filter / no-mipmap pixel-art import. For HD assets that is an open art decision (filtering,
  mipmaps) — flag to asset-advisor / art-director before sourcing; not yet reconciled here.
- Sourced art by medium: **textures** (PNG) → `assets/textures/<name>.png`, **3D models** (`.glb`) →
  `assets/models/<name>.glb` (snake_case; `assets/` gitignored; a model's own textures still go in
  `assets/textures/`). Sourcing/verifying both is the asset-advisor loop; detail in the
  `godot-texture-import-pixel-art` / `godot-mesh-import-pixel-art` skills.
- Shared example assets (from a free CC0 library, kept OUTSIDE this game's tree) resolve at
  `res://x-shared-assets/{textures,models}/<name>.<ext>` — a gitignored symlink to an external dir
  the framework knows about; pick this "place" in the Get Assets UI. Same import rules as above apply.
- Art-kind → technique (pick BEFORE filing an asset request; the *why*/gotchas live in the skills):

  | Art need | Technique | How |
  |---|---|---|
  | Greybox stage | flat-colour `BoxMesh` primitive | placeholder, **never** final art |
  | Discrete prop / furniture / item | **sourced low-poly `.glb`** (primary) | instance in place of the greybox node — NOT a texture on a box. Skill `godot-mesh-import-pixel-art`. Prototype placeholder: `tools/gen_models.gd` (skill `godot-procedural-model`) |
  | Large flat surface (wall / floor / ground) | tileable surface texture | `StandardMaterial3D` + `uv1_scale` + Texture Repeat, opaque. Skill `godot-texture-import-pixel-art`. Prototype placeholder: `tools/gen_textures.gd` (skill `godot-procedural-texture`) |
  | Vegetation / tiny detail | billboard sprite | `godot-foliage` rig |

- Naming: node names PascalCase; files and folders snake_case; one scene per entity in `entities/<name>/`.
- Input actions: `move_left, move_right, move_forward, move_back, jump, cycle_level` (Tab).
- Shader contract: `shaders/post/` for screen-space post-process (skill `godot-screen-effects`);
  `shaders/material/` for spatial/vertex material shaders (grass, foliage, toon — NOT post-process).
- Entry point: `res://main.tscn` + `res://main.gd` at the project root (`run/main_scene`). F5 launches
  Main; F6 launches individual scenes. Every scene lives in its domain folder; only the entry point
  sits at root.
- Level loading: levels swap under `Main/LevelHost`; never `change_scene_to_file()` — rules live in
  skill `godot-main-scene`.
- Hand-authoring `.tscn`: rules (Transform3D ban, Sky resource requirement) live in skill `godot-verify`.
- Enemy combat: the shootable-enemy hit/death/kill-confirm contract lives in skill `godot-fps-enemy-combat`
  — distinct from `godot-enemy-ai` (nav/FSM) and `godot-travelling-projectile-3d` (firing/despawn).
- godot-oneshot-vfx: fire-and-free 3D VFX (GPUParticles3D one-shot freed on `finished`) routed off combat seams (fired/hit/died) — muzzle, impact, death burst, shockwave; perf budget; Forward+. NOT the vignette (godot-screen-effects) nor the projectile trail (godot-travelling-projectile-3d).
- godot-decal-vfx: pooled surface-projected `Decal` marks (scorch/bullet-hole/blood) — N reused round-robin slots under VfxRoot, fade+recycle with Tween.kill before reuse, degenerate-safe normal→basis orientation (flat on floor/ceiling/wall), clustered (NOT deferred) 512-element cost model, decal-mask import contract (premult OFF / fix_alpha_border ON / mipmaps ON). Consumes the projectile hit-signal normal (godot-travelling-projectile-3d). Decals = THIS skill; fire-and-free particle/mesh one-shots = godot-oneshot-vfx.
- godot-runtime-smoke: the L2 layer — a headless `tools/smoke_*.gd` SceneTree script that boots a real scene, drives ONE gameplay seam (`weapon.try_fire()`, a simulated hit) and ASSERTS runtime outcomes validate.sh misses (signal arity/payload, recoil applied, `died` fired, no leak); wires as a validate.sh step after the smoke run. No GdUnit4. Headless caveat: logic/signal asserts work headless; render/draw/pipeline asserts need a windowed run (godot-verify L3). Logic = THIS skill; feel = godot-fps-game-feel.
- godot-fps-game-feel: the L3 periodic polish SWEEP (NOT a per-commit gate) — five measurable categories (input-feedback ≥2 channels per action, VFX-SFX timing, perf headroom ≥60 FPS / no first-spawn hitch, input responsiveness & readability, audio presence), plus weapon-feel specifics (recoil reads, walk-vs-sprint view-model, weapon identity). Researcher diffs the windowed build vs the checklist → godot-dev fixes → re-verify. Audits already-built systems; does not author them.
- Composition over inheritance (skill `godot-composition`): engine-node base + component children,
  signals up / calls down; modularize ON DEMAND only.
- Code rules: strict typed GDScript (skill `godot-code-rules`); gate `tools/validate.sh`, mandatory
  before reporting any `.gd`/`.tscn` change. Never weaken warning levels or lint caps to pass it.
- Quality stack (beyond validate.sh's L0 load+render): L1 baseline = `design/review_checklist.md`,
  the always-on lightweight rubric godot-dev self-checks before "done" (cross-file signal arity, no
  autoload sneak-in, leaks); escalate high-risk diffs to the `code-reviewer` agent (fresh isolated
  session, diff-only, Codex when available else Claude — review only, never edits). L2 runtime-smoke
  = skill `godot-runtime-smoke` (headless logic asserts, a validate.sh step). L3 feel = skill
  `godot-fps-game-feel` (periodic windowed sweep). Per-commit = L0+L1+L2; L3 is periodic, not a gate.
- Shell: prefix every command with `rtk` — the token-optimized proxy (safe; unknown commands pass
  through). Exceptions run as-is: the engine binary (`$GODOT --headless …`) and `tools/validate.sh`.
- Before structural changes, read this section; load `godot-code-rules` before writing/editing any
  `.gd`; record new project-wide decisions here — keep it thin.
- Active roadmap: `docs/roadmap/fps_poc.md` (this game's current roadmap). Before starting a task,
  identify its phase/track; refuse tasks in the 'out of scope' list or in phases after an unpassed gate.
- Roadmap status ownership: only the verifier updates phase status (✅/🔨/📋) and gate pass/fail, only
  after running that phase's gate check in the editor. Builders never self-mark phases done.
