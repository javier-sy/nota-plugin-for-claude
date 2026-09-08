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

{{requires:knowledge-base}}

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

4. **Consult, one question per layer.** Not "search the knowledge base": several
   different questions, each aimed at the layer that can answer it. The tool
   descriptions carry the full contract; what matters here is that you ask each
   layer what it knows and relate the answers yourself.

   | when | layer | how to phrase it |
   |---|---|---|
   | before the modelling table | `docs` | **the shape of the problem**, never the verb you had in mind — *"a plan of sections each with a duration"*, not *"how do I use every"* |
   | after choosing an idiom | `api_reference` | the identifier, by name |
   | when assembling setup | `demo_code` | the wiring — *"TimerClock transport MIDIVoices"*. **Never** as evidence for a choice of form |
   | when writing material | `best_practice` | the technique in use |
   | only if the user's own work is involved | `private_works`, `analysis` | described musically |

   **What this step cannot do.** These tools confirm what you already chose:
   `api_reference` checks a name you had in mind, and a search returns what
   matches your framing. If the framing is wrong they will confirm the wrong
   thing. The step that corrects the framing is step 5 — and it corrects it by
   asking `docs` about the SHAPE of the problem, which is the one query whose
   answer you cannot predict.

   And a demo is never an argument. The demos simplify to isolate a concept, so
   their scaffolding is often not the idiomatic form. They show how something is
   wired; they never show that wiring it that way was right.

5. **Ask the question, in writing** — *what has to be done here, how would it be expressed most beautifully in MusaDSL?*

   This is a required artifact, not a mood. Three moves, in order:

   **a. Route.** `search` with `kind: "docs"`, phrased as the shape of the data
   and of the plan. You are asking which document discusses your problem, not
   for an answer: a snippet is two thousand characters chosen for resembling
   your query, and the boundary between two verbs is never inside it.

   **b. Read it whole.** `get_doc` the document the routing found. This is where
   the decision is actually made, because *when is `every` the answer and when is
   it a serie* lives in how the document relates its own parts. Read it now, at
   the gate — not from memory of having read it earlier, which after a long
   conversation is memory of something no longer in front of you.

   **c. Fill the table**, one row per layer or material of the piece:

   | layer | shape of the data | consuming verb | why not the neighbouring verb | source |
   |---|---|---|---|---|

   - **shape of the data** — serie? neumas? generator output (Markov, Variatio, Grammar, Darwin)? timed serie? matrix? a class of its own?
   - **consuming verb** — `play`, `play_timed`, `move`, `every`, `on` + `launch`, `at`
   - **source** — `document > section` of the text you just read whole, for the row it supports. A row with no citation has no argument behind it, and a row citing a `[demo_code]` result has the wrong kind of argument.
   - **two answers always require an explicit justification**: `at` with a computed position, and "a class of its own" (say why the framework does not already have it)

   `docs/idioms.md` is already in context, read from the installed gem: it is
   organised by symptom, so enter it from what you are about to write. Fill the
   table **from the shape of the problem**, never from the verb you already had
   in mind. The commonest failure is to model a plan as absolute positions, after
   which a loop of `at` is inevitable: **model plans as durations**.

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
   - The framework's own `docs/idioms.md` and `docs/vocabulary.md` are already in context, read from the installed gem — use them for form and for what exists, and the MCP tools for signatures and behaviour

8. **Run `lint` before showing the code. Every time, without exception.**

   Everything above this line is instruction, and instruction gets skipped: the
   gate can be waved through, the catalogue can sit unread in context, the source
   column can be left empty, and none of that raises. `lint` runs on the text, so
   it is the one step that does not depend on remembering.

   - **Certain** findings are facts. Fix them, then run it again.
   - **Worth arguing** findings are shapes that are usually the generalist reflex
     and sometimes exactly right. For each one: change it, **or** add one line to
     the proposal saying why this is the case where the reflex is correct. A
     bespoke class for a structure that must be *inspected* is a good answer; an
     unexamined one is not an answer at all.
   - A clean report means the text is clean. It says nothing about whether the
     form is right — that was step 5, and no regular expression can redo it.

