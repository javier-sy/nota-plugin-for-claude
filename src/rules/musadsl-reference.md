# MusaDSL Condensed API Reference

Ruby framework for algorithmic sound and musical composition. All signatures verified against source code.

## Architecture

```
Clock ──ticks──> Transport ──tick()──> Sequencer ──events──> Music
                    │                     │
                    │              DSL: at, wait, every,
                    │              play, move, on/launch
                    │                     │
              Lifecycle:            Series (lazy)
          before_begin             Generative tools
            on_start          Neumas ──> Datasets (GDV/PDV)
           after_stop                    │
                                   Transcription
                                    │         │
                              MIDIVoices   MusicXML Builder
```

## Include Pattern

```ruby
include Musa::All            # All modules at once (recommended)
include Musa::Series         # Series constructors + operations only
include Musa::Scales         # Scale system access
include Musa::Chords         # Chord structures
include Musa::Datasets       # GDV, PDV, Score, etc.
include Musa::GenerativeGrammar  # N(), PN(), operators

using Musa::Extension::Neumas   # .to_neumas — FILE-SCOPED, declare in EACH file
using Musa::Extension::Matrix   # Matrix#to_p
```

## Setup Pattern (main.rb)

```ruby
require 'musa-dsl'
require 'midi-communications'
include Musa::All
using Musa::Extension::Neumas

output      = MIDICommunications::Output.gets      # interactive MIDI output selection
clock_input = MIDICommunications::Input.gets       # for MIDI sync (slave mode)

# Clock options (pick one):
clock = InputMidiClock.new(clock_input)                      # DAW sync (slave)
clock = TimerClock.new(bpm: 120, ticks_per_beat: 24)         # internal (master)
clock = DummyClock.new(ticks)                                 # testing
clock = ExternalTickClock.new                                 # manual control

transport = Transport.new(clock, 4, 24)   # beats_per_bar, ticks_per_beat
scale     = Scales.et12[440.0].major[60]  # 12-TET, A=440, C major at MIDI 60

voices = MIDIVoices.new(sequencer: transport.sequencer, output: output, channels: [0, 1])

# Optional: transcriptor for ornament expansion
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMIDI.transcription_set(duration_factor: 1/6r),
  base_duration: 1/4r, tick_duration: 1/96r
)
decoder = Decoders::NeumaDecoder.new(scale, base_duration: 1/4r, transcriptor: transcriptor)

transport.sequencer.with do
  # DSL methods available: at, wait, now, every, play, play_timed, move, on, launch, position
end

# TimerClock requires external activation:
transport.before_begin do
  Thread.new { sleep 0.1; clock.start }
end

transport.start  # blocks until clock terminates
```

## Series

### Constructors

| Constructor | Signature | Description |
|---|---|---|
| `S` | `S(*values)` | Array serie; ranges auto-expanded |
| `E` | `E(*args, **kwargs, &block)` | Evaluation block; block receives `last_value:`, `caller:` |
| `H` | `H(**series_hash)` | Hash of series (stops at shortest) |
| `HC` | `HC(**series_hash)` | Hash combined (cycles all series) |
| `A` | `A(*series)` | Array of series (stops at shortest) |
| `AC` | `AC(*series)` | Array combined (cycles all series) |
| `FOR` | `FOR(from: nil, to: nil, step: nil)` | Numeric range; step sign auto-adjusted |
| `MERGE` | `MERGE(*series)` | Sequential concatenation |
| `RND` | `RND(*values, values: nil, from: nil, to: nil, step: nil, random: nil)` | Random SHUFFLE: each value once, then ends. `.repeat` for replacement (see pitfall 9) |
| `RND1` | `RND1(*values, values: nil, from: nil, to: nil, step: nil, random: nil)` | Single random value then exhausts |
| `SIN` | `SIN(start_value: nil, steps: nil, amplitude: nil, center: nil)` | Sine wave; finite (steps iterations) |
| `FIBO` | `FIBO(first = 1, second = 1)` | Fibonacci: 1, 1, 2, 3, 5, 8... The seeds ARE the first two values: `FIBO(0, 1)` includes the leading zero, `FIBO(2, 1)` gives the Lucas numbers (infinite) |
| `HARMO` | `HARMO(error: nil, extended: nil)` | Harmonic series as MIDI semitones (infinite) |
| `NIL` | `NIL()` | Always returns nil |
| `UNDEFINED` | `UNDEFINED()` | Placeholder (undefined state) |
| `TIMED_UNION` | `TIMED_UNION(*series)` or `TIMED_UNION(**named)` | Merge timed series by time |

### Operations (chainable on any serie)

