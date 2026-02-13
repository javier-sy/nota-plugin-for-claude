---
name: code
description: >-
  Use this skill when the user wants to create a new MusaDSL composition,
  modify an existing one, add voices or sections, fix bugs in their code,
  refactor composition code, or translate a musical intention into working
  MusaDSL Ruby code. Also when they say "code", "program", "write",
  "implement", "create a piece", "add a voice", "fix this", etc.
version: 0.1.0
---

# MusaDSL Composition Coding

Help the user program and modify algorithmic compositions using MusaDSL and Ruby. Translate musical intentions into working code.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Understand the intention** — what does the user want?
   - **New composition from scratch** — create a complete project structure
   - **Modify existing composition** — add/change/remove elements in an existing piece
   - **Add a voice/section** — extend a composition with new material
   - **Debug** — find and fix problems in composition code
   - **Refactor** — restructure code without changing musical behavior
   - **Translate musical idea** — turn a description ("more intense", "chaotic", "like Reich") into code

3. **If working with an existing composition**: read the code from the filesystem to understand it fully before making changes.

4. **Research using MCP tools** — verify everything against the knowledge base:
   - `search` — find relevant documentation, patterns, and examples
   - `api_reference` — verify exact method signatures and parameters before using them
   - `pattern` — get working code patterns for specific techniques
   - `dependencies` — what setup is needed for a concept
   - `similar_works` — find similar compositions for reference and inspiration

5. **Propose the approach before writing code** — explain:
   - Which MusaDSL components you'll use and why
   - The overall structure (sections, voices, events)
   - Setup requirements (clock, transport, scale, voices, transcriptor)
   - Let the user confirm or redirect before you write

6. **Write the code**:
   - Verify every API method against the knowledge base before using it — **never invent methods**
   - Follow the project structure conventions (see below)
   - Include comments where the logic maps musical concepts to code
   - Use the static reference in `rules/musadsl-reference.md` and MCP tools together for accuracy

7. **If creating a new composition**: generate the complete project structure:
   - `musa/main.rb` — entry point with transport, clock, scale, voices, transcriptor setup
   - `musa/score.rb` — composition code with scheduled events
   - `musa/Gemfile` — dependencies
   - `README.md` — project documentation (see below)
   - Follow the naming convention: `YYYY-MM-DD Project Name [musa bw]` (adjust tags)

8. **Ensure the composition ends properly** if it is not meant to run indefinitely:
   - The piece must have a clear termination point — e.g., after the last section finishes, stop the transport
   - Use `control.after { transport.stop }` or similar after the final play/event chain
   - If using event chaining (`on`/`launch`), the last section's `control.after` should trigger the stop
   - If the piece is designed to loop or run until manually stopped, document this explicitly in the README
   - **Never leave a finite composition without a termination mechanism** — the user should not have to Ctrl+C to end a piece that was supposed to finish

9. **Generate a README.md** for the project that includes:
   - Brief description of the piece and its musical intention
   - **Audio generator connection** — a dedicated section documenting:
     - Which DAW or synthesizer the piece targets (Bitwig, Ableton Live, SuperCollider, etc.)
     - **MIDI channel mapping** — which channel is used for what role (e.g., channel 0 = melody, channel 1 = bass, channel 9 = percussion)
     - **OSC mappings** if used — which addresses, what parameters
     - **Program changes** or instrument assignments if relevant
     - Any DAW-specific setup required (templates, controller scripts, MIDI routing)
   - How to run the piece
   - Any special requirements or notes

10. **Provide guidance on testing and common pitfalls**:
    - How to run and test the piece
    - Warn about common runtime issues
    - Suggest `/nota:index` to index the work and `/nota:analyze` to generate a musical analysis when ready

## Musical-to-Technical Translation

When the user describes their intention musically, translate it:

| Musical intention | Technical approach |
|---|---|
| "more intense" | Higher velocities, increase density, add voices, tighter rhythms |
| "more chaotic" | Wider Markov ranges, more stochastic elements, less repetition |
| "calmer" | Lower velocities, sparser texture, longer durations, fewer voices |
| "like a canon" | Delayed voice entries with same/transformed material |
| "more organic" | Higher-order Markov, subtle variation, Variatio |
| "mechanical" | Strict repetition, quantized rhythms, deterministic series |
| "building up" | Gradual accumulation: voices entering, density increasing, register expanding |
| "dissolving" | Voices dropping out, longer durations, dynamics fading, register narrowing |
| "unpredictable" | Random elements, uniform Markov distributions, wide parameter ranges |
| "rhythmically complex" | Polyrhythms, irregular meters, tuplets, overlapping cycles |

## Critical Guards

- **NEVER invent API methods** — if you can't find a method in the knowledge base, say so. Use `api_reference` to verify.
- **Ruby block syntax** — MusaDSL methods like `at`, `every`, `wait`, `play` take blocks. The syntax is `at(1) { ... }` or `at 1 do ... end`. **NEVER** write `at 1 { ... }` — this is a Ruby syntax error because curly-brace blocks bind to the last argument, not the method. When using parentheses-free syntax, always use `do...end`. When using curly braces, always use parentheses: `at(1) { ... }`.
- **Series are lazy iterators** — they use `.next_value` for manual iteration, NOT `.each`. For playback, use `play serie, decoder: decoder, mode: :neumalang`.
- **Neuma durations are multiples of base_duration** — `1` = one base_duration, `2` = two base_durations. They are NOT fractions like `/4`.
- **Refinements are file-scoped** — `using Musa::Extension::Neumas` must be declared in EACH file that uses `.to_neumas`.
- **Ornaments require a Transcriptor** — without one, ornaments (`tr`, `mor`, `st`, `turn`) are silently ignored.
- **Use Rational for timing** — `1/4r`, `1r`, `3/4r`. Never use Float for timing values.
- **Compositions must end** — if the piece is finite, ensure the transport stops after the last event. Never leave a finite piece without a termination mechanism.
- **Source references**: MCP tool results include GitHub URLs pointing to exact versioned source files. When you need to examine source code in detail, use `WebFetch` to read it from the GitHub URL — do NOT attempt to read local MusaDSL source paths (the user may not have them cloned).
- **Respect existing project conventions** — if modifying an existing piece, follow its style and patterns.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "/nota:setup":

1. **Stop immediately** — do NOT write code without API verification.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `/nota:setup` which will guide them through the process.

## Important

- **Always propose before writing** — never dump a full composition without the user's agreement on the approach.
- **If the user wants to explore ideas** before coding, suggest `/nota:think` instead — it's designed for creative ideation.
- After the composition is ready, suggest `/nota:index` to index it and `/nota:analyze` to generate a musical analysis.
