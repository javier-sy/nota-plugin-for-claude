---
name: musa-explain
description: >-
  This skill should be used when the user asks about MusaDSL,
  "explain series", "how does sequencer work", "show me neumas syntax",
  "explain Markov chains in MusaDSL", "how to use generative tools",
  "what are datasets", "how to set up live coding",
  discusses algorithmic composition with MusaDSL,
  asks about musa-dsl API, or mentions any MusaDSL subsystem
  (series, sequencer, neumas, datasets, music, generative,
  transcription, transport, matrix).
version: 0.1.0
---

# MusaDSL Explain Skill

You are explaining MusaDSL concepts to a user who is composing algorithmic music with Ruby.

## Process

1. **Identify** which MusaDSL subsystem(s) are relevant to the question:
   - series, sequencer, neumas, datasets, music/scales/chords, generative (Markov, Variatio, Rules, GenerativeGrammar, Darwin), transcription, transport, matrix, midi, repl, musicxml

2. **Retrieve** accurate information using MCP tools:
   - `search` — semantic search across docs, API, demos, private works, and composition analyses (use kind `"all"` for broadest results, or `"private_works"`/`"analysis"` for specific kinds)
   - `api_reference` — exact API reference for a module/method
   - `pattern` — code pattern for a specific technique
   - `dependencies` — what setup is needed for a concept
   - `similar_works` — find similar example works/demos (also searches the user's private works and composition analyses if available)

3. **Synthesize** your answer:
   - Combine retrieved context with the static reference in `rules/musadsl-reference.md`
   - Prioritize information from the knowledge base over general knowledge
   - Include working Ruby code examples
   - Mention relevant demos (demo-00 through demo-22) when applicable

4. **Verify** accuracy:
   - NEVER invent API methods — only use what's found in the knowledge base
   - If unsure about a method signature, use `api_reference` to confirm
   - Series are LAZY: they use `.next_value`, NOT `.each`
   - Neuma durations are MULTIPLES of base_duration, not fractions
   - `using Musa::Extension::Neumas` is file-scoped (Ruby refinements)
   - **Source references**: MCP tool results include GitHub URLs pointing to the exact
     versioned source files. When you need to examine a source file in detail, use
     `WebFetch` to read it from the GitHub URL — do NOT attempt to read local file paths.
     The user may not have the MusaDSL source repositories cloned locally.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "/setup":

1. **Stop immediately** — do NOT try to search for or read local files as a fallback.
   The user may not have the MusaDSL source repositories on their machine.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `/setup` which will guide them through the process.
4. Do NOT attempt to answer the question from general knowledge — wait for the setup to be completed.

## When MCP tools are not available at all

If the knowledge base tools (search, api_reference, pattern, dependencies, similar_works)
are not available in this session (not listed as tools, not just erroring):

1. **Inform the user** that the MusaDSL knowledge base is not accessible and your answers
   will be based on limited static reference material.
2. **Use only** the static reference in `rules/musadsl-reference.md` for your answers.
3. **Never invent** API methods or signatures — if you cannot confirm via the knowledge base,
   explicitly state that.

## Beyond Explanation

- If the user wants to **implement** what they've learned — write code, create a piece, add a voice — suggest `/code`.
- If the user wants to **explore ideas** — brainstorm, get inspired, think about what to compose — suggest `/think`.

## Common Pitfalls to Warn About

- Series have NO `.each` method — use `.next_value` or `play` in sequencer
- Must call `.i` on a serie before iterating (instantiation)
- `H()` expects keyword arguments with series as values (prototypes)
- Ornaments require a Transcriptor — without one they're silently ignored
- `using` refinements are file-scoped — must declare in each file
- Durations in neumas are multiples: `1` = base_duration, `2` = 2x base_duration
- Use `Rational` for timing (`1/4r`, `1r`) — avoid Float imprecision
