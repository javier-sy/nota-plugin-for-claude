# Start TimerClock from a separate thread

## Description

`transport.start` blocks the main thread until the transport is stopped. When using `TimerClock`, you must call `clock.start` from a separate thread — otherwise the program hangs because the clock never starts ticking. Use `transport.before_begin` to schedule a thread that starts the clock after a brief delay.

## Example

```ruby
clock = TimerClock.new(bpm: 120)
transport = Transport.new(clock, 4, 24)

transport.before_begin do
  Thread.new { sleep 0.1; clock.start }
end

transport.start  # blocks until transport.stop
```

## Anti-pattern

```ruby
# BAD: calling clock.start after transport.start — this line is never reached
transport.start
clock.start  # DEAD CODE — transport.start blocks forever

# BAD: calling clock.start before transport.start — sequencer not ready yet
clock.start
transport.start  # clock is already ticking but sequencer missed early ticks
```