| Operation | Description |
|---|---|
| `.i` | Create instance (required before iterating) |
| `.next_value` | Get next value (on instance) |
| `.to_a` | Collect all values, restarting the instance. There is no `limit:`; bound an infinite serie with `.max_size(n)` first |
| `.map(isolate_values: nil, &block)` | Transform each value |
| `.select(&block)` | Keep matching values |
| `.remove(&block)` | Remove matching values (history available via `\|v, history\|`) |
| `.with(*series, on_restart: nil, isolate_values: nil, **key_series, &block)` | Combine with other series |
| `.hashify(*keys)` | Convert array values to hash |
| `.repeat(times, condition: nil)` / `.autorestart` | Repeat n times / restart indefinitely |
| `.reverse` | Reverse order (finite series only) |
| `.randomize(random: nil)` | Shuffle order |
| `.merge` / `.flatten` | Flatten nested series |
| `.cut(length)` | Split into chunks (serie of series) |
| `.max_size(n)` | Limit to n values |
| `.skip(n)` | Skip first n values |
| `.shift(n)` | Circular rotation |
| `.after(*series)` | Append series after current |
| `.switch(*indexed, **hash)` / `.multiplex(*indexed, **hash)` | Switch between series |
| `.buffered(sync: false)` | Enable multiple independent readers |
| `.quantize(reference: nil, step: nil, value_attribute: nil, stops: nil, predictive: nil, left_open: nil, right_open: nil)` | Quantize time-value pairs |
| `.lock` | Freeze values |
| `.anticipate(&block)` | Look-ahead evaluation |
| `.lazy(&block)` | Lazy evaluation |
| `.process_with(**params, &processor)` | Process with transcriptor pipeline |
| `.compact_timed` | Remove nil entries from timed series |
| `.flatten_timed` | Decompose timed hash values |

### BufferSerie (independent readers)

```ruby
melody = S(60, 64, 67).buffered    # or .buffered(sync: true) for synchronized restart
voice1 = melody.buffer.i           # independent reader
voice2 = melody.buffer.i           # independent reader
voice1.next_value  # => 60
voice2.next_value  # => 60 (independent)
```

## Neumas / Neumalang

### Notation Format

```
(grade octave duration velocity ornament)
```

| Component | Values | Example |
|---|---|---|
| Grade | `0`, `+2`, `-1` (absolute or relative) | `(0)`, `(+2)`, `(-3)` |
| Octave | `o0`, `o1`, `o-1` | `(0 o1 1 mf)` |
| Duration | multiples of base_duration (e.g., `base_duration: 1/4r` → `1`=quarter, `2`=half, `1/2`=eighth, `1/4`=sixteenth) | `(0 1/2)` |
| Velocity | `ppp pp p mp mf f ff fff` | `(0 1 mf)` |
| Relative vel | `+f +ff -p -pp` | `(0 1 +f)` |
| Ornaments | `tr` (trill), `mor` (mordent), `turn`, `st` (staccato) | `(0 1 mf tr)` |
| Silence | `(silence duration)` | `(silence 1)` |
| Parallel | `\|` operator between voices | `voice1 \| voice2` |

### Parsing and Decoding

```ruby
using Musa::Extension::Neumas   # file-scoped

# String to neumas (refinement)
neumas = '(0 1 mf) (+2 1) (+4 2 p)'.to_neumas

# Parallel voices via | operator
song = "(0 1 mf) (+2 1 mp)" | "(+7 2 p) (+5 1 mp)"

# Parser with decoder
serie = Neumalang.parse('(0 1 mf) (+2 1)', decode_with: decoder)

# NeumaDecoder constructor
decoder = Decoders::NeumaDecoder.new(scale, base_duration: 1/4r)
decoder = Decoders::NeumaDecoder.new(scale, base_duration: 1/4r, transcriptor: transcriptor)

# Play with sequencer (neumalang mode)
play neuma_serie, decoder: decoder, mode: :neumalang do |gdv|
  pdv = gdv.to_pdv(scale)
  voice.note pitch: pdv[:pitch], velocity: pdv[:velocity], duration: pdv[:duration]
end
```

## Sequencer DSL

### Scheduling Methods

