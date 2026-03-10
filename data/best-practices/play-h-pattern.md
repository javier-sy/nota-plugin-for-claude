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

## Variant: HC() for cyclic hash series

When component series have different lengths, use `HC()` instead of `H()`. `HC()` repeats shorter series cyclically to match the longest one, so a 3-value duration pattern cycles against an 8-value grade series without running out.

```ruby
# HC() — shorter series repeat cyclically to match the longest
melody = HC(
  grade: S(0, 2, 4, 5, 7, 9, 11, 12),    # 8 values
  duration: S(1/4r, 1/8r, 1/8r),           # 3 values — cycles: 1/4, 1/8, 1/8, 1/4, 1/8, ...
  velocity: S(80, 70)                       # 2 values — cycles: 80, 70, 80, 70, ...
)

control = play(melody) do |note|
  pitch = scale[note[:grade]].pitch
  v(0).note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
end
```

Note: with `H()`, the serie ends when the shortest component ends. With `HC()`, it ends when the longest component ends (others cycle).

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
