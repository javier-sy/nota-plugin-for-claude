---
name: explain
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
   - series, sequencer, neumas, datasets, music/scales/chords, generative (Markov, Variatio, GenerativeGrammar, Darwin), transcription, transport, matrix, midi, repl, musicxml

2. **Classify the question before touching anything.** What is being asked
   decides which layers can answer it, and in what order. Getting this wrong
   produces an answer that is fluent, sourced, and about something else.

   | the question is… | layers, in order |
   |---|---|
   | *when do I use X? X or Y?* | `docs` to route → `get_doc` the winner whole → `api_reference` to check each claim about behaviour |
   | *what does X do? what is the signature?* | `api_reference` → then `docs`, reframed as **the decision behind it**: explaining what something is without saying when it is the answer is half an explanation |
   | *how do I set X up?* | `demo_code` (+ `gem_readme`) |
   | *what do I have to install?* | `gem_readme` + `docs` |
   | *something about my own work* | `analysis` / `private_works` |

   Ask each relevant layer **separately**, in one `search` call with one entry
   per layer. There is no undifferentiated search: a question you cannot assign
   to a layer is a question you have not finished forming.

3. **Synthesize** — and the layers do not have equal standing:

   - **`docs` leads.** It is the only layer that says *when* something is the
     answer. If the question was a "when", the answer is built on it.
   - **`api` verifies.** Every claim about behaviour — what a method returns,
     what it does to state, what it raises — is checked against the contract or
     it is not made.
   - **`demo` illustrates.** It shows a working assembly. **It never establishes
     that a form is right**, and answering a "when" from a demo is the specific
     error this ordering exists to prevent.
   - `docs/idioms.md` and `docs/vocabulary.md` are in context already, read from
     the user's installed gem: the first for form, the second for what exists.

   A `docs` snippet routes; it does not settle anything. If the answer turns on
   a distinction between two verbs, read that document whole with `get_doc`
   first — the distinction lives in how the document relates its parts, not in
   the fragment that most resembled the question.

   End with a **sources block**, grouped by layer, naming `document > section`
   for what you leaned on. A reader can then check the part that matters to them,
   and a wrong citation is visible instead of merely being wrong.

4. **Verify** accuracy:
   - NEVER invent API methods. `api_reference` looks names up and **can say no**:
     when it reports that a name is not in the indexed API, that is information.
     Check rubydoc.info before telling the user a method does not exist, and never
     fill the gap with something plausible.
   - Series are LAZY: they use `.next_value`, NOT `.each`
   - Neuma durations are MULTIPLES of base_duration, not fractions
   - `using Musa::Extension::Neumas` is file-scoped (Ruby refinements)
   - **Source references**: Each MCP result includes a **Source** URL (GitHub, versioned
     source) and, for API chunks, a **Docs** URL (rubydoc.info, published documentation).
     When the retrieved content is not sufficient to answer accurately:
     1. Re-query the knowledge base first — try `api_reference`, or `search` with a
        different query or `kind: "docs"` / `kind: "api"`.
     2. If still insufficient, use `WebFetch` on the **Docs** URL (rubydoc.info) — it
        has signatures, descriptions, and examples in rendered form.
     3. Use `WebFetch` on the **Source** URL (GitHub) only to understand an
        implementation detail that the docs do not cover.
     — Do NOT read local file paths; the user may not have MusaDSL cloned locally.

## When MCP tools return setup errors

If MCP tool results mention "not configured", "API key", or "{{cmd:setup}}":

1. **Stop immediately** — do NOT try to search for or read local files as a fallback.
   The user may not have the MusaDSL source repositories on their machine.
2. **Tell the user** that the plugin needs to be configured first.
3. **Suggest** they run `{{cmd:setup}}` which will guide them through the process.
4. Do NOT attempt to answer the question from general knowledge — wait for the setup to be completed.

## When MCP tools are not available at all

If the knowledge base tools (search, api_reference, get_doc, list_docs, similar_works)
are not available in this session (not listed as tools, not just erroring):

1. **Inform the user** that the MusaDSL knowledge base is not accessible and your answers
   will be based on limited static reference material.
2. **Use only** `docs/idioms.md` and `docs/vocabulary.md` — in context from the installed gem — and say plainly that signatures could not be verified.
3. **Never invent** API methods or signatures — if you cannot confirm via the knowledge base,
   explicitly state that.

## Beyond Explanation

- If the user wants to **implement** what they've learned — write code, create a piece, add a voice — suggest `{{cmd:code}}`.
- If the user wants to **explore ideas** — brainstorm, get inspired, think about what to compose — suggest `{{cmd:think}}`.

## Common Pitfalls to Warn About

- Series have NO `.each` method — use `.next_value` or `play` in sequencer
- Must call `.i` on a serie before iterating (instantiation)
- `H()` expects keyword arguments with series as values (prototypes)
- Ornaments require a Transcriptor — without one they're silently ignored
- `using` refinements are file-scoped — must declare in each file
- Durations in neumas are multiples: `1` = base_duration, `2` = 2x base_duration
- Use `Rational` for timing (`1/4r`, `1r`) — avoid Float imprecision
