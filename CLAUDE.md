# DiceOfFate — Claude Context

POC for a game developer framework using Godot 4.x. The goal is to build small things and observe how agents behave.

## Project layout

```
main.tscn         entry point + main.gd, at project root (skill: godot-main-scene)
design/           design docs — one per agreed slice (written by game-designer only)
library/          warm knowledge, never auto-loaded: addon research catalog (addon-researcher) + skill-sources.md (external skill collection registry)
entities/         one scene+script per entity, entities/<name>/
levels/           level scenes
shaders/post/     post-process shaders
resources/        .tres resources
tools/            framework tooling (validate.sh, verify_scene.gd, verify_render.gd) — not game code
.claude/
  agents/         game-designer (Opus), godot-dev (Sonnet), godot-refactor (Haiku), skill-researcher (Opus), bug-triage (Opus), addon-researcher (Sonnet)
  skills/         godot-* skills, scoped to this project (skills/eval/ is researcher scratch — never committed)
```

## How to work on this project

Pipeline: idea → **game-designer** (Opus — interviews the user, cuts scope, writes `design/<slug>.md`) → **godot-dev** (Sonnet — implements the doc) → **godot-verify** (3-layer checks) → human **runs** it (F5/F6). The editor viewport is NOT verification — it uses the editor's camera and hides camera/lighting bugs.

Quick path: a request may skip the designer ONLY if all four checks pass — covered by existing skills/design docs, ~one entity touched, observable in one F5 run, no new conventions/input actions. Entry point is the `/quick` skill, which encodes the check, the godot-dev dispatch, and the report shape (Result / Files / Verify / Friction). godot-dev always reports **friction** (improvised pattern, first-try verify failure, scope overrun, ambiguous guidance); non-empty friction → the orchestrator offers bug-triage (ask, never auto-run — same gate as bugs).

Discoverability: the user may not know the framework's entry points exist — surface them in replies instead of routing silently. When a request matches a route, name it in one line before (or while) acting: small concrete change in prose → "this fits `/quick`"; vague or multi-step feature → game-designer; a bug just surfaced or was fixed → offer bug-triage; a pattern no skill covers → skill-researcher; a generic system the ecosystem has surely solved → addon-researcher. Suggest, don't lecture: one line, at most one route per reply, and skip it when the user already invoked the route themselves.

Role boundary: the orchestrator (main session) investigates and updates framework documentation only (`.claude/`, CLAUDE.md); ALL changes to game/project files (scenes, scripts, project.godot, tools) go through the agents. When something breaks, the deliverable is the framework fix, not a hand-patched file.

Bug learning loop: after a bug is found (and usually fixed by godot-dev), the orchestrator ASKS the user whether to triage it properly — never auto-runs it. On yes, spawn **bug-triage** (Opus) with the symptom, diagnosis, and fix. It finds the root cause and reaches one verdict: update an existing skill, recommend skill-researcher (missing skill), update documentation (CLAUDE.md / agent prompts), or no change — "no change" is a valid, expected outcome, not a failure. Framework edits need the user's approval inside the triage run; a researcher recommendation comes back to the orchestrator to dispatch.

This is a framework/workflow to speed up development — not a vibe-coding tool. Requests that can't be built and verified in one small step go through game-designer first; it is expected to push back on scope. Keep tasks small and discrete.

Self-improvement (skill gaps): when a task has no matching godot-* skill — godot-dev reports the gap, or the orchestrator sees it before dispatching — the orchestrator spawns **skill-researcher** (Opus). It searches the external skill collections registered in `library/skill-sources.md` (downloaded at runtime to `~/.cache/diceofate/` on first use — never bundled, never in /tmp), evaluates candidates in `.claude/skills/eval/<name>/` against project conventions, and asks the human to adopt or reject (same human-gate as game-designer). On adopt it rewrites — never copies — the skill into this project's skill format at `.claude/skills/godot-<name>/` (one canonical path, GDScript-only, MIT attribution) and registers it in the Skills list below. The eval copy is always deleted afterwards. We import only what a current task needs, never wholesale.

Buy-vs-build (addons): when a request is a generic, solved-elsewhere system (dialogue, inventory, save/load, state machines, pathfinding, debug overlays…), the orchestrator spawns **addon-researcher** (Sonnet) BEFORE game-designer designs it from scratch. It searches for free, license-compatible Godot 4 addons (Asset Library, GitHub), writes the evaluation to `library/<slug>.md` — the durable catalog; it checks existing `library/` verdicts before re-researching — and asks the human to adopt/reject/park (same human gate as the other researchers). On adopt, installation is a godot-dev task taken from the doc's Install section; the researcher itself never installs anything.

