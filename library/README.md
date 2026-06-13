# Library — warm knowledge (not loaded by default)

Nothing in this folder is loaded into an agent's context automatically. These are
"warm" files: durable research and registries that the **self-improvement loops**
consult on demand — and that a human can read to understand past verdicts. Hot
knowledge (always loaded or trigger-loaded) lives in CLAUDE.md and `.claude/skills/`;
this folder is everything worth keeping that should NOT cost tokens on every task.

Contents:

- **Addon research catalog** — one doc per investigated need (`<slug>.md`), written by
  the **addon-researcher** agent only (humans may edit verdicts). Before building a
  generic system, check here — a past verdict (adopted / rejected — build it ourselves /
  parked) is research we don't repeat. Doc template lives in
  `.claude/agents/addon-researcher.md`. The framework UI lists this folder in the
  sidebar with the verdict of each doc.
- **Transcript digests** (`transcripts/<slug>.md`) — one digest per saved video
  transcript, written by the **transcript-researcher** agent. When we're about to build
  in a domain a transcript covers, the video's main points are distilled once, verified
  against our stack, and mapped to what we already know — so a 40KB transcript becomes a
  one-page checked list of "covered / partial / gap" instead of a re-read. Raw
  transcripts are dropped into the project's `transcripts/` folder (the UI can create
  them there); once harvested the raw moves to `transcripts/archive/` (kept as the
  full-text backup) and the distilled digest lands here. The template lives in
  `.claude/agents/transcript-researcher.md`.
- **[skill-sources.md](skill-sources.md)** — registry of external skill collections used
  by the **skill-researcher** agent. These are never bundled with the repo; they are
  downloaded at runtime to a per-user cache on first use. The registry is the canonical
  list of URLs, licenses, and cache paths, so a fresh clone of this repo self-bootstraps.
