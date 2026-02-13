# Voice accessor with v(n)

## Description

`MIDIVoices` does not define `[]` — you must use `.voices[n]` to access individual voices. Define a `v(n)` accessor in the sequencer context to encapsulate this. At the beginning of the score, assign voices to semantic names like `kick = v(0)`, `bass = v(1)` for readability.

## Example

```ruby
# main.rb — inside sequencer.with
@voices = voices
def v(n) = @voices.voices[n]

load 'score.rb'
extend TheScore
score
```

```ruby
# score.rb
module TheScore
  def score
    kick = v(0)
    snare = v(1)
    bass = v(2)
    melody = v(3)

    # ... use semantic names throughout
    kick.note pitch: 36, velocity: 100, duration: 1/4r
  end
end
```

## Anti-pattern

```ruby
# BAD: verbose access repeated everywhere
voices.voices[0].note pitch: 36, velocity: 100, duration: 1/4r
voices.voices[1].note pitch: 38, velocity: 90, duration: 1/4r

# BAD: using [] directly on MIDIVoices — NoMethodError
voices[0].note pitch: 36, velocity: 100, duration: 1/4r
```