## Skills (in .claude/skills/)

- `godot-project-conventions` — run FIRST in any new setup; records conventions here in CLAUDE.md
- `godot-main-scene` — Main scene entry point; owns the persistent shell, loads/swaps levels
- `godot-3d-pixelation` — SubViewport low-res render setup
- `godot-camera-rig` — orthographic fixed-angle follow camera
- `godot-postprocess-quad` — fullscreen quad rig for screen-space effects
- `godot-screen-textures` — depth/normal/screen texture reading in shaders
- `godot-verify` — 3-layer verification: property names, smoke run, render check (mandatory after scene/script changes); validators at `tools/verify_scene.gd` + `tools/verify_render.gd`; layers 1–2 also run inside `tools/validate.sh`
- `godot-composition` — composition over inheritance ("SOLID for Godot"): component nodes, signals up / calls down, and the rules for when to modularize (and when not to)
- `godot-code-rules` — strict GDScript rules (typing, warnings-as-errors, size caps, headers, @warning_ignore/SEAM policy) + the `tools/validate.sh` gate; load before touching any .gd

## Project conventions

- Engine: Godot 4.3+ (reversed-Z). Renderer: Forward+ (required by outline shaders).
- Art style: 3D pixel art. 3D content renders inside a SubViewport (skill: godot-3d-pixelation); post-process effects attach to the camera inside it.
- Camera: orthographic, fixed angle (skill: godot-camera-rig). Do not switch to perspective without flagging the texel-snapping consequence.
- Folders: scenes/, entities/, levels/, shaders/post/, resources/.
- Naming: node names PascalCase; files and folders snake_case; one scene per entity in entities/<name>/.
- Input actions: move_left, move_right, move_forward, move_back, jump, cycle_level (Tab — cycles blockout levels via main.gd's load_level(); design: level-switcher.md).
- Shader contract: skills godot-postprocess-quad (single quad + shader file) and godot-screen-textures (helper names get_linear_depth(), get_normal()).
- Entry point: `res://main.tscn` + `res://main.gd` at the project root (set as `run/main_scene`). F5 launches Main; F6 launches individual scenes. No generic `scenes/` folder — every scene lives in its domain folder (levels/, entities/, …); only the entry point sits at root.
- Level loading: levels swap under `Main/LevelHost`; never `change_scene_to_file()` — loading rules, free()-vs-queue_free(), and the pixelation migration note live in skill godot-main-scene.
- Hand-authoring .tscn files: rules (Transform3D ban, Sky resource requirement) live in skill godot-verify, "Hand-authoring .tscn rules".
- Composition over inheritance (skill: godot-composition): entities = engine-node base + component children; signals up, calls down; shared components in entities/components/<name>/. Modularize ON DEMAND only — second consumer, two-jobs script, or a design doc naming a mechanic reusable. Mechanical extractions go to the godot-refactor agent (Haiku), which must verify before AND after.
- Code rules: strict typed GDScript (warnings-as-errors in project.godot + gdlint/gdformat via gdlintrc) — skill godot-code-rules; gate: `tools/validate.sh`, mandatory before reporting any .gd/.tscn change. Never weaken the warning levels or lint caps to pass the gate.
- Shell commands: prefix every command with `rtk` — the token-optimized CLI proxy (`rtk git status`, `rtk ls`, `rtk grep …`, `rtk cat …`; in chains too: `rtk git add . && rtk git commit`). RTK has dedicated filters for git/ls/grep/find/cat/test/build tools and passes anything else through unchanged, so it is always safe. A PreToolUse hook (`.claude/settings.json`) rewrites bare commands as a backstop, but type `rtk` yourself so the intent is explicit and the specialized filters (e.g. `rtk test`, `rtk grep`) get used. Exceptions with no rtk filter — run as-is: the Godot binary (`$GODOT --headless …`) and project shell scripts (`tools/validate.sh`).
- Rule for AI sessions: read this section before structural changes; load godot-code-rules before writing or editing any .gd file; record new project-wide decisions here, not in chat.
- Active roadmap: docs/roadmap/first_game.md. Before starting any task, identify which phase it belongs to. Refuse tasks in the 'out of scope' list or in phases after an unpassed gate.
- Roadmap status ownership: only the verifier updates phase status (✅/🔨/📋) and gate pass/fail, only after running that phase's gate check in the editor. Builders never self-mark phases done.
