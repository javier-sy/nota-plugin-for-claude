# Clean shutdown in after_stop

## Description

Register an `after_stop` callback on the transport to ensure clean shutdown. Call `voices.panic` to send CC 123 (all-notes-off) on every channel, then close the MIDI output. Do not call `transport.sequencer.reset` — the transport handles reset automatically after `after_stop` callbacks.

## Example

```ruby
transport.after_stop do
  voices.panic       # CC 123 all-notes-off on all channels
  output&.close      # release MIDI resource
  puts "\n  Stopped"
end
```

## Anti-pattern

```ruby
# BAD: no cleanup — notes hang after stopping
transport.start
# (Ctrl+C or transport.stop — notes keep sounding)

# BAD: calling reset manually — transport does this automatically
transport.after_stop do
  voices.panic
  transport.sequencer.reset  # UNNECESSARY — done automatically
  output&.close
end
```
