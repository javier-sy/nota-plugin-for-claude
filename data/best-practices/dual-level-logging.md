# Dual-level logging: sequencer vs composition

## Description

The sequencer generates massive output at debug/info levels. Clone the sequencer's logger and set a different level for composition logging. This way the composition can log at `warn` or `info` without flooding the console with sequencer internals.

For punctual messages that need visibility regardless of level, use a `force:` parameter that temporarily overrides the log level.

## Example

```ruby
# In setup (main.rb or base class)
sequencer = Sequencer.new(4, 24)
sequencer.logger.error!  # sequencer: only errors (silent)

# Clone for composition use
@logger = sequencer.logger.clone
@logger.warn!  # composition: warnings and above

def info(text, force: false)
  previous_level = @logger.level
  @logger.level = Logger::INFO if force
  @logger.info(text)
  @logger.level = previous_level if force
end

# Usage in composition
info "Processing section 3..."              # only shown if level <= INFO
info "CRITICAL: mode changed", force: true  # always shown
```

```ruby
# Simpler alternative using Transport's built-in logger
transport = Transport.new(clock, 4, 24, do_log: false)  # suppress transport logs

# In sequencer context
def debug(&block) = @transport.logger.debug('score', &block)

# Usage
debug { "bass bar #{bar_count}" }  # lazy — block only evaluated if level allows
```

## Anti-pattern

```ruby
# BAD: puts everywhere — no level control, no way to silence
puts "Section A starting..."
puts "Note: #{pitch} vel: #{vel}"
# Cannot turn off without deleting lines

# BAD: using sequencer logger directly — floods with tick-level detail
transport = Transport.new(clock, 4, 24, do_log: true)
# Console filled with "tick 1", "tick 2", ... for every tick
```