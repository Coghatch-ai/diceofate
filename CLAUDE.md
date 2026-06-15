# DiceOfFate — Claude Context

POC for a game developer framework using Godot 4.x. The goal is to build small things and observe how agents behave.

> **Keep this file thin — it is the always-loaded routing hub, not a manual.** It records *when* to use each agent / skill / loop and the project conventions; the *how* (steps, templates, gotchas) lives in the agent prompt or the skill, which load on demand. Adding or changing a capability = **one line** here (a routing-table row, a `## Skills` entry, or a convention line) + the detail in the agent/skill. Do **not** append a new prose section, restate an agent's steps, or duplicate a skill; if a bullet grows past ~2 lines, move the detail out and leave a pointer. Match the existing structure and tone.

## Project layout

```
main.tscn         entry point + main.gd, at project root (skill: godot-main-scene)
design/           design docs — one per agreed slice (written by game-designer only)
transcripts/      raw transcript drop zone → transcript-researcher
library/          warm knowledge, never auto-loaded — see library/README.md
entities/         one scene+script per entity, entities/<name>/
levels/           level scenes
shaders/          post/ (screen-space) + material/ (spatial/vertex)
resources/        .tres resources
tools/            framework tooling — not game code
.claude/
  agents/         the pipeline's agents — the routing table below names each by when to use it
  skills/         godot-* skills (see ## Skills; eval/ = researcher scratch, never committed)
```

## How to work on this project

**Pipeline:** idea → **game-designer** (scope) → **godot-dev** (build) → **godot-verify** → human runs (F5/F6). The editor viewport is NOT verification — it hides camera/lighting bugs.

**Self-improvement spine** (the shape every route below shares): the framework grows by *pull* — an agent queries the registry (`## Skills`, `tools/CAPABILITIES.md`, `library/`); on a genuine gap it flags what's missing and the orchestrator routes to the matching researcher (**human-gated**); the result registers back so the next query finds it. Capability gaps only — ordinary work never enters the loop.

**Routing** (the *when*; mechanics live in each agent/skill, the result registers where the next agent will look):

| When a request / gap is… | Route | Result registers to |
|---|---|---|
| a small concrete change, ~1 entity, one F5 | `/quick` skill | — |
| a vague / multi-step feature | **game-designer** → godot-dev | `design/<slug>.md` |
| a bug that surfaced or was fixed | offer **bug-triage** (ask, never auto-run) | a skill / docs / "no change" |
| a knowledge gap no `godot-*` skill covers | **skill-researcher** (`library/sources/skill-sources.md`) | `.claude/skills/godot-<name>/` + `## Skills` |
| a generic solved-elsewhere system (dialogue, inventory, save…) | **addon-researcher**, BEFORE designing | `library/addons/<slug>.md` |
| an agent-capability gap (render a frame, capture debug output) | **cli-researcher** (CLI default; MCP parked) | `library/tools/<slug>.md` → `tools/CAPABILITIES.md` |
| about to build a domain a saved transcript covers | **transcript-researcher**, FIRST | `library/transcripts/<slug>.md` |
| blocked on art (a texture or a 3D prop) | **asset-advisor** / asset-sourcing loop | `assets/` + the two catalogues |
| a level drawn in the Draw-level tool | **level-designer** → game-designer | `design/levels/<name>.md` |

**Two loops carry orchestrator glue beyond a single agent:**
- *Asset-sourcing:* asset-advisor gate 1 → orchestrator calls `mcp__ui__request_asset` (`{name, kind, prompt}`) → 🎨 Get Assets modal → user picks or names a local PNG/GLB → server writes `assets/textures/` or `assets/models/` (by file type) → asset-advisor gate 2 → on PASS, godot-dev wires it → godot-verify.
- *Draw-level:* the UI exports `levels/drawn/current.json` → level-designer writes the brief → game-designer slices it → godot-dev builds a GridMap + MeshLibrary (skill `godot-gridmap-level`), never hand-authored Transform3D boxes.

