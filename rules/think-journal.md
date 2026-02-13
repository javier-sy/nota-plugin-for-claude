# Think Journal — Persistent Creative Memory

## Rule

Whenever the conversation involves **creative thinking about a composition** — generating ideas, exploring musical directions, making aesthetic decisions, evaluating options, reflecting on the compositional process — you MUST persist the substance of that thinking to a `think-journal.md` file at the **root of the current musical project**.

This applies regardless of whether `/nota:think` was explicitly invoked. Any conversation that produces creative insights about a composition must be journaled.

## What to journal

- Ideas generated (explored and unexplored)
- Musical directions considered
- Aesthetic decisions and their reasoning
- Technical approaches discussed (which MusaDSL tools, why)
- Open questions and unresolved threads
- Ideas explicitly discarded and why
- Connections to other works, composers, or techniques

## What NOT to journal

- Implementation details (code belongs in code files)
- Debugging or technical troubleshooting
- General MusaDSL usage questions unrelated to a specific composition
- Setup, configuration, or tooling discussions

## File format

Maintain `think-journal.md` as a **living document**, not an append-only log. Structure it with these sections:

```markdown
# Think Journal — [Project Name]

## Active Threads
Ideas and directions currently being explored or worth returning to.

## Explored
Ideas that have been developed, implemented, or fully discussed.

## Decisions
Aesthetic and technical choices made, with reasoning.

## Discarded
Ideas considered and intentionally set aside, with reasoning.

## Open Questions
Unresolved questions worth revisiting.
```

## How to update

- **Add new ideas** to Active Threads when they emerge in conversation
- **Move ideas to Explored** when they've been developed or implemented via `/nota:code`
- **Move ideas to Discarded** when explicitly rejected, always noting why
- **Record decisions** when the user makes a choice between alternatives
- **Consolidate** — if an active thread evolves across multiple conversations, update it in place rather than appending duplicates
- **Preserve the user's language** — if the user thinks in Spanish, journal in Spanish

## Locating the project

The current musical project is the working directory or the directory the user is working in. The `think-journal.md` file goes at its root, alongside folders like `musa/`, `bw/`, `Live/`, etc.

If no specific project context is clear, ask the user which project the ideas relate to before writing.

## Important

- **Write to the file as part of your response** — don't wait for a "save" command. The act of thinking and the act of persisting are the same.
- **Read the file at the start of creative discussions** — if `think-journal.md` exists in the project, read it before generating new ideas so you don't repeat or contradict previous thinking.
- **The journal belongs to the user** — write in a way that's useful to re-read independently of the conversation. Complete sentences, enough context to understand each entry on its own.
