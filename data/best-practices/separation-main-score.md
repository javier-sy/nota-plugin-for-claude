# Separate main.rb from score.rb

## Description

Split every project into two files: **main.rb** for infrastructure (MIDI, clock, transport, voices, shutdown) and **score.rb** for pure composition (musical material, events, formal structure). The composer works in score.rb without touching infrastructure. This separation enables live-coding reload of the score without restarting transport.

## Example

```ruby
# main.rb — infrastructure only
require 'musa-dsl'
require 'midi-communications'
include Musa::All

output = MIDICommunications::Output.gets
clock = TimerClock.new(bpm: 120)
transport = Transport.new(clock, 4, 24)
scale = Scales.et12[440.0].major[60]
voices = MIDIVoices.new(sequencer: transport.sequencer, output: output, channels: [0, 1])

transport.sequencer.with do
  @transport = transport
  @voices = voices
  @scale = scale

  load 'score.rb'
  extend TheScore
  score
end

transport.start
```

```ruby
# score.rb — composition only
module TheScore
  def score
    melody = v(0)
    at 1 do
      launch :section_a
    end

    on :section_a do
      # ... musical content ...
    end
  end
end
```

## Anti-pattern

```ruby
# BAD: everything in one file — infrastructure mixed with composition
require 'musa-dsl'
output = MIDICommunications::Output.gets
clock = TimerClock.new(bpm: 120)
transport = Transport.new(clock, 4, 24)
# ... 200 lines of setup ...
transport.sequencer.with do
  # ... 500 lines of composition interleaved with setup ...
end
transport.start
```
