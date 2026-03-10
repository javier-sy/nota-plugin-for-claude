# Buffered series for parallel voices

## Description

Use `.buffered` to create a shared buffer and `.buffer` to obtain independent readers when the same musical material must be consumed by multiple voices at different times or transpositions. This is the fundamental mechanism for canons, imitation, and any technique where voices share material with temporal offset. Each `.buffer` reader advances independently through the shared data, so one voice can start later or read at a different rate.

## Example

```ruby
# Canon: two voices, same melody, 1 bar offset, Comes a 4th below
melody = S(0, 2, 4, 5, 7, 4, 2, 0).buffered
dux_grades = melody.buffer
comes_grades = melody.buffer

durations = S(1/4r).repeat
velocities = S(80).repeat

at 1 do
  play H(grade: dux_grades, duration: durations, velocity: velocities) do |note|
    pitch = scale[note[:grade]].pitch
    v(0).note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
  end
end

at 2 do  # 1 bar later
  play H(grade: comes_grades, duration: durations.i, velocity: velocities.i) do |note|
    pitch = scale[note[:grade] - 4].pitch  # 4th below
    v(1).note pitch: pitch, velocity: note[:velocity], duration: note[:duration]
  end
end
```

## Anti-pattern

```ruby
# BAD: duplicate the series manually — diverges if one is modified
dux = S(0, 2, 4, 5, 7, 4, 2, 0)
comes = S(0, 2, 4, 5, 7, 4, 2, 0)  # separate copy, no shared buffer

# BAD: call .instance twice on the same prototype — independent iterators, not a shared canon
melody = S(0, 2, 4, 5, 7)
iter1 = melody.i  # independent
iter2 = melody.i  # independent — both start at 0, no shared data
```
