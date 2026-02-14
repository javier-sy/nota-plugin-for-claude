# Tick-aligned duration interpolation

## Description

When interpolating between two rhythmic patterns (e.g., uniform → Fibonacci proportions), work in **tick space** (integers) and convert to Rational only at the end. This avoids cumulative rounding errors. Always correct the last value so the total sum equals exactly one bar (or the target duration). Shuffle after interpolation if rhythmic variety is desired.

The pattern: define two tick arrays (source and target), interpolate element-wise with a blend factor, round to integers, fix the last element, then convert to Rationals.

## Example

```ruby
# Interpolate between uniform quarters and Fibonacci proportions 1:1:2:4
# 96 ticks = 1 bar (4 beats × 24 ticks/beat)
def durations_for(blend_factor, rng)
  uniform   = [24, 24, 24, 24]   # ticks: equal quarters
  fibonacci = [12, 12, 24, 48]   # ticks: 1:1:2:4 proportions

  ticks = uniform.zip(fibonacci).map { |u, f| (u + (f - u) * blend_factor).round }
  ticks[-1] = 96 - ticks[0..-2].sum  # correct last to keep sum = 1 bar

  ticks.shuffle!(random: rng) if blend_factor > 0.3
  ticks.map { |t| Rational(t, 96) }
end

# Usage
durs = durations_for(instability, rng)
# At instability 0.0: [1/4r, 1/4r, 1/4r, 1/4r]
# At instability 1.0: [1/8r, 1/8r, 1/4r, 1/2r] (shuffled)
```

## Anti-pattern

```ruby
# BAD: interpolating in Rational space — rounding issues, sum != 1 bar
def durations_for(blend_factor)
  uniform   = [1/4r, 1/4r, 1/4r, 1/4r]
  fibonacci = [1/8r, 1/8r, 1/4r, 1/2r]

  uniform.zip(fibonacci).map { |u, f|
    (u + (f - u) * blend_factor).round(4)  # Float rounding!
  }
  # Sum may not be exactly 1r — causes timing drift
end
```