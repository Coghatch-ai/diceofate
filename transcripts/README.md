# transcripts/ — raw transcript drop zone

Drop a raw video transcript here (one `.md` file per video) when you're about to build
in a domain it covers. The web UI can also create a file in this folder.

This folder is the **drop zone** — at rest it holds only transcripts still waiting to be
harvested:

1. You (or the UI) drop `something.md` here.
2. The orchestrator spawns the **transcript-researcher** agent on it.
3. The agent distills + verifies the video, writes a durable one-page digest to
   `library/transcripts/something.md`, then **moves the raw into `transcripts/archive/`**.
4. `transcripts/archive/` is the kept full-text backup — the source we can always go
   back to. It is never auto-deleted; if you later decide an archived raw isn't worth
   keeping, moving it to a trash/disposal step is a separate, manual call.

So two things are kept per video: the distilled **digest** in `library/transcripts/`
(the warm-knowledge record) and the **archived raw** here (the full source). See
`.claude/agents/transcript-researcher.md` for the full workflow.
