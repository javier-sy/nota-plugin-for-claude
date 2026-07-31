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
   - `search` with `kind: "best_practice"` — find relevant best practices for the techniques being used
   - `get_best_practices_index` — read the user's condensed best practices index to check for applicable patterns
   - `api_reference` — verify exact method signatures and parameters before using them
   - `pattern` — get working code patterns for specific techniques
   - `dependencies` — what setup is needed for a concept
   - `similar_works` — find similar compositions for reference and inspiration

   **Beware of what this step can and cannot do.** These tools verify what you already chose: `api_reference` confirms the signature of a method you had in mind, `search` returns what matches your framing. If your framing is wrong, they will confirm the wrong thing — and the demos in the knowledge base include simplified scaffolding that is not always the idiomatic form. Never take a demo as a model of good form without asking whether it was simplifying to isolate a concept. The step that corrects the framing is step 5, not this one.

5. **Ask the question, in writing** — *what has to be done here, how would it be expressed most beautifully in MusaDSL?*

   This is a required artifact, not a mood. Before proposing anything, produce a **modelling table** with one row per layer or material of the piece:

   | layer | shape of the data | consuming verb | why not the neighbouring verb |
   |---|---|---|---|

   - **shape of the data** — serie? neumas? generator output (Markov, Variatio, Rules, Grammar, Darwin)? timed serie? matrix? a class of its own?
   - **consuming verb** — `play`, `play_timed`, `move`, `every`, `on` + `launch`, `at`
   - **two answers always require an explicit justification in the last column**: `at` with a computed position, and "a class of its own" (say why the framework does not already have it)

   Read `docs/idioms.md` in musa-dsl (or `search "idioms choosing the MusaDSL form" kind: "docs"`) and fill the table **from the shape of the problem**, not from the verb you already had in mind. The commonest failure is to model a plan as absolute positions, after which a loop of `at` is inevitable: **model plans as durations**.

6. **Propose the approach** — on top of the table, explain:
   - The overall structure (sections, voices, events)
   - Setup requirements (clock, transport, scale, voices, transcriptor)
   - **MusaDSL resources the user did not ask for and that fit** — one to three, each with a single line of justification. Look at the subsystems the plan does *not* use (generative tools, neumas, transcription, matrix, `Datasets::Score`, timed series) and say honestly whether any of them expresses what the user described better than what they asked for. This is where the assistant stops being a transcriber of requests and starts being a musician who knows the instrument.
   - Let the user confirm or redirect before you write

7. **Write the code**:
   - Verify every API method against the knowledge base before using it — **never invent methods**
   - Apply relevant best practices found in the search — both general (from knowledge.db) and user-specific (from private.db)
   - Follow the project structure conventions (see below)
   - Include comments where the logic maps musical concepts to code
   - Use the static reference in `rules/musadsl-reference.md`, `rules/best-practices.md`, and MCP tools together for accuracy

8. **If creating a new composition**: generate the complete project structure:
   - `musa/main.rb` — entry point with transport, clock, scale, voices, transcriptor setup
   - `musa/score.rb` — composition code with scheduled events. **Its header must carry `include Musa::Series` and the `using` lines for every refinement it will need**, even before anything uses them: a vocabulary that is not in scope cannot be reached, and its absence produces no error because the reflex that avoids it also avoids the constructors that would raise.
   - `musa/Gemfile` — dependencies
   - `README.md` — project documentation (see below)
   - Follow the naming convention: `YYYY-MM-DD Project Name [musa bw]` (adjust tags)

9. **Ensure the composition ends properly** if it is not meant to run indefinitely:
   - The piece must have a clear termination point — e.g., after the last section finishes, stop the transport
   - Use `control.after { transport.stop }` or similar after the final play/event chain
   - If using event chaining (`on`/`launch`), the last section's `control.after` should trigger the stop
   - If the piece is designed to loop or run until manually stopped, document this explicitly in the README
   - **Never leave a finite composition without a termination mechanism** — the user should not have to Ctrl+C to end a piece that was supposed to finish