```ruby
# Absolute positioning — bar_position is Numeric, Array, or Serie
at bar_position, debug: false do ... end      # returns EventHandler (control)

# Relative positioning — bars_delay is Numeric, Array, or Serie
wait bars_delay, debug: false do ... end      # returns EventHandler

# Immediate (next tick)
now do ... end                                # returns EventHandler

# Recurring
every interval,                               # interval nil = once
      duration: nil, till: nil,
      condition: nil,
      on_stop: nil, after_bars: nil, after: nil do |control:|
  # control: is optional keyword
end

# Series playback
play serie,
     mode: :wait,           # :wait (default), :at, :neumalang
     parameter: nil,        # wrap element in hash key
     on_stop: nil, after_bars: nil, after: nil,
     context: nil,          # additional DSL context hash
     **mode_args do |key1:, key2:, control:|
  # hash keys become keywords; control: optional
end
play serie, mode: :at do |note:, at:| ... end   # OFF BY ONE, see pitfall 13
play serie, mode: :neumalang, decoder: decoder do |gdv| ... end

# Timed series (elements carry :time attribute)
play_timed timed_serie,
           at: nil,                           # starting position (default: current)
           on_stop: nil, after_bars: nil, after: nil do |values, time:, started_ago:, control:|
end

# Value animation
move every: interval,
     from: start, to: finish,
     step: nil,              # value increment per step
     duration: nil, till: nil,
     function: nil,          # proc mapping [0..1]->[0..1]; default linear
     right_open: nil,        # exclude final value
     on_stop: nil, after_bars: nil, after: nil do |value, next_value, control:, duration:, quantized_duration:, started_ago:, position_jitter:, duration_jitter:|
end

# Hash / multi-parameter move
move every: 1/4r,
     from: { p: 60, v: 80 }, to: { p: 72, v: 100 },
     duration: 2r do |values|
  values[:p]  # hash mode
end

# Events
on :event_name, name: nil, only_once: nil do |param1, param2| ... end
launch :event_name, param1, param2
```

### Control Objects

All scheduling methods return a control object supporting `.stop`.

| Callback | When it fires |
|---|---|
| `on_stop { }` | Always: manual stop, natural end, duration/till reached, condition failed |
| `after { }` / `after(bars) { }` | Only on natural termination (NOT on manual `.stop`) |

```ruby
ctrl = every 1r, duration: 8r do ... end
ctrl.on_stop { cleanup }
ctrl.after { launch :next_section }  # only if duration completes naturally
ctrl.stop   # triggers on_stop, NOT after

# Parameter form also works:
every 1r, on_stop: proc { cleanup }, after: proc { continue } do ... end
```

### SmartProcBinder

Blocks declare only the parameters they need; undeclared ones are silently ignored. Keywords must be declared as keyword args (`|control:|` not `|control|`).

| Method | Positional params | Keyword params |
|---|---|---|
| `every` | — | `control:` |
| `play` | element (hash keys as keywords) | `control:` |
| `move` | value, next_value | `control:`, `duration:`, `quantized_duration:`, `started_ago:`, `position_jitter:`, `duration_jitter:`, `right_open:` |
| `play_timed` | values (extra attrs as keywords) | `time:`, `started_ago:`, `control:` |

### `position`

`position` returns current sequencer position in bars (Rational). Available inside any DSL block.

## Scales & Music

### Scale Construction

```ruby
tuning = Scales.et12[440.0]             # 12-TET, A=440Hz
scale  = tuning.major[60]               # C major rooted at MIDI 60
scale  = Scales.et12[440.0].minor[69]   # A minor
tuning = Scales.default_system.default_tuning  # default (A=440, et12)
```

### Available Scale Kinds (35+)

| Family | Scales |
|---|---|
| Diatonic | `major`, `minor`, `minor_harmonic`, `major_harmonic` |
| Greek modes | `dorian`, `phrygian`, `lydian`, `mixolydian`, `locrian` |
| Pentatonic | `pentatonic_major`, `pentatonic_minor` |
| Blues | `blues`, `blues_major` |
| Symmetric | `whole_tone`, `diminished_hw`, `diminished_wh` |
| Melodic minor | `minor_melodic`, `dorian_b2`, `lydian_augmented`, `lydian_dominant`, `mixolydian_b6`, `locrian_sharp2`, `altered` |
| Ethnic | `double_harmonic`, `hungarian_minor`, `phrygian_dominant`, `neapolitan_minor`, `neapolitan_major` |
| Bebop | `bebop_dominant`, `bebop_major`, `bebop_minor` |
| Chromatic | `chromatic` |

### Note Access

```ruby
scale[0]                  # NoteInScale at grade 0
scale[4]                  # grade 4
scale.tonic               # tonic (grade 0)
scale.dominant            # dominant (grade 4)
scale[:I], scale[:V]      # Roman numeral access
note.pitch                # MIDI pitch number
note.frequency            # Hz
note.sharp / note.flat    # chromatic alterations (+/-1 semitone)
note.sharp(7)             # +7 semitones
note.at_octave(1)         # transpose up 1 octave
```

### Chords

