# Use module TheScore with load/extend

## Description

Define the composition code inside `module TheScore` with a single entry-point method (`def score`). In main.rb, use `load` (not `require_relative`) to load score.rb, then `extend TheScore` to mix the module into the sequencer context. This gives score.rb access to all infrastructure accessors (`transport`, `v(n)`, `debug`) without passing parameters, and `load` allows re-evaluation during live coding.

## Example

```ruby
# main.rb — inside sequencer.with block
@transport = transport
@voices = voices
@scale = scale

def transport = @transport
def scale = @scale
def v(n) = @voices.voices[n]
def debug(&block) = @transport.logger.debug('score', &block)

load 'score.rb'
extend TheScore
score
```

```ruby
# score.rb
using Musa::Extension::Neumas  # must be in EACH file

module TheScore
  def score
    kick = v(0)
    bass = v(1)
    # ... composition using transport, scale, v(), debug ...
  end
end
```

## Anti-pattern

```ruby
# BAD: require_relative — cannot reload during live coding
require_relative 'score'

# BAD: passing everything as parameters
def score(transport, voices, scale, decoder, ...)
  # ... unwieldy parameter list
end
```