10. **Generate a README.md** for the project that includes:
   - Brief description of the piece and its musical intention
   - **Audio generator connection** — a dedicated section documenting:
     - Which DAW or synthesizer the piece targets (Bitwig, Ableton Live, SuperCollider, etc.)
     - **MIDI channel mapping** — which channel is used for what role (e.g., channel 0 = melody, channel 1 = bass, channel 9 = percussion)
     - **OSC mappings** if used — which addresses, what parameters
     - **Program changes** or instrument assignments if relevant
     - Any DAW-specific setup required (templates, controller scripts, MIDI routing)
   - How to run the piece
   - Any special requirements or notes

11. **Provide guidance on testing and common pitfalls**:
    - How to run and test the piece
    - Warn about common runtime issues
    - Suggest `{{cmd:index}}` to index the work and `{{cmd:analyze}}` to generate a musical analysis when ready

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

## Shape-to-Idiom Translation

The table above maps *adjectives*. This one maps **shapes** — and shape is what you can see at the moment you are about to choose wrongly. Full catalogue with rationale and anti-patterns in `docs/idioms.md` (musa-dsl).

| Shape of the problem | Idiom |
|---|---|
| Events that follow one another in time | Serie carrying `duration:` + `play` |
| Several layers of events at their own times | AbsTimed series + `TIMED_UNION` + `play_timed` |
| A parameter that changes continuously | `move from:, to:, duration:, every:, function:` |
| Something that recurs at a fixed interval | `every` |
| Sections that follow one another | `on` / `launch` + `control.after` |
| A sequence of any values | `S`, `FOR`, `SIN`, `FIBO`, `HARMO`, `RND`, `E` |
| Parallel parameters forming one event | `H` (ends with the shortest) / `HC` (cycles to the longest) |
| The same material for several voices | `.buffered` + `.buffer.i` per voice |
| A recurrence with state | `FIBO()`, or `E` with `caller.parameters` |
| A choice with probabilities and memory | Markov (which is itself a serie) |
| A constrained random sequence | `RND(random:)` + `.remove { |v, history| }` |
| An exhaustive parameter space | Variatio |
| A structure that grows by rules | Rules (L-system), GenerativeGrammar |
| Selection by fitness among candidates | Darwin |
| Pitch, interval, chord, key | `scale[]`, `chord_on`, `.with_quality`, `.at_octave` |
| Material that reads as a score | neumas / `.neu` files |
| Ornament, articulation | Transcriptor + transcription set |
| A trajectory drawn in several dimensions | `Matrix#to_p` → `to_timed_serie` → `play_timed` |
| A piece to query or export | `Datasets::Score`, MusicXML builder |
| Time without a real clock (render, tests) | `DummyClock`, `ExternalTickClock`, tickless mode |

## Critical Guards

These prevent code that FAILS. The guards in the next section prevent something the tests cannot see: code that works while being foreign to the framework.

- **NEVER invent API methods** — if unsure, use `api_reference` to verify, then escalate to the **Docs** URL (rubydoc.info) before concluding a method doesn't exist. Only tell the user a method isn't available after both KB and rubydoc confirm its absence.
- **Ruby block syntax** — MusaDSL methods like `at`, `every`, `wait`, `play` take blocks. The syntax is `at(1) { ... }` or `at 1 do ... end`. **NEVER** write `at 1 { ... }` — this is a Ruby syntax error because curly-brace blocks bind to the last argument, not the method. When using parentheses-free syntax, always use `do...end`. When using curly braces, always use parentheses: `at(1) { ... }`.
- **Series are lazy iterators** — they use `.next_value` for manual iteration, NOT `.each`. For playback, use `play serie, decoder: decoder, mode: :neumalang`.
- **Neuma durations are multiples of base_duration** — `1` = one base_duration, `2` = two base_durations. They are NOT fractions like `/4`.
- **Refinements are file-scoped** — `using Musa::Extension::Neumas` must be declared in EACH file that uses `.to_neumas`.
- **Ornaments require a Transcriptor** — without one, ornaments (`tr`, `mor`, `st`, `turn`) are silently ignored.
- **Use Rational for timing** — `1/4r`, `1r`, `3/4r`. Never use Float for timing values.
- **Compositions must end** — if the piece is finite, ensure the transport stops after the last event. Never leave a finite piece without a termination mechanism.
- **Source references**: Each MCP result includes a **Source** URL (GitHub, versioned source) and, for API chunks, a **Docs** URL (rubydoc.info, published documentation). When the result content is insufficient to verify a method: (1) re-query the knowledge base with `api_reference` or `search` with different terms; (2) if still insufficient, use `WebFetch` on the **Docs** URL (rubydoc.info); (3) only use `WebFetch` on the **Source** URL (GitHub) to understand an implementation detail not covered by the docs. Do NOT read local MusaDSL paths — the user may not have them cloned.
- **Respect existing project conventions** — if modifying an existing piece, follow its style and patterns.

