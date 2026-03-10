# State machine for multi-phase compositions

## Description

For compositions with complex formal structure (multiple phases, episodes, transitions), use a centralized `@state` hash to track current phase, episode counters, and accumulated metrics. Route all transitions through a dedicated `:transition` event handler. Each phase is self-contained: it generates its material, plays it, and launches a transition when done — without knowing what comes next. This keeps phases decoupled and the formal structure explicit and easy to modify.

## Example

```ruby
@state = { phase: :exposition, episode: 0, total_notes: 0 }

on :transition do |next_phase|
  @state[:phase] = next_phase
  @state[:episode] = 0
  case next_phase
  when :development then launch :development
  when :climax then launch :climax
  when :coda then launch :coda
  end
end

on :exposition do
  @state[:episode] += 1
  return launch(:transition, :development) if @state[:episode] > 3

  series = exposition_series(episode: @state[:episode])
  melody = H(
    grade: series[:pitches].instance,
    duration: series[:durations].instance,
    velocity: series[:velocities].instance
  ).instance

  control = play(melody) do |note|
    pitch = scale[note[:grade]].pitch
    v(0).note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
    @state[:total_notes] += 1
  end
  control.after { wait 1/8r { launch :exposition } }
end

on :development do
  @state[:episode] += 1
  transpose = (@state[:episode] - 1) * 2
  return launch(:transition, :climax) if @state[:episode] > 4

  control = play_phase(dev_material, transpose: transpose)
  control.after { wait 1/8r { launch :development } }
end

at 1 { launch :exposition }
```

## Anti-pattern

```ruby
# BAD: nested transition logic — phases know about each other
on :exposition do
  play(melody) do |note| ... end
  # tightly coupled: exposition decides what comes next
  if episode > 3
    launch :development  # what if we want to insert a transition section?
  end
end

# BAD: fixed-time scheduling — fragile to tempo or duration changes
at 1 { launch :exposition }
at 17 { launch :development }   # breaks if exposition durations change
at 33 { launch :climax }        # breaks if development durations change
```