9. **If creating a new composition**: generate the complete project structure:
   - `musa/main.rb` — entry point with transport, clock, scale, voices, transcriptor setup
   - `musa/score.rb` — composition code with scheduled events. **Its header must carry `include Musa::Series` and the `using` lines for every refinement it will need**, even before anything uses them: a vocabulary that is not in scope cannot be reached, and its absence produces no error because the reflex that avoids it also avoids the constructors that would raise.
   - `musa/Gemfile` — dependencies
   - `README.md` — project documentation (see below)
   - Follow the naming convention: `YYYY-MM-DD Project Name [musa bw]` (adjust tags)

10. **Ensure the composition ends properly** if it is not meant to run indefinitely:
   - The piece must have a clear termination point — e.g., after the last section finishes, stop the transport
   - Use `control.after { transport.stop }` or similar after the final play/event chain
   - If using event chaining (`on`/`launch`), the last section's `control.after` should trigger the stop
   - If the piece is designed to loop or run until manually stopped, document this explicitly in the README
   - **Never leave a finite composition without a termination mechanism** — the user should not have to Ctrl+C to end a piece that was supposed to finish

11. **Generate a README.md** for the project that includes:
   - Brief description of the piece and its musical intention
   - **Audio generator connection** — a dedicated section documenting:
     - Which DAW or synthesizer the piece targets (Bitwig, Ableton Live, SuperCollider, etc.)
     - **MIDI channel mapping** — which channel is used for what role (e.g., channel 0 = melody, channel 1 = bass, channel 9 = percussion)
     - **OSC mappings** if used — which addresses, what parameters
     - **Program changes** or instrument assignments if relevant
     - Any DAW-specific setup required (templates, controller scripts, MIDI routing)
   - How to run the piece
   - Any special requirements or notes

12. **Provide guidance on testing and common pitfalls**:
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

## Choosing the form

`docs/idioms.md` is in this context already, read from the installed
musa-dsl. It is the catalogue of forms, organised **by symptom** — each
entry names a reflex, the idiom that replaces it, what is gained, how the
reflex is detectable in text, and when the reflex is actually right.

Enter it from what you are about to write, not from a table here. A
condensed copy of it used to live in this file, and a condensed copy is an
edited copy: it drifted from the original, and once turned a false claim
into a rule with emphatic typography. The catalogue travels with the gem
the user has installed, so it cannot disagree with their framework.

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

Idiom failures are invisible to testing — the code runs, the piece sounds
right, and it is still not MusaDSL. The catalogue in `idioms.md` lists each
reflex together with how it is **detectable** in the text you are writing;
those detections are the guards. Match them against the token you are about
to type, not against a virtue you intend to have, and when one fires read
that entry's section whole before continuing.

One guard is not in the catalogue, because it is not an idiom failure but a
setup failure that conceals itself:

- **Before writing `S(`, `H(`, `FIBO(` or any constructor in a file** —
  check that the file has `include Musa::Series`. Its absence is
  self-concealing: the reflex avoids the constructors, so no `NameError`
  ever reveals it.

A bespoke Ruby class is sometimes the honest answer — a serie is a
consumable flow and cannot be asked for its period or its reachable states,
so a structure that must be *inspected* deserves a class. What is never
acceptable is that the choice was not argued against the framework.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "{{cmd:setup}}":

1. **Stop immediately** — do NOT write code without API verification.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `{{cmd:setup}}` which will guide them through the process.

## Important

- **Always propose before writing** — never dump a full composition without the user's agreement on the approach.
- **If the user wants to explore ideas** before coding, suggest `{{cmd:think}}` instead — it's designed for creative ideation.
- After the composition is ready, suggest `{{cmd:index}}` to index it and `{{cmd:analyze}}` to generate a musical analysis.