## Idiom Guards

Idiom failures are invisible to testing — the code runs, the piece sounds right, and it is still not MusaDSL. These guards therefore match **the token being written**, not a virtue. When one fires, stop and consult `docs/idioms.md` (or `search "idioms choosing the MusaDSL form" kind: "docs"`) before continuing.

- **`at` inside a loop, or `at` whose position contains a loop variable** — STOP. A sequence of events in time is a Serie carrying `duration:` consumed by `play`. Reserve `at` for genuine one-off landmarks. If you are holding absolute positions you already took the wrong turn upstream: **model plans as durations, not as positions.**
- **`a, b = b, a + b`, or any hand-written recurrence** — `FIBO()` exists; `E(*seeds) { |last_value:, caller:| ... }` exists for seeded or custom recurrences, carrying state in `caller.parameters`.
- **Arithmetic on MIDI note numbers** (`pitch + 7`, `% 12`, tables of semitones) — use `scale[grade]`, `note.at_octave`, `.sharp`/`.flat`, `chord_on`, `chord.with_quality`/`.with_move`. Integer pitches weld the piece to one tuning and one tonic.
- **`60.0 / bpm`, `* beat` or integer velocities appearing in the MATERIAL** — the musical layer stays GDV (grade, duration as multiples of `base_duration`, velocity as a dynamic mark); convert with `to_pdv(scale)` and to seconds only in the block that finally emits sound.
- **`rand` not derived from a seeded `Random`, or a ladder of `if p < 0.3`** — `RND(values, random:)` with `.remove { |value, history| ... }` for constraints, Markov when the tendency has memory. Note `Markov` **is a serie** and can feed `play` directly.
- **`product` / `permutation` / nested loops filling a candidate array** — that is Variatio, GenerativeGrammar, Rules or Darwin. Pruning during growth beats generate-then-filter.
- **`every` whose body nudges a variable towards a target** — that is `move from:, to:, duration:, every:, function:`.
- **`sort_by` on a time field followed by index traversal** — that is `TIMED_UNION` and `play_timed`.
- **Position constants defined by adding to other position constants** — macro form is `on`/`launch` with `control.after`, not arithmetic. Only events can distinguish *finishing* from *being stopped*.
- **Before writing `S(`, `H(`, `FIBO(` or any constructor in a file** — check that the file has `include Musa::Series`. Its absence is self-concealing: the reflex avoids the constructors, so no `NameError` ever reveals it.

A bespoke Ruby class is sometimes the honest answer — a serie is a consumable flow and cannot be asked for its period or its reachable states, so a structure that must be *inspected* deserves a class. What is never acceptable is that the choice was not argued against the framework.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "{{cmd:setup}}":

1. **Stop immediately** — do NOT write code without API verification.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `{{cmd:setup}}` which will guide them through the process.

## Important

- **Always propose before writing** — never dump a full composition without the user's agreement on the approach.
- **If the user wants to explore ideas** before coding, suggest `{{cmd:think}}` instead — it's designed for creative ideation.
- After the composition is ready, suggest `{{cmd:index}}` to index it and `{{cmd:analyze}}` to generate a musical analysis.