```ruby
chord = scale.tonic.chord              # triad from scale degree
chord = scale[0].chord(:seventh)       # 7th chord
chord = scale.chord_on(0)              # equivalent to scale[0].chord
chord = scale.chord_on(:dominant, :seventh)
chord = scale.chord_on(:IV, :seventh, :major, move: {root: -1})

chord.pitches             # => [60, 64, 67]
chord.notes               # Array of ChordGradeNote
chord.root / .third / .fifth / .seventh
chord.quality             # => :major
chord.size                # => :triad

# Modifications
chord.with_quality(:minor)
chord.with_size(:ninth)
chord.with_move(root: -1, fifth: 1)           # voicing: move tones to octaves
chord.with_duplicate(root: -2, third: [-1,1]) # double tones
chord.octave(-1)                               # transpose down octave

# Chord-Scale navigation
scale.contains_chord?(chord)            # => true/false
scale.degree_of_chord(chord)            # => degree (0-based) or nil
chord.search_in_scales(family: :diatonic)  # find scales containing chord
chord.search_in_scales(brightness: -1..1)
chord.as_chord_in_scale(other_scale)    # recontextualize
```

### Scale Metadata

```ruby
tuning.major.class.metadata               # combined metadata hash
tuning.major.class.intrinsic_metadata     # structure-derived only
tuning.major.class.base_metadata          # library-defined only
tuning.major.class.custom_metadata        # user-added only
tuning.scale_kinds(family: :diatonic)     # filter scale kinds
tuning.scale_kinds(brightness: -1..1)     # by brightness range
tuning.scale_kinds { |k| k.intrinsic_metadata[:has_leading_tone] }
Scales.extend_metadata(:dorian, mood: :dark)  # add custom metadata
```

| Metadata key | Values |
|---|---|
| `family` | `:diatonic`, `:greek_modes`, `:melodic_minor_modes`, `:pentatonic`, `:blues`, `:bebop`, `:symmetric`, `:ethnic`, `:chromatic` |
| `brightness` | -3 (Locrian/very dark) to +3 (Lydian augmented/very bright); major = 0 |
| `has_leading_tone` | boolean |
| `has_tritone` | boolean |
| `symmetric` | `:equal`, `:palindrome`, `:repeating`, or nil |

## Generative Tools

### Markov Chains

```ruby
markov = Musa::Markov::Markov.new(
  start: 0,
  finish: :end,        # optional; nil = infinite
  transitions: {
    0 => { 2 => 0.5, 4 => 0.3, 7 => 0.2 },
    7 => { 0 => 0.6, :end => 0.4 }
  },
  random: nil          # optional Random object for reproducibility
)
melody = markov.i.to_a  # serie; terminates at :end state
```

Transitions support: weighted hash `{ state => prob }`, array (equiprobable), or proc `{ |history| ... }`.

### Variatio (Cartesian product)

```ruby
variatio = Musa::Variatio::Variatio.new(:name) do
  field :root, [60, 64, 67]
  field :type, [:major, :minor]
  fieldset :env, nil do          # nested field group
    field :attack, [0.1, 0.5]
  end
  constructor do |root:, type:, env:| { root: root, type: type } end
  with_attributes do |obj, root:, type:|  end  # optional post-processing
  finalize do |obj| obj end                    # optional final transform
end

all     = variatio.run            # => all combinations
limited = variatio.on(root: [60]) # override at runtime
```

### Rules (L-system production)

```ruby
rules = Musa::Rules::Rules.new do
  7.times do                        # N grow rules = N tree levels
    grow 'add note' do |melody, max_interval:|
      last = melody.last
      (-max_interval..max_interval).each do |iv|
        branch melody + [last + iv] if (last + iv).between?(48, 84)
      end
    end
  end
  cut 'no repeat' do |melody| prune if melody.size >= 2 && melody[-1] == melody[-2] end
  ended_when do |melody| melody.size == 8 end
end

tree     = rules.apply([[60]], max_interval: 4)  # seed [[value]] prevents flattening
melodies = tree.combinations.map(&:last)         # all valid complete paths
endpoints = tree.fish                            # valid endpoint objects only
```

Key: each `grow` = 1 tree level. Use object accumulation for state (not `history`). `history` is always `[]` with single seed.

### GenerativeGrammar

```ruby
include Musa::GenerativeGrammar

a = N('a', size: 1)          # terminal node with attributes
b = N('b', size: 1)
p = PN()                     # proxy node for recursive grammars

d       = a | b              # alternative (OR)
grammar = (a | d).repeat(3) + N('c')   # sequence + repeat
grammar = (a | d).repeat(min: 1, max: 4)

grammar.options(content: :join)    # => ["aaac", ...] as strings
grammar.options(content: :itself)  # => arrays of nodes (default)
grammar.options(raw: true)         # => OptionElement objects with attributes
grammar.options { |o| o.sum(...) <= 3 }  # filtered

# Filtering by attribute
grammar.limit { |o| o.collect { |e| e.attributes[:size] }.sum <= 3 }

# Proxy for recursion
proxy = PN()
proxy.proxy_source = a + (proxy | N('end'))
```

### Darwin (evolutionary selection)

