# ClockProxy for real-time and offline execution

## Description

Wrap the clock in a proxy that delegates to either `TimerClock` (real-time performance) or `DummyClock` (offline rendering/testing). `DummyClock` advances ticks as fast as possible while the sequencer has pending events — the entire piece executes instantly. The proxy uses `respond_to?` guards for optional methods (`start`, `stop`, `bpm=`) so the same composition code works in both modes without changes.

This enables: instant test runs during development, offline MIDI file rendering, and real-time performance — all from the same codebase.

## Example

```ruby
require 'forwardable'

class ClockProxy
  extend Forwardable

  def initialize(clock)
    @clock = clock
  end

  def_delegator :@clock, :run

  def start
    @clock.start if @clock.respond_to?(:start)
  end

  def stop
    @clock.stop if @clock.respond_to?(:stop)
  end

  def bpm=(value)
    if @clock.respond_to?(:bpm=)
      @clock.bpm = value
    else
      @bpm = value
    end
  end

  def bpm
    @clock.respond_to?(:bpm) ? @clock.bpm : @bpm
  end
end

# Usage
realtime = ARGV.include?('--realtime')
sequencer = Sequencer.new(4, 24)

clock = ClockProxy.new(
  if realtime
    TimerClock.new(bpm: 120)
  else
    DummyClock.new { !sequencer.empty? }
  end
)

transport = Transport.new(clock, 4, 24)

# TimerClock needs explicit start; DummyClock doesn't — proxy handles both
transport.before_begin do
  Thread.new { sleep 0.1; clock.start }
end
```

## Anti-pattern

```ruby
# BAD: conditionals scattered throughout the composition
if realtime
  clock = TimerClock.new(bpm: 120)
  transport = Transport.new(clock, 4, 24)
  transport.before_begin { Thread.new { sleep 0.1; clock.start } }
else
  clock = DummyClock.new { !sequencer.empty? }
  transport = Transport.new(clock, 4, 24)
  # different setup, easy to diverge
end
```