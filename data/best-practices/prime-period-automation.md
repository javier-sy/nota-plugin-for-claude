# Prime periods for non-repeating parameter automation

## Description

When automating multiple parameters simultaneously with `SIN()`, use prime numbers for the period lengths (the `steps:` parameter). Since the GCD of any two primes is 1, their combined cycle length equals the product of all periods — producing rich, non-repeating textures from simple oscillators. Access primes via the `PRIMES[]` array. For example, periods of 13, 17, and 19 produce a combined cycle of 4,199 steps before the exact pattern repeats.

## Example

```ruby
# Three parameters with prime periods — combined cycle = 13 × 17 × 19 = 4199 notes
vel_env = SIN(steps: PRIMES[5], center: 70, amplitude: 40).instance    # period 13
dur_env = SIN(steps: PRIMES[7], center: 8, amplitude: 4).instance      # period 19
pan_env = SIN(steps: PRIMES[6], center: 64, amplitude: 50).instance    # period 17

every 1/16r do
  vel = vel_env.next_value.to_i
  dur = Rational(dur_env.next_value.to_i, 32)
  pan = pan_env.next_value.to_i

  voice.controller[10] = pan       # CC 10 = pan
  voice.note pitch, velocity: vel, duration: dur
end
```

## Anti-pattern

```ruby
# BAD: equal or multiple periods — cycles synchronize, result sounds mechanical
vel_env = SIN(steps: 16, center: 70, amplitude: 40).instance
dur_env = SIN(steps: 16, center: 8, amplitude: 4).instance    # same period: perfect sync
pan_env = SIN(steps: 32, center: 64, amplitude: 50).instance  # multiple of 16: sync every 32

# BAD: even non-prime coprime values give shorter combined cycles than primes
vel_env = SIN(steps: 12, center: 70, amplitude: 40).instance
dur_env = SIN(steps: 15, center: 8, amplitude: 4).instance    # LCM(12,15) = 60, not 180
```