```ruby
darwin = Musa::Darwin::Darwin.new do
  measures do |obj|
    die if obj[:interval] > 12           # eliminate non-viable
    feature :stepwise if obj[:interval] <= 2   # boolean feature
    dimension :size, -obj[:interval].to_f      # numeric (normalized 0-1)
  end
  weight stepwise: 1.5, size: 2.0        # positive = favor, negative = penalize
end
ranked = darwin.select(candidates)        # sorted best-first; died objects excluded
best   = ranked.first
```

## Datasets

### Core Types

| Module | Natural Keys | Purpose |
|---|---|---|
| `GDV` | grade, sharps, octave, velocity, silence + AbsD | Scale-degree notation |
| `PDV` | pitch, velocity + AbsD | MIDI-style absolute pitch |
| `GDVd` | delta encoding of GDV | Compression / incremental encoding |
| `AbsD` | duration, note_duration, forward_duration | Duration container |
| `V` | (array) | Value arrays |
| `PackedV` | (hash) | Key-value pairs |
| `P` | [value, duration, value, ...] | Point series |
| `PS` | from, to, duration, right_open | Parameter segments |
| `Score` | time-indexed container | Event organization |

### Conversions

```ruby
gdv = { grade: 0, duration: 1r, velocity: 0 }.extend(GDV)
pdv = gdv.to_pdv(scale)      # => { pitch: 60, duration: 1r, velocity: 64 }
gdv2 = pdv.to_gdv(scale)     # reverse

gdvd1 = gdv.to_gdvd(scale)                   # absolute (first note)
gdvd2 = gdv2.to_gdvd(scale, previous: gdv)   # delta (subsequent)

neuma_str = gdv.to_neuma     # requires gdv.base_duration to be set

# P → PS segments
p = [60, 4, 64, 8, 67].extend(P)
p.base_duration = 1/4r
ps_serie = p.to_ps_serie

# P → AbsTimed
timed = p.to_timed_serie(base_duration: 1/4r, time_start: 0r)
```

### Duration Fields (AbsD)

| Field | Purpose | Default |
|---|---|---|
| `:duration` | Total event time | Required |
| `:note_duration` | Actual sound length (staccato/legato) | = duration |
| `:forward_duration` | Time until next event starts | = duration |

### Score

```ruby
score = Score.new
score.at(1r, add: { pitch: 60, duration: 1r }.extend(PDV))
score.at(2r)                           # retrieve events at time
score.size                             # number of time slots
score.positions                        # all time positions
score.duration                         # total duration
score.between(1r, 4r)                  # events overlapping [1r, 4r)
score.changes_between(0r, 4r)          # note-on/note-off timeline
score.values_of(:pitch)                # Set of unique attribute values
score.subset { |e| e[:pitch] > 60 }    # filtered Score
score.each { |time, events| ... }
score.to_h
```

## Transcription

### MIDI Transcriptor (ornament expansion)

```ruby
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMIDI.transcription_set(duration_factor: 1/6r),
  base_duration: 1/4r, tick_duration: 1/96r
)
# Ornaments expanded to note sequences: tr (trill), mor (mordent), turn, st (staccato)
# Use with decoder: Decoders::NeumaDecoder.new(scale, base_duration: 1/4r, transcriptor: transcriptor)
# Or manually: transcriptor.transcript(gdv)  => array of GDV
```

### MusicXML Transcriptor (ornament preservation)

```ruby
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMusicXML.transcription_set,
  base_duration: 1/4r, tick_duration: 1/96r
)
# Preserves ornaments as MusicXML notation symbols instead of expanding them
```

## MIDI

### MIDIVoices

```ruby
voices = MIDIVoices.new(sequencer: transport.sequencer, output: output, channels: [0, 1, 2])
voice  = voices.voices[0]

# note signature: positional pitch OR keyword pitch:
voice.note(60, velocity: 100, duration: 1/4r)             # positional pitch
voice.note pitch: 60, velocity: 100, duration: 1/4r       # keyword pitch
voice.note pitch: [60, 64, 67], velocity: 90, duration: 1r  # chord
voice.note pitch: 60, velocity: 80, duration: 100r,         # duration: nil RAISES, see pitfall 12
             note_duration: nil, duration_offset: nil,      # articulation overrides
             velocity_off: 64

# Manual note off: hold with a duration longer than the passage and release early
note_ctrl = voice.note(pitch: 64, velocity: 80, duration: 100r)
note_ctrl.on_stop { puts "Note ended!" }
note_ctrl.note_off(velocity: 64)

voice.all_notes_off

voice.controller[:mod_wheel] = 64     # CC by symbol
voice.controller[7] = 100             # CC by number
voice.sustain_pedal = 127
voice.sustain_pedal                    # current value

voices.fast_forward = true    # silent catch-up (no MIDI output)
voices.fast_forward = false
voices.panic(reset: false)    # all notes off
```

