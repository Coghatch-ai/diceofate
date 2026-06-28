# DiceOfFate — Known Problems (review consultation list)

Outstanding architectural debt. Reviewers and the orchestrator consult this during any
review/synthesis pass; builders check it before touching a listed file. Each row names the
rule's owning skill — the **RULE** lives in the skill, the **INSTANCE** lives here. Remove a row
when the instance is fixed.

## Duplication (rule: godot-code-rules DRY / godot-composition "Where extraction goes")

| Instance | Sites | Target |
|---|---|---|
| `_get_vfx_root` | vfx_router, npc_vfx (×2) | `tools/lib/vfx_utils.gd` |

## .tscn authoring (rule: godot-verify Transform3D-ban)

| Instance | Site |
|---|---|
| hand-authored Transform3D | player.tscn:25,31,34,38,60 |

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
| Disconnecting a signal | Guard with `is_connected(sig, callable)` before `disconnect(...)` (and the mirror for connect) — disconnecting an unconnected signal throws. Rule: godot-composition "Signal hygiene". |
| Signal naming | Name a signal for the **event that happened** (past tense — `died`, `health_changed`), one canonical name per event declared once; never name it for the listener's command, never mirror the same fact under two names. Rule: godot-composition "Signal hygiene". |
