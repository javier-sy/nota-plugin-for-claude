# Use play H() for multi-parameter melody playback

## Description

Combine parallel series (grade, duration, velocity) into a hash serie with `H()` and pass it to `play`. The `play` command handles lazy iteration and timing automatically, consuming one hash per note. The block converts grades to MIDI pitches via the current scale.

## Example

```ruby
grades_arr = [0, 2, 4, 5, 7]
durs_arr = [1r, 1r, 1/2r, 1/2r, 2r]
vels_arr = [80, 70, 90, 85, 75]

control = play H(
  grade: S(*grades_arr),
  duration: S(*durs_arr),
  velocity: S(*vels_arr)
) do |note|
  pitch = scale[note[:grade]].pitch
  melody.note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
end

control.after { launch :next_section }
```

## Anti-pattern

```ruby
# BAD: manual iteration — loses timing integration with sequencer
grades_arr.each_with_index do |grade, i|
  melody.note pitch: scale[grade].pitch,
              velocity: vels_arr[i],
              duration: durs_arr[i]
end

# BAD: three separate play calls — voices not synchronized
play S(*grades_arr) do |g| ... end
play S(*durs_arr) do |d| ... end
```
