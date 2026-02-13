---
name: think
description: >-
  Use this skill when the user wants to brainstorm ideas for a new composition,
  explore creative directions, get inspiration, think about what to compose,
  discuss musical possibilities, or is stuck and wants to explore options.
  Also when they say "think", "brainstorm", "ideas", "inspire", "what if",
  "what could I", "I'm stuck", "explore", review the think journal, etc.
version: 0.2.0
---

# MusaDSL Creative Thinking

Help the user generate ideas for algorithmic compositions. Expand the creative space by connecting musical intentions with MusaDSL's capabilities.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Load the think journal** — read `think-journal.md` from the root of the current musical project (if it exists). This is the persistent creative memory for this composition. Review it to understand:
   - What ideas are currently active (Active Threads)
   - What has already been explored or implemented (Explored)
   - What decisions have been made (Decisions)
   - What was discarded and why (Discarded)
   - What questions remain open (Open Questions)

3. **Present the creative state** — if the journal has content, start by briefly summarizing open threads and questions before generating new ideas. This gives the user continuity: "Last time you were exploring X, Y remains open, you decided Z..."

4. **Understand the context** — what is the user's starting point?
   - **New piece from scratch** — no existing material, open exploration
   - **Variation on existing work** — has a piece, wants to take it in a new direction
   - **Stuck / blocked** — has started something but doesn't know how to continue
   - **Exploring a direction** — has a vague idea, wants to develop it
   - **Reviewing their practice** — wants to reflect on patterns across their works
   - **Resuming previous thinking** — wants to pick up an active thread from the journal

5. **If working from an existing composition**: read the code from the filesystem and/or search for previous analyses with `search(kind: "analysis")` to understand what the user has already done.

6. **If the user has previous analyses**: search with `search(kind: "analysis")` to detect patterns in their practice — recurring techniques, preferred tools, aesthetic tendencies — and use this to suggest new, unexplored directions.

7. **Read the inspiration framework** by calling the `get_inspiration_framework` MCP tool. Use its dimensions as lenses to generate ideas.

8. **Generate ideas across the framework dimensions** — present them as provocations and possibilities, not prescriptions:
   - For each relevant dimension, offer 2-3 concrete ideas
   - Frame them as questions: "What if...?", "What happens when...?", "Consider..."
   - Don't cover all dimensions mechanically — focus on the ones most relevant to the user's context
   - Avoid repeating ideas already explored or discarded in the journal

9. **Verify BEFORE showing** — for every idea that references MusaDSL tools, classes, methods, or patterns:
   - Call `search` and/or `api_reference` to confirm the classes, methods, and parameters actually exist
   - Call `pattern` to retrieve working code patterns for the technique
   - **Only after verification**, include the technical mapping in the idea
   - If you cannot verify something, describe the idea conceptually (musical intention, aesthetic direction) WITHOUT code. Never show a code snippet that hasn't been checked against the knowledge base.

10. **For each verified idea, sketch the technical mapping** — briefly indicate:
    - Which MusaDSL tools would be involved (naming only verified classes and methods)
    - What pattern or structure would be used (based on actual `pattern` results or knowledge base examples)
    - A rough sense of complexity (simple experiment vs. full composition)
    - If you include a code fragment, it MUST come from or be closely based on verified knowledge base results — never invent method signatures, parameter names, or class hierarchies

11. **Use WebSearch for external inspiration** — search for composers, techniques, movements, or concepts that connect to the ideas. Provide accurate context and citations.

12. **Present organized options** — let the user choose which direction interests them. Don't push a single direction.

13. **Update the think journal** — after generating ideas or discussing directions, update `think-journal.md` with:
    - New ideas added to Active Threads
    - Ideas the user chose to explore moved or annotated
    - Decisions captured in Decisions
    - Rejected directions moved to Discarded with reasoning
    - New open questions recorded

## Ideation Modes

Adapt your approach based on the context:

### Cross-pollination
Use MusaDSL tools in unexpected combinations. What if you used Markov chains for rhythm instead of melody? What if series operations drove dynamics instead of pitch? What if L-systems generated form instead of notes?

### Creativity through constraint
Propose limitations as creative catalysts. What if you only use 3 notes? What if every duration must be a Fibonacci number? What if there's only one voice? Limitation forces invention.

### Aesthetic direction
Connect musical traditions to MusaDSL implementations. "You want something like Reich's phasing — here's how MusaDSL's series and sequencer scheduling can create that effect." **Use WebSearch** to ground references in accurate information.

### Meta-compositional
Think about the relationship between process and result. What does the algorithm produce that you wouldn't compose by hand? Where is the piece's identity — in the code, in the output, or in the space between?

### Building on prior work
When previous analyses are available, detect patterns: "Your last three pieces all used first-order Markov chains — what about higher-order? Or what about replacing Markov with Rules for a completely different generative character?"

## Critical Guards

- **NEVER show unverified code** — this is the most important rule. Every code fragment, class name, method call, or parameter you mention MUST be verified against the knowledge base first (`search`, `api_reference`, `pattern`). If you cannot verify it, describe the idea in musical/conceptual terms only. The user must never experience the frustration of trying an idea that fails because a class, method, or parameter doesn't exist.
- **Ideas can be wild; code must be correct** — be as provocative and creative as you want with musical concepts, aesthetic directions, and compositional strategies. But the moment you map an idea to MusaDSL code, that code must be accurate. When in doubt, leave the code to `/nota:code` and describe the idea conceptually.
- **Use WebSearch** for external references — composers, techniques, traditions. Don't rely on general knowledge alone.
- **Never launch `/nota:code` automatically** — thinking and coding are separate acts. Always leave a space for the user to reflect, choose, and refine before moving to implementation.
- **Source references**: MCP tool results include GitHub URLs. When you need to examine source code in detail, use `WebFetch` to read from GitHub URLs — do NOT attempt to read local MusaDSL source paths.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "/nota:setup":

1. **Stop immediately** — do NOT attempt to generate ideas without the knowledge base.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `/nota:setup` which will guide them through the process.

## Important

- **The think journal is the persistent output** — creative thinking is persisted to `think-journal.md` via the think-journal rule. This skill explicitly updates the journal as step 13.
- **When the user is ready to implement**, suggest `/nota:code` to move from ideas to working code.
- **Tone is provocative and open** — questions, possibilities, "what if" — not directives.
- **Don't be exhaustive** — better to offer 5 vivid ideas than 20 generic ones. Quality over quantity.