**Governance:**
- **Role boundary** — the orchestrator (main session) edits framework files only (`.claude/`, CLAUDE.md); ALL game/project file changes (scenes, scripts, project.godot, tools) go through the agents. When something breaks, the deliverable is the framework fix, not a hand-patched file.
- **Human gate** — every researcher (skill / addon / cli / transcript / asset / level) asks the human to adopt / reject / park; it never auto-adopts and never writes game code. "No change" is a valid outcome.
- **Discoverability** — the user may not know a route exists; name the matching one in a line before/while acting, ≤1 route per reply, and skip it when they already invoked it. Suggest, don't lecture.
- **Small + verifiable** — anything that can't be built and verified in one small step goes through game-designer first (it pushes back on scope). A framework to speed up development, not a vibe-coding tool.

## Skills (in `.claude/skills/`)

Each skill's full description loads with it — this is the index (load-order hint where it matters):

- `godot-project-conventions` — run FIRST in a new setup; records conventions here
- `godot-main-scene` · `godot-3d-pixelation` · `godot-orthographic-follow-camera` — persistent shell, SubViewport downscale, orthographic top-down/iso camera
- `godot-first-person-controller` — FPS sibling of godot-orthographic-follow-camera: CharacterBody3D + child Head perspective eye-camera inside the SubViewport, raw mouse-look (yaw body / pitch head), camera-relative WASD + jump; pick one camera skill per genre
- `godot-travelling-projectile-3d` — fire a travelling projectile (spawn at a `Marker3D` muzzle, `top_level` detach, move `-z`, despawn on range, Area3D hit) gated by a one-shot `Timer` cooldown; a host-agnostic firing component. NOT hitscan/raycast
- `godot-pixel-lighting` · `godot-screen-effects` — sun/ambient/tonemap; post-process quad + depth/normal reads
- `godot-texture-import-pixel-art` · `godot-mesh-import-pixel-art` · `godot-foliage` — textures (NEAREST/no-mipmap), sourced `.glb` props, billboard foliage
- `godot-procedural-texture` — generate local placeholder pixel-art surface textures procedurally (`tools/gen_textures.gd`, Image API, seamless); add a spec + re-run. Placeholder path, not final art
- `godot-procedural-model` — generate local placeholder low-poly `.glb` props procedurally (`tools/gen_models.gd`, primitive kitbash → GLTFDocument); add a spec + re-run. Placeholder path, not final art
- `godot-animation-libraries` — skeletal animation on a sourced rigged `.glb`: separate model/anim glTF files, merge clips into one AnimationLibrary on your own AnimationPlayer, retarget a foreign clip (Mixamo) via SkeletonProfileHumanoid (Phase 8; complements `godot-mesh-import-pixel-art`)
- `godot-gridmap-level` — drawn-grid / tile levels via GridMap + MeshLibrary
- `godot-composition` — component-node pattern; load before modularizing
- `godot-code-rules` — typed-GDScript rules; load before editing any `.gd`
- `godot-verify` — mandatory 3-layer check; the gate before "done"

## Project conventions

