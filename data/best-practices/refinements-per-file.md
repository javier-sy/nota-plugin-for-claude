# Declare refinements in every file that uses them

## Description

Ruby refinements are file-scoped: a `using` declaration only activates the refinement in the file where it appears. Declaring `using Musa::Extension::Neumas` in main.rb does NOT make `.to_neumas` available in score.rb. The same applies to `using Musa::Extension::Matrix` (for `.to_p`) and any other MusaDSL refinement. Always add the `using` declaration at the top of EVERY file that calls refined methods.

## Example

```ruby
# score.rb — must declare its own using
using Musa::Extension::Neumas    # for .to_neumas
using Musa::Extension::Matrix    # for .to_p (if using Matrix)

module TheScore
  def score
    melody = '(0 1 mf) (+2 1) (+4 2)'.to_neumas   # works
    matrix = Matrix[[0r, 60], [1/4r, 64]].to_p(time_dimension: 0)  # works
  end
end
```

## Anti-pattern

```ruby
# main.rb
using Musa::Extension::Neumas  # only active in THIS file

load 'score.rb'
extend TheScore
score

# score.rb — MISSING using declaration
module TheScore
  def score
    '(0 1 mf)'.to_neumas  # NoMethodError: undefined method 'to_neumas' for String
  end
end
```
