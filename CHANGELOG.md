# Changelog

## 1.0.0 — 2026-08-05

**Nota stops carrying MusaDSL's knowledge and starts asking the framework for it.**

That is the whole of this release, and it is why the version has a 1 in front:
the architecture stopped moving. Everything else here follows from it.

### The principle

**musa-dsl owns the knowledge; Nota decides its distribution.** Knowledge in
prose lives where it can be falsified — musa-dsl has a suite, a doctest that
executes every claim its documentation makes, and a CI. A copy of that knowledge
here was outside all three, and every copy that ever lived here drifted from the
original. One of them turned a false claim into a rule with emphatic typography.

The guardrail in the other direction, so the framework does not end up carrying
prose whose only reader is a plugin: **a document moves into musa-dsl only if,
were Nota deleted tomorrow, it would still deserve to exist.**

### Gone from the plugin

- `rules/musadsl-reference.md` (35 KB of hand-maintained API reference)
- `rules/musadsl-philosophy.md`
- `rules/best-practices.md`
- `prompts/regenerate-*.md` — prompts that asked a model to re-read the sources
  and rewrite a summary. Their existence was the symptom: transcription made
  into a process.
- 19 of the 23 shipped "best practices". They described musa-dsl rather than a
  way of composing with it, and moved into musa-dsl's own documentation — the
  craft of laying out a project into `docs/guides/project-structure.md`, the
  plain facts into the subsystem guides. The four that remain are techniques,
  not framework facts.

**Always-in-context went from 47.7 KB copied to ~17 KB read from the gem.**

### New

- **Reads `docs/idioms.md` and `docs/vocabulary.md` from the installed
  musa-dsl** at session start, in both harnesses. No copy, no version floor: it
  asks whether the documents are where it expects them and says what it found,
  including which version. A gem that has one and not the other serves the one it
  has and names the other.
- **`get_doc` and `list_docs`** — read a whole document out of the installed gem.
  A `docs` snippet routes; the document decides. The boundary between two verbs
  lives in how a document relates its parts, not in the 2000 characters that most
  resembled a query.
- **`lint`** — reads composition code and reports what a reader can see. No API
  key, no database, no network, so it works when everything else is unreachable.
  Two lists kept apart: facts about the text, and shapes that are usually the
  generalist reflex and occasionally right. **The lint points; the agent judges.**
  It is the only step in the circuit that does not depend on remembering.
- **`spec/`** — the plugin has its own examples for the first time. Each one
  corresponds to something that went wrong and was found by hand.
- **`tools/retrieval-battery.rb`** — 32 questions asked by intention, each with
  the document that should answer it. Runs in CI and fails on regression.
- **`tools/contract-check.rb`** — asserts that every document the skills name
  exists in the installed musa-dsl. The plugin now depends on file names in
  another repository; that dependency is checked rather than assumed.

### Changed

- **`search` has no `all`.** It takes a list of `{kind, query}`, each embedded and
  ranked on its own, under its own heading, nothing merged. A caller that cannot
  say which layer it needs has not finished forming its question.
- **`api_reference` looks names up** — exact, then prefix, then, clearly labelled
  as something else, the nearest chunks. **It can say no.** The escalation the
  skills describe (knowledge base, then rubydoc, then source) can only happen if
  the first step is capable of returning nothing.
- **`similar_works` ranks each collection separately.** The user's own pieces used
  to be merged into the public demos' slots and printed under their heading.
- **Results carry their kind and distance**, and an empty result distinguishes
  "nothing near enough" from "this collection is empty" — the second is a broken
  index, not an answer.
- **The index is pruned.** Documents deleted upstream used to stay for ever and
  keep being quoted.
- **The chunker refuses to build** when a kind it expects produced nothing. It had
  been producing zero best practices for months because a path moved.
- The four reasoning skills were rewritten by substitution: route, read whole,
  cite. `code` gained a source column in its modelling table and a mandatory lint
  step, and is **smaller** than before.

### Removed

- `pattern` and `dependencies`. Their fixed quotas and embedded phrasings were
  the server doing the skill's work.

### Requires

**musa-dsl with `docs/idioms.md` and `docs/vocabulary.md`** — 0.49.1 or later.
Older gems get what they have, and are told what they lack.

### What this release does not know about itself

It was rebuilt on the idea that **reading a whole document decides better than
reading a fragment**. That is argued, not measured, and it costs roughly 10k
tokens each time a modelling gate fires. The retrieval battery measures that the
right document is *reachable*; nothing yet measures whether reading it *changes
the decision*. That instrument is the commissions protocol, and it needs
compositions with a known idiomatic solution written by a person — deferred to
2.0 rather than faked here, because a battery written by the assistant would
measure its own consistency with itself.
