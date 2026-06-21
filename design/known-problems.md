# DiceOfFate — Known Problems (review consultation list)

Outstanding architectural debt. Reviewers and the orchestrator consult this during any
review/synthesis pass; builders check it before touching a listed file. Each row names the
rule's owning skill — the **RULE** lives in the skill, the **INSTANCE** lives here. Remove a row
when the instance is fixed.

## Duplication (rule: godot-code-rules DRY / godot-composition "Where extraction goes")

| Instance | Sites | Target |
|---|---|---|
| tint-walker | runner/tank/shooter/magnet (×4) | `tools/lib/enemy_utils.gd` |
| `_get_vfx_root` | vfx_router, npc_vfx (×2) | `tools/lib/vfx_utils.gd` |
| floor-slab StaticBody3D+mesh+collision | firing_yard_nodes, build_rw_slice_e4, build_ruined_warehouse (×3) | `tools/lib/level_nodes.gd` (LevelNodes) |
| `_reset_player` verbatim | firing_yard.gd, ruined_warehouse.gd (×2) | shared helper |

## Composition boundaries (rule: godot-composition)

| Instance | Site | Fix direction |
|---|---|---|
| group-scan + parent-walk for nav-region | WaveManager | `@export` injection (rule 5) |
| behaviorless subclasses differ only by tint | runner/tank | `@export tint_color` on Enemy base (rule 7) |

## .tscn authoring (rule: godot-verify Transform3D-ban)

| Instance | Site |
|---|---|
| hand-authored Transform3D | main.tscn:29, player.tscn:20,31,36,41 |

## Process — RESOLVED at tool level

The "forms must offer a free-text escape hatch" issue is now enforced **deterministically in the
`mcp__ui__form` tool itself** (`xenodot-forge/ui/server/mcp-tools/form-tool.js` injects a trailing
non-required `additional_feedback` textarea on every form). No agent-prompt rule needed; the
per-prompt guidance was reverted. Takes effect on the next forge MCP-server restart. Remove this
note once that change is committed/deployed.

## Decided design answers (durable, so a future synthesis doesn't re-litigate)

| Question | Answer |
|---|---|
| Player health ownership | A Health **component** on the player (signals up / calls down), **NOT** the run_state autoload. Health is its own entity per godot-composition; do not centralize entity state in an autoload. |
