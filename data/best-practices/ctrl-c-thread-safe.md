# Thread-safe Ctrl+C handler

## Description

`transport.stop` uses a Mutex internally, so it cannot be called directly from a signal handler (Ruby signal handlers run in the main thread's context and can deadlock). Wrap the call in `Thread.new` to move it out of the signal handler context.

## Example

```ruby
trap('INT') do
  puts "\n  [Ctrl+C] Stopping..."
  Thread.new { transport.stop }
end
```

## Anti-pattern

```ruby
# BAD: direct call in trap — risk of deadlock
trap('INT') do
  transport.stop  # may deadlock if main thread holds the Mutex
end

# BAD: no handler at all — Ctrl+C kills the process without cleanup
# (notes hang, MIDI output not closed)
```
