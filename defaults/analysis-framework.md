# Analysis Framework

Default analytical dimensions for composition analysis. Each `##` section defines one dimension. The section title names the dimension; the body instructs what to analyze.

Customize this framework with `/nota:analysis_framework` to add, remove, or modify dimensions.

## Formal Structure

Analyze the macro-level structure of the composition:

- Identify sections and how they are organized (on/launch event chains, sequencer scheduling with `at`/`every`/`wait`)
- Map the form: is it through-composed, sectional, cyclic, open-ended?
- Note proportions: relative durations of sections, density changes across the timeline
- Describe the chaining logic: how sections connect, whether transitions are immediate or gradual

## Harmonic and Modal Language

Analyze the pitch organization:

- Which scales and modes are used (`Scales.et12[...].major`, `.minor`, `.dorian`, etc.)?
- Are there modulations, transpositions, or scale changes over time?
- Identify tonal centers and how they shift
- Note chord construction patterns and harmonic rhythm
- Are grades used relative or absolute? How does the grade space map to pitch?

## Rhythmic and Temporal Strategy

Analyze time organization:

- What `base_duration` is used and how do neuma durations relate to it?
- Identify rhythmic patterns, repetitions, and variations
- Are there polyrhythms, cross-rhythms, or metric modulations?
- What clock/transport setup is used (TimerClock, InputMidiClock, ExternalTickClock)?
- Note tempo choices and any tempo changes

## Generative Strategy

Analyze how material is generated algorithmically:

- Which generative tools are used (Markov, Variatio, Rules/L-systems, Darwin/genetic, GenerativeGrammar)?
- How are Series used — which constructors (S, FOR, FIBO, H, etc.) and which operations (map, select, merge, etc.)?
- What is the balance between deterministic and indeterminate elements?
- Are there feedback loops or self-modifying structures?
- How are random/stochastic elements controlled (seeds, ranges, weighted choices)?

## Texture and Instrumentation

Analyze the sonic surface:

- How many voices/MIDI channels are used and what roles do they play?
- How is density managed over time — layering, thinning, solo passages?
- Are there distinct timbral roles (melody, bass, harmony, percussion)?
- How are velocity dynamics used (ppp through fff)?
- Note any MIDI-specific techniques (program changes, CC, aftertouch)

## Idiomatic Usage and Special Features

Analyze how the composition uses MusaDSL's unique capabilities:

- Which MusaDSL-specific idioms are central to the piece (neumas, series operations, transcriptors, ornaments)?
- Are there unusual or creative uses of the framework?
- How does the code architecture reflect the musical architecture?
- Note any custom extensions, refinements, or workarounds

## Relation to Other Artists

Identify connections to other composers, traditions, or aesthetic movements:

- What musical traditions or styles does this piece relate to (minimalism, spectralism, serialism, aleatoric, generative, etc.)?
- Are there specific composers whose techniques or aesthetics are echoed?
- **Use WebSearch to complement your knowledge**: search for relevant composers, techniques, or movements to provide accurate context and citations
- Note connections to electronic music, live coding culture, or algorithmic art communities

## Notable Technical Patterns

Extract reusable patterns and representative fragments:

- Identify idiomatic code patterns that could be reused in other compositions
- Highlight notable combinations of series operations
- Note effective patterns for section chaining, voice management, or generative control
- Include short representative code fragments (with brief explanation) that capture the essence of the piece's technique

## Coding Best Practices

Extract reusable best practices at the project and code organization level:

- **Project structure** — How is the code organized across files? Is there a clear separation between setup (transport, voices, scale) and composition logic (score, sections)? What organizational decisions make the project easier to understand, modify, or extend?
- **Abstraction choices** — Where does the code create useful abstractions (helper methods, reusable series, parameterized patterns) vs. where does it keep things inline and direct? What is the right level of abstraction for this piece, and why?
- **Parameterization** — Which musical decisions are expressed as parameters (scale, tempo, density, probabilities) that can be tweaked without restructuring? What would a newcomer need to change to create a variation?
- **Readability** — How well does the code communicate its musical intent? Are variable names, structure, and flow readable as a "score"? What naming or structural conventions make the code self-documenting?
- **Modularity and reuse** — Are there self-contained patterns (a voice setup, a generative engine, a section-chaining strategy) that could be lifted into another project with minimal adaptation? Express them as transferable recipes.
- **Error resilience** — How does the code handle edge cases — empty series, MIDI connection issues, timing drift? Are there defensive patterns worth adopting?
- **Lessons learned** — What worked particularly well that should become standard practice? What was awkward or fragile and should be done differently next time?

## Conclusion

Synthesize the analysis into a cohesive closing:

- **Key aspects** — Recapitulate the most significant findings across all dimensions. What defines this piece? What are its central ideas, its strongest choices, its distinctive character? Distill the analysis into its essential points.
- **Aesthetic reading** — Go beyond technical description to interpret the piece musically and aesthetically. What is the compositional intention? What effect does the algorithmic approach produce that a manual approach would not? Where does the piece sit in the tension between process and result, control and emergence, code and music?
- **Closing** — A brief, considered final statement that captures the essence of the piece as a whole — its identity, its contribution, its place in the composer's practice.
