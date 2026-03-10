# Push-poll architecture for external control

## Description

When receiving external control (OSC, MIDI CC, network messages), use a push-poll architecture: incoming messages trigger events that update state variables; the sequencer reads those variables on its own timing grid with `every`. This decouples the input source from the musical timing — external messages arrive asynchronously, but notes are always quantized to the sequencer grid. Never generate notes directly from the input handler (timing will be irregular) and never block the sequencer waiting for input.

## Example

```ruby
# === Push: external input updates state via events ===

@current_scale = Scales.et12[440.0].major[60]
@current_pattern = [1, 0, 1, 0, 1, 0, 1, 0]
@velocity = 80

on :root_changed do |params|
  @current_scale = Scales.et12[440.0].send(params[:mode])[60 + params[:root]]
end

on :density_changed do |params|
  @current_pattern = DENSITY_PATTERNS[params[:density]]
end

on :velocity_changed do |params|
  @velocity = params[:value]
end

# === Poll: sequencer reads state on its own grid ===

every 1/8r do
  bar_pos = ((position * 8).to_i) % 8
  next unless @current_pattern[bar_pos] == 1

  grade = rng.rand(0..6)
  pitch = @current_scale[grade].pitch
  v(0).note pitch: pitch, velocity: @velocity, duration: 1/16r
end
```

## Anti-pattern

```ruby
# BAD: generate notes directly from input handler — irregular timing
on :note_trigger do |params|
  v(0).note pitch: params[:pitch], velocity: 100, duration: 1/4r
  # timing depends on when the OSC message arrives, not on the grid
end

# BAD: poll the input source from the sequencer — blocking risk
every 1/8r do
  msg = osc_server.recv  # blocks until message arrives!
  v(0).note pitch: msg.pitch, velocity: 100, duration: 1/16r
end
```
