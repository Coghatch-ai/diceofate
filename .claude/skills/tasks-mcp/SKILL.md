---
name: tasks-mcp
description: Use mcp__ui__tasks as a plan and scratchpad inside any agent run. Add tasks at start, update status as you work, use note as scratchpad. Visible in the UI right rail and persistent across sessions.
metadata:
  type: utility
---

# Tasks MCP — Plan & Scratchpad

`mcp__ui__tasks` is a persistent task board (stored at `.xenodot/tasks.json`, shown in the UI right rail). Use it in every run as:

1. **Plan** — add a batch at the start so the user sees every step before you begin.
2. **Scratchpad** — update `status` and `note` as you work so progress is visible live.

## Operations

```jsonc
// Add a batch at the start of your run
{ "op": "add", "tasks": [
  { "title": "Read design doc",   "owner": "agent" },
  { "title": "Build scene",       "owner": "agent" },
  { "title": "Run validate.sh",   "owner": "agent" }
]}

// Single add
{ "op": "add", "title": "Fix collision", "owner": "agent" }

// Mark in-progress (+ scratchpad note)
{ "op": "update", "title": "Build scene", "status": "in_progress", "note": "working on wall merge" }

// Mark done
{ "op": "update", "title": "Build scene", "status": "done" }

// Remove (when a step turns out to be unnecessary)
{ "op": "remove", "title": "Build scene" }
```

## Fields

| Field | Values | Notes |
|---|---|---|
| `title` | string | Required; used as the key for `update`/`remove` |
| `owner` | `"agent"` (default) \| `"user"` | `"user"` tasks surface in the Get Assets / task modal for the human |
| `status` | `"pending"` → `"in_progress"` → `"done"` | |
| `note` | string | Free text; use as scratchpad — visible in the UI |

## Pattern for every run

```
START  → op: add   (batch — full plan)
BEFORE each step → op: update status: in_progress  (+note if useful)
AFTER  each step → op: update status: done
END    → all tasks done; no stale entries left
```

## Rules

- Add the plan before doing any work — not after.
- Never leave tasks in `pending` or `in_progress` when you return.
- `owner: "user"` only for things the human must supply (an asset, a decision) — not for your own steps.
- Calling `mcp__ui__tasks` never pauses the session; call it freely between other tool calls.
