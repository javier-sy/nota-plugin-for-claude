# Markov with mutable transitions via blending

## Description

Create two Markov transition tables — "calm" and "wild" — and blend them continuously with a control parameter (0.0–1.0). Assign the blended result to `markov_instance.transitions=` each iteration. The Markov chain maintains its state (last value) while its behavior mutates smoothly. This turns a static Markov into a dynamic system whose character evolves over time.

Use `make_transitions` to generate distance-weighted probability tables from a list of grades, and `blend_transitions` to interpolate linearly between two tables with renormalization.

## Example

```ruby
# Helper: generate distance-weighted transition table
def make_transitions(grades, stepwise_weight:, repeat_weight:)
  transitions = {}
  grades.each do |from|
    probs = {}
    grades.each do |to|
      distance = (from - to).abs
      weight = if from == to then repeat_weight
               elsif distance <= 2 then stepwise_weight
               else 1.0
               end
      probs[to] = weight
    end
    total = probs.values.sum.to_f
    probs.transform_values! { |v| v / total }
    transitions[from] = probs
  end
  transitions
end

# Helper: blend two tables by linear interpolation + renormalization
def blend_transitions(calm, wild, factor)
  all_states = (calm.keys | wild.keys)
  result = {}
  all_states.each do |from|
    calm_t = calm[from] || {}
    wild_t = wild[from] || {}
    all_targets = (calm_t.keys | wild_t.keys)
    blended = {}
    all_targets.each do |to|
      c = calm_t[to] || 0.0
      w = wild_t[to] || 0.0
      blended[to] = c * (1.0 - factor) + w * factor
    end
    total = blended.values.sum
    blended.transform_values! { |v| v / total } if total > 0
    result[from] = blended
  end
  result
end

# Setup
rng = Random.new(42)
calm = make_transitions([0, -1, -3, 2], stepwise_weight: 3.0, repeat_weight: 4.0)
wild = make_transitions([0, -1, -2, -3, -5, 2, 4, 5], stepwise_weight: 1.2, repeat_weight: 0.5)
markov = Markov.new(start: 0, transitions: calm, random: rng).i

# Every half bar: blend transitions based on a control parameter
every(1/2r) do
  markov.transitions = blend_transitions(calm, wild, instability)
end
```

## Anti-pattern

```ruby
# BAD: creating a new Markov instance each time — loses chain state
every(1/2r) do
  new_transitions = blend_transitions(calm, wild, instability)
  markov = Markov.new(start: 0, transitions: new_transitions, random: rng).i
  # chain restarts from 0 each time — no continuity
end
```