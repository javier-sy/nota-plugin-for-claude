# Prompt: Regenerate musadsl-reference.md

## Objective

Regenerate the file `rules/musadsl-reference.md` — the condensed MusaDSL API reference that is always loaded in the LLM context when the Nota plugin is active.

## What this file is for

`musadsl-reference.md` is the **static knowledge layer** of the Nota plugin. It gives the LLM immediate access to accurate API signatures, patterns, and pitfalls without needing semantic search. Every skill (`/nota:code`, `/nota:explain`, `/nota:think`, etc.) benefits from this reference being precise and complete.

## Sources to read

Read ALL of the following before writing. Do not skip any file.

### Primary: musa-dsl documentation (docs/)

```
MusaDSL/musa-dsl/docs/README.md
MusaDSL/musa-dsl/docs/api-reference.md
MusaDSL/musa-dsl/docs/getting-started/quick-start.md
MusaDSL/musa-dsl/docs/getting-started/tutorial.md
MusaDSL/musa-dsl/docs/subsystems/series.md
MusaDSL/musa-dsl/docs/subsystems/sequencer.md
MusaDSL/musa-dsl/docs/subsystems/transport.md
MusaDSL/musa-dsl/docs/subsystems/music.md
MusaDSL/musa-dsl/docs/subsystems/neumas.md
MusaDSL/musa-dsl/docs/subsystems/datasets.md
MusaDSL/musa-dsl/docs/subsystems/generative.md
MusaDSL/musa-dsl/docs/subsystems/transcription.md
MusaDSL/musa-dsl/docs/subsystems/midi.md
MusaDSL/musa-dsl/docs/subsystems/matrix.md
MusaDSL/musa-dsl/docs/subsystems/musicxml-builder.md
MusaDSL/musa-dsl/docs/subsystems/core-extensions.md
MusaDSL/musa-dsl/docs/subsystems/repl.md
```

### Primary: musa-dsl README

```
MusaDSL/musa-dsl/README.md
```

### Primary: Ruby source code (inline documentation)

Read the public API of each subsystem. Focus on public method signatures, YARD `@param`/`@return` annotations, and class/module-level comments. The relevant directories are:

```
MusaDSL/musa-dsl/lib/musa-dsl/series/
MusaDSL/musa-dsl/lib/musa-dsl/sequencer/
MusaDSL/musa-dsl/lib/musa-dsl/transport/
MusaDSL/musa-dsl/lib/musa-dsl/music/
MusaDSL/musa-dsl/lib/musa-dsl/neumas/
MusaDSL/musa-dsl/lib/musa-dsl/neumalang/
MusaDSL/musa-dsl/lib/musa-dsl/datasets/
MusaDSL/musa-dsl/lib/musa-dsl/generative/
MusaDSL/musa-dsl/lib/musa-dsl/transcription/
MusaDSL/musa-dsl/lib/musa-dsl/midi/
MusaDSL/musa-dsl/lib/musa-dsl/matrix/
MusaDSL/musa-dsl/lib/musa-dsl/musicxml/
MusaDSL/musa-dsl/lib/musa-dsl/core-ext/
MusaDSL/musa-dsl/lib/musa-dsl/repl/
MusaDSL/musa-dsl/lib/musa-dsl/logger/
```

For each directory, read all `.rb` files. Prioritize files with substantial documentation comments over purely implementation files.

### Secondary: supporting gem READMEs

```
MusaDSL/midi-communications/README.md
MusaDSL/midi-events/README.md
MusaDSL/midi-parser/README.md
MusaDSL/musalce-server/README.md
```

## Output requirements

### Format

Write a single markdown file: `rules/musadsl-reference.md`

### Content principles

1. **Accuracy over brevity** — Every method signature, parameter name, and default value must match the source code. When docs and code disagree, the code is authoritative.

2. **Condensed, not summarized** — This is a reference, not a tutorial. Use tables for enumerations (constructors, operations, scales, clocks). Use code blocks for signatures and minimal usage examples. Omit narrative explanations that don't add information beyond the code itself.

3. **Complete public API** — Cover every public subsystem. If something exists in the source but was missing from the previous version, add it. Do not omit subsystems or methods because they seem minor.

4. **Practical code examples** — For each subsystem, include at least one minimal working example showing typical usage. Examples should be correct and runnable.

5. **Pitfalls and critical warnings** — Preserve and update the "Common Pitfalls" section. These are high-value for preventing LLM errors. Add new pitfalls discovered in the source.

### Structure

Follow this section order (same as the current version, with additions as needed):

1. Title + one-line description
2. Architecture overview (ASCII diagram of the data flow)
3. Include pattern (`include Musa::All` etc.)
4. Setup Pattern (canonical main.rb)
5. One section per subsystem, in this order:
   - Series (constructors, operations, instantiation)
   - Neumas / Neumalang (notation format, parsing)
   - Sequencer DSL (at, wait, every, play, move, on/launch)
   - Scales & Music (constructors, note access, chords, available scales)
   - Generative Tools (Markov, Variatio, Rules, GenerativeGrammar, Darwin)
   - Datasets (GDV, PDV, GDVd, AbsD, Score)
   - Transcription (MIDI and MusicXML transcriptors)
   - MIDI (device selection, MIDIVoices, MIDIRecorder)
   - Transport & Clocks (clock types, lifecycle callbacks)
   - Matrix (to_p conversion)
   - MusicXML Builder
   - Core Extensions (if relevant public API)
   - REPL (if relevant public API)
6. Common Pitfalls (numbered list)
7. Demo Index (table of all demos with topic and key concepts)

### Size target

~400 lines, ~15k tokens. This is the current size and is a good balance for always-in-context reference. If the source material warrants more, up to ~500 lines is acceptable, but prefer density over length.

### What NOT to include

- Plugin instructions (how to use Nota skills, the creative cycle, etc.)
- Best practices for composition structure (that belongs in GOOD_PRACTICES.md or the knowledge DB)
- Behavioral rules for the LLM (that belongs in other rule files)
- Version history or changelog
- Installation instructions for musa-dsl itself

## Process

1. Read all primary sources (docs + source code) in parallel where possible
2. Read secondary sources (gem READMEs)
3. Cross-reference docs against source code to verify accuracy
4. Write the complete `rules/musadsl-reference.md`
5. After writing, verify: are there any public classes/modules in the source that have no coverage in the reference? If so, add them.
