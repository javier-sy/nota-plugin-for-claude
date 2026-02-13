# Define helpers as def in module, not procs/lambdas

## Description

Define auxiliary functions as `def` methods inside `module TheScore`, outside of `def score`. This gives natural invocation (no `.call`), explicit dependencies via parameters (no hidden closures), and independent testability. Pure functions take only their inputs. Stateful functions receive state as explicit parameters rather than capturing it from scope.

## Example

```ruby
module TheScore
  # Pure function — all inputs via parameters
  def make_transitions(grades, stepwise_weight:, repeat_weight:)
    transitions = {}
    grades.each_with_index do |g, i|
      next_grades = grades.reject { |x| x == g }
      probs = next_grades.map { |ng| (g - ng).abs <= 2 ? stepwise_weight : 1.0 }
      total = probs.sum
      transitions[g] = next_grades.zip(probs.map { |p| p / total }).to_h
    end
    transitions
  end

  # Stateful function — RNG passed explicitly
  def bass_durations_for(instability, rng)
    base = instability > 0.5 ? [1/2r, 1/4r] : [1r, 1/2r]
    base.map { |d| d * (rng.rand(0.8..1.2)).rationalize(1/100r) }
  end

  def score
    transitions = make_transitions([0, 2, 4, 7], stepwise_weight: 3.0, repeat_weight: 4.0)
    durs = bass_durations_for(0.3, rng)
  end
end
```

## Anti-pattern

```ruby
# BAD: procs with implicit closures
make_transitions = ->(grades) {
  # captures stepwise_weight, repeat_weight from outer scope
}
make_transitions.call([0, 2, 4, 7])

# BAD: global methods outside any module
def make_transitions(grades)
  # pollutes global namespace
end
```