Controller symbols: `:mod_wheel` (1), `:breath` (2), `:volume` (7), `:expression` (11), `:general_purpose_1..4` (16-19), `:sustain_pedal` (64), `:portamento` (65). LSB variants with `_lsb` suffix.

### MIDIRecorder

```ruby
recorder = Musa::MIDIRecorder::MIDIRecorder.new(sequencer)
input.on_message { |bytes| recorder.record(bytes) }
# After recording:
notes = recorder.transcription
# => [{ position:, channel:, pitch:, velocity:, duration:, velocity_off: }]
# pitch may be :silence for gaps
raw = recorder.raw    # array of timestamped raw events
recorder.clear
```

### MIDICommunications (separate gem)

```ruby
output = MIDICommunications::Output.gets               # interactive selection
input  = MIDICommunications::Input.gets
output = MIDICommunications::Output.all.first          # programmatic
input  = MIDICommunications::Input.find_by_name('Name')
```

## Transport & Clocks

### Clock Types

| Clock | Constructor | Activation | Use Case |
|---|---|---|---|
| `TimerClock` | `TimerClock.new(bpm:, ticks_per_beat:)` | External: `clock.start` from another thread | Standalone |
| `InputMidiClock` | `InputMidiClock.new(midi_input)` | External: waits for MIDI Start (0xFA) | DAW sync |
| `ExternalTickClock` | `ExternalTickClock.new` | Manual: call `clock.tick()` per tick | Testing |
| `DummyClock` | `DummyClock.new(tick_count)` | Automatic: starts immediately | Unit tests |

Clock common API: `.stop` (idempotent, fires on_stop callbacks), `.terminate` (stop + exit run loop).

`TimerClock` additional API: `.start`, `.pause`, `.continue`, `.bpm=`, `.started?`, `.paused?`

### Transport

```ruby
transport = Transport.new(clock, beats_per_bar, ticks_per_beat)
transport.sequencer            # access sequencer
transport.start                # blocks while running
transport.stop                 # terminates clock, triggers shutdown sequence

# Lifecycle callbacks
transport.before_begin { |seq| }         # once before first start (init)
transport.on_start { |seq| }             # each start
transport.after_stop { |seq| }           # on stop
transport.on_change_position { |seq| }  # on seek/jump

# Position seek (fast-forwards through intermediate events)
transport.change_position_to(bars: 8)
transport.change_position_to(beats: 16)
transport.change_position_to(midi_beats: 32)
```

Shutdown sequence: `stop` → `clock.terminate` → `after_stop` callbacks → sequencer reset → `before_begin` (prepare restart).

## Matrix

```ruby
using Musa::Extension::Matrix

# Matrix -> P format: [time, param1, param2, ...] rows
gesture = Matrix[[0, 60, 100], [0.5, 62, 110], [1, 64, 120]]
p_seq = gesture.to_p(time_dimension: 0, keep_time: false)
# => [[[60, 100], 0.5, [62, 110], 0.5, [64, 120]]]

# Condensation: Array of connected matrices merges into single P
[matrix1, matrix2].to_p(time_dimension: 0)

# condensed_matrices: extract connected sub-matrices
matrix.condensed_matrices
```

## MusicXML Builder

```ruby
score = Musa::MusicXML::Builder::ScorePartwise.new do
  work_title "Title"
  work_number 1
  creators composer: "Name"
  encoding_date DateTime.now

  part :p1, name: "Piano", abbreviation: "Pno." do
    measure do
      attributes do
        divisions 4               # per quarter note
        key 1, fifths: 0          # C major (1 = staff number)
        time 1, beats: 4, beat_type: 4
        clef 1, sign: 'G', line: 2
        clef 2, sign: 'F', line: 4   # bass clef staff 2
      end
      metronome beat_unit: 'quarter', per_minute: 120
      direction { dynamics 'f'; wedge 'crescendo' }
      direction wedge: 'stop', dynamics: 'ff'

      pitch 'C', octave: 4, duration: 4, type: 'quarter'
      pitch 'E', octave: 4, duration: 4, type: 'quarter', alter: 1  # E#
      pitch 'G', octave: 4, duration: 4, type: 'quarter', dots: 1, slur: 'start'
      rest duration: 4, type: 'quarter'

      backup 16   # return to measure start for second voice/staff
      pitch 'C', octave: 3, duration: 16, type: 'whole', staff: 2, voice: 2
    end
  end
end

File.write("score.musicxml", score.to_xml.string)
File.open("score.musicxml", 'w') { |f| score.to_xml(f) }

# Constructor style (equivalent)
score = Musa::MusicXML::Builder::ScorePartwise.new(work_title: "Title", ...)
part  = score.add_part(:p1, name: "Piano")
meas  = part.add_measure(divisions: 4)
meas.attributes.last.add_key(1, fifths: 0)
meas.add_pitch(step: 'C', octave: 4, duration: 4, type: 'quarter')
```

