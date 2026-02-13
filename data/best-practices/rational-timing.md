# Always use Rational for timing values

## Description

Always use Ruby's Rational literal syntax (`1/4r`, `1r`, `3/4r`) for all timing values: durations, positions, base_duration, tick_duration. Never use Float (`0.25`, `1.0`) for timing — floating point arithmetic causes cumulative drift that makes notes arrive at wrong positions. Rational arithmetic is exact.

## Example

```ruby
# Correct: Rational literals
transport = Transport.new(clock, 4, 24)
decoder = Musa::Neumas::Decoders::NeumaDecoder.new(scale, base_duration: 1/4r)
transcriptor = Musa::Transcription::Transcriptor.new(
  transcription_set, base_duration: 1/4r, tick_duration: 1/96r
)

voice.note pitch: 60, velocity: 100, duration: 1/4r    # quarter note
voice.note pitch: 62, velocity: 90, duration: 1/2r     # eighth note
voice.note pitch: 64, velocity: 80, duration: 1r        # whole base_duration

wait(3/4r) { launch :next }
every 1/2r, duration: 4r do ... end
```

## Anti-pattern

```ruby
# BAD: Float — cumulative drift over time
voice.note pitch: 60, velocity: 100, duration: 0.25
wait(0.75) { launch :next }

# BAD: Integer division without r suffix — evaluates to 0!
duration: 1/4    # => 0 (integer division)
duration: 1/4r   # => (1/4) (Rational — correct)
```
