# Lazy debug helper via transport logger

## Description

Define a `debug` accessor that delegates to `transport.logger.debug` with a tag. The block-based interface ensures lazy evaluation: the block is only executed when the log level is active. Enable with `do_log: true` in `Transport.new`. Use `debug { "msg" }` in score.rb for clean, zero-cost-when-disabled logging.

## Example

```ruby
# main.rb — inside sequencer.with
@transport = transport
def debug(&block) = @transport.logger.debug('score', &block)

# score.rb — usage
on :bass_bar do
  debug { "bass_bar triggered at position #{position}" }
  # ...
  bass_ctrl.after do
    debug { "bass → after" }
    launch :bass_bar
  end
end
```

## Anti-pattern

```ruby
# BAD: eager evaluation — string built even when logging is off
puts "bass_bar triggered at position #{position}"

# BAD: conditional logging scattered throughout
if $debug
  puts "bass_bar triggered"
end
```
