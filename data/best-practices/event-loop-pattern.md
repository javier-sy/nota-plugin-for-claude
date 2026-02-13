# Event loop with on/launch for recalculated material

## Description

Use `on`/`launch` events for looping sections where material is recalculated each iteration. The pattern: register an event handler with `on :name`, generate material inside it, play it, and in `control.after` launch the same event again. This is more flexible than `every` for material that changes each cycle based on evolving state.

## Example

```ruby
on :bass_bar do
  # Recalculate material each iteration using current state
  grades = markov_instance.to_a.first(4)
  durs = bass_durations_for(instability, rng)
  vels = [rng.rand(60..90)] * 4

  bass_ctrl = play H(
    grade: S(*grades),
    duration: S(*durs),
    velocity: S(*vels)
  ) do |note|
    pitch = current_scale[note[:grade]].pitch
    bass.note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
  end

  bass_ctrl.after { launch :bass_bar }
end

at(1) { launch :bass_bar }
```

## Anti-pattern

```ruby
# BAD: using every with static material — same bar repeated
every 1 do
  bass.note pitch: 36, velocity: 100, duration: 1r
end

# BAD: infinite loop with sleep — blocks the sequencer
loop do
  play_something
  sleep 1  # never do this in the sequencer context
end
```