- Engine: Godot-family — runs on Godot, Redot or Blazium (shared project format / GDScript / CLI); this game is pinned to **Godot 4.6** (reversed-Z; per project.godot `config/features`). Renderer: Forward+ (required by outline shaders). Switch engines by pointing `$GODOT` at the fork binary (see xenodot-forge/docs/engines.md).
- Art style: 3D pixel art. 3D content renders inside a SubViewport (skill: godot-3d-pixelation); post-process effects attach to the camera inside it.
- Camera: projection is genre-dependent, NOT fixed. The pixel-art look comes from the SubViewport downscale (godot-3d-pixelation), not the camera — perspective and orthographic both render pixelated inside it. Orthographic fixed-angle (skill: godot-orthographic-follow-camera) is the default for top-down/iso games; first-person/third-person genres use a perspective eye-camera inside the SubViewport. Switching projection only trades the texel-snapping behaviour (flag it, don't forbid it).
- Sourced art by medium: **textures** (PNG) → `assets/textures/<name>.png`, **3D models** (`.glb`) → `assets/models/<name>.glb` (snake_case; `assets/` gitignored; a model's own textures still go in `assets/textures/`). Source PNG = image; imported = texture (`CompressedTexture2D`); the `.tres` that uses it = material. Sourcing/verifying both is the asset-advisor loop; detail in skills `godot-texture-import-pixel-art` / `godot-mesh-import-pixel-art`.
- Art-kind → technique (pick the right one BEFORE filing an asset request; the *why* and the gotchas live in the named skills):

  | Art need | Technique | How |
  |---|---|---|
  | Greybox stage | flat-colour `BoxMesh` primitive | current builder — placeholder, **never** final art |
  | Discrete prop / furniture / item | **sourced low-poly `.glb` model** (primary) | instance the model in place of the greybox node — NOT a texture on a box. Skill `godot-mesh-import-pixel-art`; catalogue `library/sources/model-sources.md`. Prototype placeholder: generate locally with `tools/gen_models.gd` (skill `godot-procedural-model`) |
  | Large flat surface (wall / floor / ground) | tileable surface texture | `StandardMaterial3D` + `uv1_scale` (sized to the face) + Texture Repeat on, **opaque (no alpha)**. Skill `godot-texture-import-pixel-art`. Prototype placeholder: generate locally with `tools/gen_textures.gd` (skill `godot-procedural-texture`) |
  | Vegetation / tiny detail | billboard sprite | existing `godot-foliage` rig |

- Naming: node names PascalCase; files and folders snake_case; one scene per entity in entities/<name>/.
- Input actions: move_left, move_right, move_forward, move_back, jump, cycle_level (Tab).
- Shader contract: `shaders/post/` for screen-space post-process (skill: godot-screen-effects — the quad rig + `get_linear_depth()` / `get_normal()` helpers). `shaders/material/` for spatial/vertex material shaders (grass, foliage, toon — NOT post-process).
- Entry point: `res://main.tscn` + `res://main.gd` at the project root (`run/main_scene`). F5 launches Main; F6 launches individual scenes. No generic `scenes/` folder — every scene lives in its domain folder; only the entry point sits at root.
- Level loading: levels swap under `Main/LevelHost`; never `change_scene_to_file()` — loading rules + the pixelation migration note live in skill godot-main-scene.
- Hand-authoring .tscn files: rules (Transform3D ban, Sky resource requirement) live in skill godot-verify, "Hand-authoring .tscn rules".
- Composition over inheritance (skill: godot-composition): engine-node base + component children, signals up / calls down; modularize ON DEMAND only. Mechanical extractions go to the godot-refactor agent (Haiku), which must verify before AND after.
- Code rules: strict typed GDScript (skill: godot-code-rules); gate `tools/validate.sh`, mandatory before reporting any .gd/.tscn change. Never weaken the warning levels or lint caps to pass it.
- Shell: prefix every command with `rtk` — the token-optimized proxy (safe; unknown commands pass through; a PreToolUse hook backstops it). Full reference in the global/parent CLAUDE.md. Exceptions with no rtk filter, run as-is: the Godot binary (`$GODOT --headless …`) and project scripts (`tools/validate.sh`).
- Rule for AI sessions: read this section before structural changes; load godot-code-rules before writing/editing any .gd file; record new project-wide decisions here, not in chat — keep it thin (see the note at the top).
- Active roadmap: docs/roadmap/fps_poc.md (the first-person shooter POC). Retired: `first_game.md` (completed foundation POC), `itch_demo.md` (unbuilt apartment-demo idea). Before starting any task, identify its phase/track. Refuse tasks in the 'out of scope' list or in phases after an unpassed gate.
- Roadmap status ownership: only the verifier updates phase status (✅/🔨/📋) and gate pass/fail, only after running that phase's gate check in the editor. Builders never self-mark phases done.