Key parameters: `staff:` (grand staff), `voice:` (polyphony), `alter:` (accidentals: -1 flat, 1 sharp), `dots:`, `slur:` (start/stop).

## Core Extensions

| Extension | Usage | Purpose |
|---|---|---|
| `Musa::Extension::Neumas` | `using` (refinement) | `.to_neumas` on strings; `\|` for parallel voices |
| `Musa::Extension::Matrix` | `using` (refinement) | `Matrix#to_p`, `Array#to_p` |
| `Musa::Extension::Arrayfy` | `using` (refinement) | `.arrayfy` normalizes to array |
| `Musa::Extension::Hashify` | `using` (refinement) | `.hashify(*keys)` array/hash → hash |
| `Musa::Extension::DeepCopy` | `using` (refinement) | `.deep_copy` with singleton module preservation |
| `Musa::Extension::ExplodeRanges` | `using` (refinement) | `.explode_ranges` expands Range in arrays |
| `Musa::Extension::SmartProcBinder` | `using` (refinement) | Flexible proc parameter binding |
| `Musa::Extension::With` | `using` (refinement) | DSL block context switching |
| `Musa::Extension::AttributeBuilder` | `include` | DSL builder macros (`attribute :name`) |

### Logger

```ruby
logger = Musa::Logger.new(
  sequencer: sequencer,
  level: :debug,
  position_format_integer_digits: 3,
  position_format_decimal_digits: 3
)
# Output: "  1.000: [INFO] message"
# Levels: debug, info, warn, error, fatal
```

## REPL (Live Coding)

```ruby
# TCP server on port 1327 for live code evaluation
# Start inside sequencer DSL context to expose DSL methods to editor
transport.sequencer.with do
  @repl = Musa::REPL::REPL.new(binding)
end
transport.start

# Protocol (line-based TCP):
#   #path → filepath → #begin → code lines → #end
#   Server responds: //echo … //end, //error … //end
# Clients: MusaLCEClientForVSCode (TCP/1327)
#          MusaLCEforBitwig, MusaLCEforLive (via musalce-server)
```

`musalce-server` CLI: `musalce-server bitwig` or `musalce-server live` — wraps REPL with DAW-specific MIDI routing.

## Supporting Gems

| Gem | Module | Purpose |
|---|---|---|
| `midi-communications` | `MIDICommunications` | Cross-platform MIDI I/O |
| `midi-events` | `MIDIEvents` | MIDI event objects (`NoteOn`, `NoteOff`, `ChannelMessage`) |
| `midi-parser` | `MIDIParser` | Parse raw MIDI bytes to event objects |
| `musalce-server` | — | Live coding server for Bitwig/Live (CLI: `musalce-server bitwig\|live`) |

## Common Pitfalls

Every entry below is demonstrated by an example in `musa-dsl/spec/reference_pitfalls_spec.rb`, named after the entry. A warning with no spec behind it is a conjecture with typography, so it does not go here — and three of the warnings this list used to carry were false.

1. **`using Musa::Extension::Neumas` is file-scoped.** Declaring it in `main.rb` does NOT make `.to_neumas` available in `score.rb`. Declare it in every file that uses it. *(spec: "refinements are file-scoped")*

2. **Series are lazy, and a prototype cannot be read.** Series have no `.each`. Call `.i` for an instance, then `.next_value`, or hand the serie to `play`. Note that `.to_a` **restarts** the instance rather than continuing from where `next_value` left off. *(spec: "a serie is lazy")*

3. **Neuma durations are multiples of `base_duration`, never fractions of a bar.** With `base_duration: 1/4r`, `1` is a quarter; with `base_duration: 1r`, the same `1` is a whole bar. *(spec: "neuma durations are multiples of base_duration")*

4. **Use Rational for timing.** A Float position is rounded to the nearest tick: `at(1.3)` fires at `125/96r`. Prefer `1/4r`, `1r`, `3/4r`. *(spec: "a Float position is quantised to the tick grid")*

5. **Ornaments need a Transcriptor, and are silent without one.** The annotation survives on the event — `tr: true` is still there — and nothing acts on it: two events instead of five. Apply the transcriptor with `.process_with { |gdv| transcriptor.transcript(gdv) }`. *(spec: "without a transcriptor an ornament survives as an annotation")*

6. **`after` fires only on natural completion; `on_stop` fires on any ending.** Use `on_stop` for cleanup that must always run, `after` for chaining sections. *(spec: "after fires on natural completion, on_stop on any ending")*

7. **MIDI channels are 0-indexed (0–15)**, not 1–16. *(spec: "MIDI channels are 0-indexed")*

