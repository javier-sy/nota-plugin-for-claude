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
