# Reset decoder state between sections

## Description

`NeumaDecoder` is stateful: relative neuma values (grade, velocity, duration) accumulate as each neuma is decoded. If section A ends at grade +5 with forte dynamics, section B will start from that accumulated state unless the decoder is explicitly reset. Always set `decoder.base` at the beginning of each independent section to ensure predictable starting values.

## Example

```ruby
on :section_a do
  decoder.base = { grade: 0, octave: 0, duration: 1/4r, velocity: 1 }
  melody_a = '(0 1 mf) (+2 1) (+4 2)'.to_neumas
  ctrl = play melody_a, decoder: decoder, mode: :neumalang do |gdv|
    pdv = gdv.to_pdv(scale)
    v(0).note pdv[:pitch], velocity: pdv[:velocity], duration: pdv[:duration]
  end
  ctrl.after { launch :section_b }
end

on :section_b do
  decoder.base = { grade: 0, octave: 0, duration: 1/4r, velocity: 1 }  # reset!
  melody_b = '(3 1 f) (-1 1/2) (0 2 p)'.to_neumas
  ctrl = play melody_b, decoder: decoder, mode: :neumalang do |gdv|
    pdv = gdv.to_pdv(scale)
    v(0).note pdv[:pitch], velocity: pdv[:velocity], duration: pdv[:duration]
  end
  ctrl.after { launch :coda }
end
```

## Anti-pattern

```ruby
# BAD: no reset — section B inherits accumulated state from section A
on :section_a do
  play '(0 1 mf) (+2 1) (+4 2)'.to_neumas, decoder: decoder, mode: :neumalang do |gdv|
    # ends at grade 6, duration 2, velocity mf
  end
end

on :section_b do
  # grade (0) here is actually grade 6 from section A's end state!
  play '(0 1 p)'.to_neumas, decoder: decoder, mode: :neumalang do |gdv|
    # unexpected pitch — decoder still carries section A's state
  end
end
```