8. **`play` in its default `:wait` mode needs a `:duration` on every element.** Without it, every element fires in the same instant AND the control never completes, so neither `after` nor `on_stop` ever runs — a section chained with `after` stops the chain in silence. See musa-dsl issue #72. *(spec: "play in its default mode needs a :duration")*

9. **`RND()` is a shuffle, not a die.** Each value is drawn once and removed, so it yields a random permutation and then ends: `RND(1..6)` gives six values and `nil` on the seventh, and `infinite?` is false. Sampling with replacement is `RND(...).repeat`, which reshuffles each pass and IS infinite. *(spec: "RND is a shuffle that exhausts")*

10. **`FIBO()` starts at 1**: 1, 1, 2, 3, 5, 8, 13… Its seeds are its first two values, so `FIBO(0, 1)` gives the version with the leading zero and `FIBO(a, b)` yields a, b, a+b, … *(spec: "FIBO starts at 1")*

11. **`move` takes `every:` as a keyword**, not positionally. `move(every: 1/4r, from: 0, to: 127, duration: 4r)`; the positional form raises ArgumentError. *(spec: "move takes every: as a keyword")*

12. **`duration: nil` does not give an indefinite note — it raises.** `MIDIVoice#note` computes a note duration from it unconditionally. Until musa-dsl issue #81 is resolved, hold a note with a duration longer than the passage and release it early with `note_off`. *(spec: "the indefinite note the reference offers cannot be created")*

13. **`mode: :at` is off by one element.** An element's `:at` schedules when the NEXT element is evaluated, not when that element plays: declared at 1, 5 and 9, the notes fire immediately, at bar 1 and at bar 5. An `:at` in the past silently ends the serie. See musa-dsl issue #82; prefer the default `:wait` mode with durations until it is fixed.

### Removed from this list

Kept here so they are not reintroduced from an older copy:

- ~~"Series constructors are not available inside DSL blocks"~~ — they are. `S()`, `H()` and the rest work inside `sequencer.with do … end`. *(spec: "series constructors DO work inside a DSL block")*
- ~~"`RND()` is infinite (never exhausts)"~~ — the opposite; see 9.
- ~~"`duration: nil` means indefinite"~~ — it raises; see 12.
- The two Rules entries (`history` always `[]`, seed with `[[value]]`) described behaviour of an algorithm whose documentation and implementation disagree — musa-dsl issue #73. They return when that is decided.

## Demo Index

| # | Topic | Key Concepts |
|---|---|---|
| 00 | Template | Setup pattern, slave clock, hot-reload, Transcriptor |
| 01 | Hello Musa | `Scales.et12`, `TimerClock`, `at`, `MIDIVoices` |
| 02 | Series Explorer | `S`, `FOR`, `RND`, `FIBO`, `HARMO`, `H`, `.map`, `.repeat` |
| 03 | Canon | `.buffered`, `.buffer`, independent readers, `wait` |
| 04 | Neumas | `.to_neumas`, ornaments, `NeumaDecoder`, `Transcriptor`, `on`/`launch` |
| 05 | Markov | `Markov.new`, weighted/equiprobable/dynamic transitions, `H()` |
| 06 | Variatio | `Variatio.new`, `field`, `constructor`, `.run`, `.on()` |
| 07 | Scale Navigator | 40+ scales, modes, metadata, `brightness`, chord access |
| 08 | Voice Leading | `Rules.new`, `grow`, `cut`, `ended_when`, `.apply`, `.combinations` |
| 09 | Darwin | `Darwin.new`, `measures`, `feature`, `dimension`, `die`, `weight`, `.select` |
| 10 | Grammar | `N()`, `PN()`, `\|`, `+`, `.repeat`, `.limit`, `.options` |
| 11 | Matrix | `Matrix#to_p`, Hadamard product, condensation, `play_timed` |
| 12 | DAW Sync | `InputMidiClock`, `on_start`, `after_stop`, MIDI clock |
| 13 | Live Coding | `InputMidiClock`, `every`, hot-reload, REPL/MusaLCE |
| 14 | Clock Modes | `TimerClock` vs `InputMidiClock`, master vs slave |
| 15 | OSC SuperCollider | OSC client, granular synthesis control |
| 16 | OSC Max/MSP | OSC server/client, reactive sequencing |
| 17 | Event Architecture | `on`/`launch`, `control.after`, section chaining |
| 18 | Parameter Automation | `SIN()`, `move`, CC automation, PRIMES |
| 19 | Advanced Series | `H()`, `.eval`, `.shift`, nested series, Fibonacci palindromes |
| 20 | Neuma Files | `.neu` files, variables, `Neumalang.parse_file`, ornaments pipeline |
| 21 | Fibonacci Episodes | Multi-threading, `FIBO`, episode tracking, `control.after` |
| 22 | Multi-Phase | Phase-based composition, state management, conditional canons |
