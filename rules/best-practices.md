# MusaDSL Best Practices

Condensed reference of composition project conventions. Apply these when writing or reviewing MusaDSL code.

1. **Separate main.rb / score.rb** — main.rb = infrastructure (MIDI, clock, transport, voices, shutdown). score.rb = composition (material, events, structure). Composer works only in score.rb.
2. **Use `module TheScore` + `load`/`extend`** — define composition in `module TheScore` with a `def score` entry point. Use `load` (not `require`) for live-coding reload. `extend TheScore` mixes it into the sequencer context.
3. **Expose infrastructure via accessors** — define `def transport`, `def scale`, `def v(n)`, `def debug(&block)` inside `sequencer.with`. score.rb accesses them as methods, not variables.
4. **`v(n)` for voice access** — `MIDIVoices` has no `[]`; use `def v(n) = @voices.voices[n]`. Assign semantic names: `kick = v(0)`, `bass = v(1)`.
5. **Start TimerClock from a thread** — `transport.start` blocks; call `clock.start` from `Thread.new` inside `transport.before_begin`. Without this, the program hangs.
6. **Clean shutdown in `after_stop`** — call `voices.panic` (CC 123 all-notes-off) then `output&.close`. Do not call `sequencer.reset` — transport does it automatically.
7. **Thread-safe Ctrl+C** — wrap `transport.stop` in `Thread.new` inside `trap('INT')`. Direct call risks deadlock because stop uses a Mutex.
8. **Fixed seed for reproducibility** — `rng = Random.new(42)`. Pass to `Markov.new(random: rng)` and all `rng.rand()` calls explicitly. Same seed = same piece.
9. **`on`/`launch` for loops with recalculated material** — register `on :event`, generate material inside, `play` it, chain with `control.after { launch :event }`. More flexible than `every` for evolving content.
10. **`play H()` for multi-parameter melodies** — combine grade, duration, velocity series with `H()`. `play` handles timing. Block converts grades to pitches via scale.
11. **Define helpers as `def` in module, not procs** — auxiliary functions go as `def` in `module TheScore`, outside `def score`. Natural invocation, explicit parameters, no hidden closures.
12. **Always use Rational for timing** — `1/4r`, `1r`, `3/4r`. Never Float. Integer `1/4` without `r` suffix evaluates to 0.
13. **Lazy debug via logger** — `def debug(&block) = @transport.logger.debug('score', &block)`. Block evaluated only when log level active. Enable with `do_log: true` in Transport.
14. **Markov blending for evolving behavior** — create "calm" and "wild" transition tables, blend with a 0.0–1.0 factor, assign to `markov.transitions=`. Chain state preserved while behavior mutates smoothly.
15. **Parameterize with Series, not scalars** — wrap constants with `S(value).repeat` from the start. Later, swap to `S(v1, v2, v3).repeat` without restructuring code.
16. **Tick-aligned duration interpolation** — when interpolating rhythms, work in integer tick space and convert to Rational at the end. Correct the last value to keep the sum exact.
17. **Dual-level logging** — clone the sequencer's logger with a different level for composition logging. Sequencer at `error!`, composition at `warn!` or `info!`. Use `force:` for critical messages.
18. **Buffered series for parallel voices** — `.buffered` creates a shared buffer; `.buffer` obtains independent readers. Essential for canons: same material, different temporal offsets or transpositions.
19. **Reset decoder state between sections** — set `decoder.base = { grade: 0, octave: 0, duration: 1/4r, velocity: 1 }` at the start of each independent section. Without reset, relative neuma values carry over from the previous section.
20. **Declare refinements in every file** — `using Musa::Extension::Neumas` and other refinements are file-scoped. Must appear in EVERY .rb file that calls refined methods, not just main.rb.
21. **Prime periods for parameter automation** — use prime `steps:` in `SIN()` for multiple parameters. GCD of primes = 1, so combined cycle = product of all periods. Use `PRIMES[]` array.
22. **State machine for multi-phase structure** — centralize state in a `@state` hash with phase, episode counters. Route transitions through a `:transition` event handler. Phases are self-contained and decoupled.
23. **Push-poll for external control** — external input (OSC, MIDI CC) triggers events that update state variables; sequencer reads them on its own grid with `every`. Never generate notes directly from input handlers.
