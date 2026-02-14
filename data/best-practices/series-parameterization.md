# Parameterize with Series instead of scalars

## Description

Define composition parameters as Series from the start, even when they begin as constants. Use `S(value).repeat` to wrap a scalar — it behaves identically to the scalar but can later be replaced with a varying Series (`S(7, 14, 3).repeat`) without restructuring the code. This enables creating variants by changing only the parameter definitions.

In class-based compositions, define parameters as class constants. In module-based compositions, define them as method return values or local variables at the top of the score method. The key principle: the runner code consumes `.next_value` uniformly, whether the source is constant or varying.

## Example

```ruby
module TheScore
  # Parameters as Series — change these for variants
  MELODY_OCTAVE = S(5).repeat          # constant: always octave 5
  DENSITY_FACTOR = S(1.0, 1.5, 2.0).repeat  # varying: cycles through values
  RHYTHM_SUBDIVISIONS = S(4).repeat    # constant now, easy to vary later

  def score
    octave_s = MELODY_OCTAVE.i
    density_s = DENSITY_FACTOR.i
    subdiv_s = RHYTHM_SUBDIVISIONS.i

    on :section do
      octave = octave_s.next_value
      density = density_s.next_value
      subdiv = subdiv_s.next_value
      # ... use values uniformly regardless of source ...
    end
  end
end
```

```ruby
# Class-based alternative (for large projects with inheritance)
class Composition < BaseComposition
  CENTER_PITCH = 72
  RADIUS_SERIE = S(4).repeat   # scalar wrapped as Serie
end

class Variant3 < Composition
  RADIUS_SERIE = S(4, 8, 2, 6).repeat  # now varies — no other changes needed
end
```

## Anti-pattern

```ruby
# BAD: using raw scalars — changing to a varying parameter requires restructuring
RADIUS = 4

def render(radius)
  # ... uses radius as a number ...
end

# To vary per iteration, you now need to change render() signature,
# add Series logic, and update all call sites
```