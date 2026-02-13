# Fixed seed for reproducibility

## Description

Create a `Random.new(seed)` instance with a fixed seed and pass it explicitly to all stochastic operations. This guarantees that the same seed produces the exact same composition. Pass the RNG as an explicit parameter to helper methods — do not use global `rand()`. Change the seed to explore variants.

## Example

```ruby
rng = Random.new(42)

# Pass to Markov
markov = Musa::Markov::Markov.new(
  start: 0,
  transitions: { 0 => { 2 => 0.5, 4 => 0.5 }, 2 => { 0 => 1.0 }, 4 => { 0 => 1.0 } },
  random: rng
)

# Pass to helper methods explicitly
def select_next_mode(instability, mode_tiers, current_mode, rng)
  threshold = rng.rand
  # ...
end

# Custom random selections
durations = [1r, 1/2r, 1/4r]
dur = durations[rng.rand(durations.length)]
```

## Anti-pattern

```ruby
# BAD: using global rand — not reproducible, not seedable
dur = durations[rand(durations.length)]

# BAD: creating Random.new without seed — different every run
rng = Random.new
```
