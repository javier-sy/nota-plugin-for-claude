---
name: musa-think
description: >-
  Use this skill when the user wants to brainstorm ideas for a new composition,
  explore creative directions, get inspiration, think about what to compose,
  discuss musical possibilities, or is stuck and wants to explore options.
  Also when they say "think", "brainstorm", "ideas", "inspire", "what if",
  "what could I", "I'm stuck", "explore", etc.
version: 0.1.0
---

# MusaDSL Creative Thinking

Help the user generate ideas for algorithmic compositions. Expand the creative space by connecting musical intentions with MusaDSL's capabilities.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Understand the context** — what is the user's starting point?
   - **New piece from scratch** — no existing material, open exploration
   - **Variation on existing work** — has a piece, wants to take it in a new direction
   - **Stuck / blocked** — has started something but doesn't know how to continue
   - **Exploring a direction** — has a vague idea, wants to develop it
   - **Reviewing their practice** — wants to reflect on patterns across their works

3. **If working from an existing composition**: read the code from the filesystem and/or search for previous analyses with `search(kind: "analysis")` to understand what the user has already done.

4. **If the user has previous analyses**: search with `search(kind: "analysis")` to detect patterns in their practice — recurring techniques, preferred tools, aesthetic tendencies — and use this to suggest new, unexplored directions.

5. **Read the inspiration framework** by calling the `get_inspiration_framework` MCP tool. Use its dimensions as lenses to generate ideas.

6. **Generate ideas across the framework dimensions** — present them as provocations and possibilities, not prescriptions:
   - For each relevant dimension, offer 2-3 concrete ideas
   - Frame them as questions: "What if...?", "What happens when...?", "Consider..."
   - Connect abstract ideas to concrete MusaDSL implementations — what tools, what patterns, what code structure
   - Don't cover all dimensions mechanically — focus on the ones most relevant to the user's context

7. **For each idea, sketch the technical mapping** — briefly indicate:
   - Which MusaDSL tools would be involved (Markov, Series, Rules, etc.)
   - What pattern or structure would be used
   - A rough sense of complexity (simple experiment vs. full composition)

8. **Use WebSearch for external inspiration** — search for composers, techniques, movements, or concepts that connect to the ideas. Provide accurate context and citations.

9. **Verify technical viability** — use `search` and `api_reference` to confirm that suggested approaches are actually possible in MusaDSL. Never suggest something that can't be implemented.

10. **Present organized options** — let the user choose which direction interests them. Don't push a single direction.

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

- **Ideas must be grounded in MusaDSL** — never suggest something that can't be implemented with the available tools. Verify with `search`/`api_reference` when unsure.
- **Use WebSearch** for external references — composers, techniques, traditions. Don't rely on general knowledge alone.
- **Never launch `/code` automatically** — thinking and coding are separate acts. Always leave a space for the user to reflect, choose, and refine before moving to implementation.
- **Verify technical viability** — if you suggest using a specific tool or pattern, confirm it exists in MusaDSL.
- **Source references**: MCP tool results include GitHub URLs. When you need to examine source code in detail, use `WebFetch` to read from GitHub URLs — do NOT attempt to read local MusaDSL source paths.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "/setup":

1. **Stop immediately** — do NOT attempt to generate ideas without the knowledge base.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `/setup` which will guide them through the process.

## Important

- **Output is ephemeral** — this skill does not persist anything. The user takes what they want from the conversation.
- **When the user is ready to implement**, suggest `/code` to move from ideas to working code.
- **Tone is provocative and open** — questions, possibilities, "what if" — not directives.
- **Don't be exhaustive** — better to offer 5 vivid ideas than 20 generic ones. Quality over quantity.
