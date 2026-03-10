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
include Musa::All            # All modules at once
include Musa::Series         # Series constructors + operations
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

output = MIDICommunications::Output.gets       # interactive MIDI output selection
clock_input = MIDICommunications::Input.gets   # for MIDI sync (slave mode)

# Clock options (pick one):
clock = InputMidiClock.new(clock_input)                          # DAW sync (slave)
clock = TimerClock.new(bpm: 120, ticks_per_beat: 24)             # internal (master)
clock = DummyClock.new(ticks)                                     # testing
clock = ExternalTickClock.new                                     # manual control

transport = Transport.new(clock, 4, 24)  # beats_per_bar, ticks_per_beat
scale = Scales.et12[440.0].major[60]     # 12-TET, A=440, C major at MIDI 60

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
| `FOR` | `FOR(from: 0, to: nil, step: 1)` | Numeric range; step sign auto-adjusted |
| `MERGE` | `MERGE(*series)` | Sequential concatenation |
| `RND` | `RND(*values, from:, to:, step:, random:)` | Random infinite (array or range mode) |
| `RND1` | `RND1(*values, from:, to:, step:, random:)` | Single random value then exhausts |
| `SIN` | `SIN(start_value:, steps:, amplitude: 1.0, center: 0.0)` | Sine wave; finite (steps iterations) |
| `FIBO` | `FIBO()` | Fibonacci: 0, 1, 1, 2, 3, 5, 8... (infinite) |
| `HARMO` | `HARMO(error: 0.5, extended: false)` | Harmonic series as MIDI semitones (infinite) |
| `NIL` | `NIL()` | Always returns nil |
| `UNDEFINED` | `UNDEFINED()` | Placeholder (undefined state) |
| `TIMED_UNION` | `TIMED_UNION(*series)` or `TIMED_UNION(**named)` | Merge timed series by time |

### Operations (chainable on any serie)

| Operation | Description |
|---|---|
| `.i` | Create instance (required before iterating) |
| `.next_value` | Get next value (on instance) |
| `.to_a` / `.to_a(limit: n)` | Collect all values (use limit for infinite series) |
| `.map { \|v\| }` | Transform each value |
| `.select { \|v\| }` | Keep matching values |
| `.remove { \|v, history\| }` | Remove matching values (history available) |
| `.with(*series, &block)` | Combine with other series |
| `.hashify(*keys)` | Convert array values to hash |
| `.repeat(n)` / `.autorestart` | Repeat n times / restart indefinitely |
| `.reverse` | Reverse order (finite series only) |
| `.randomize(random:)` | Shuffle order |
| `.merge` / `.flatten` | Flatten nested series |
| `.cut(length)` | Split into chunks (serie of series) |
| `.max_size(n)` | Limit to n values |
| `.skip(n)` | Skip first n values |
| `.shift(n)` | Circular rotation |
| `.after(*series)` | Append series after current |
| `.buffered` | Enable multiple independent readers |
| `.quantize(step:, predictive:)` | Quantize time-value pairs |
| `.lock` | Freeze values |
| `.anticipate(&block)` | Look-ahead evaluation |
| `.compact_timed` | Remove nil entries from timed series |
| `.flatten_timed` | Decompose timed hash values |
| `.process_with { \|v\| }` | Process with transcriptor pipeline |

### BufferSerie (independent readers)

```ruby
melody = S(60, 64, 67).buffered
voice1 = melody.buffer.i   # independent reader
voice2 = melody.buffer.i   # independent reader
voice1.next_value  # => 60
voice2.next_value  # => 60 (independent)
```

## Neumas / Neumalang

### Notation Format

```
(grade duration velocity ornament)
```

| Component | Values | Example |
|---|---|---|
| Grade | `0`, `+2`, `-1` (absolute or relative) | `(0)`, `(+2)`, `(-3)` |
| Octave | `o0`, `o1`, `o-1` | `(0 o1 1 mf)` |
| Duration | multiples of base_duration: `2`=half, `1`=quarter, `1/2`=eighth | `(0 1/2)` |
| Velocity | `ppp pp p mp mf f ff fff` | `(0 1 mf)` |
| Relative vel | `+f +ff -p -pp` | `(0 1 +f)` |
| Ornaments | `tr` (trill), `mor` (mordent), `turn`, `st` (staccato) | `(0 1 mf tr)` |
| Silence | `(silence duration)` | `(silence 1)` |
| Parallel | `\|` operator between voices | `voice1 \| voice2` |

### Parsing and Decoding

```ruby
using Musa::Extension::Neumas

# String to neumas (refinement)
neumas = '(0 1 mf) (+2 1) (+4 2 p)'.to_neumas

# Parser with decoder
serie = Neumalang.parse('(0 1 mf) (+2 1)', decode_with: decoder)

# NeumaDecoder
decoder = Decoders::NeumaDecoder.new(scale, base_duration: 1/4r)
decoder = Decoders::NeumaDecoder.new(scale, base_duration: 1/4r, transcriptor: transcriptor)

# Play with sequencer
play neuma_serie, decoder: decoder, mode: :neumalang do |gdv|
  pdv = gdv.to_pdv(scale)
  voice.note pitch: pdv[:pitch], velocity: pdv[:velocity], duration: pdv[:duration]
end
```

## Sequencer DSL

### Scheduling Methods

```ruby
# Absolute positioning
at position do ... end                    # returns control
at [1, 3, 5] do ... end                  # series of positions

# Relative positioning
wait duration do ... end                  # relative to current position

# Immediate
now do ... end

# Recurring
every interval, duration: d, till: t, condition: proc, on_stop: proc, after: proc do |control:|
  # control: is optional keyword
end

# Series playback (default mode: :wait)
play serie, mode: :wait, on_stop: proc, after: proc do |key1:, key2:, control:|
  # hash keys become keywords; control: optional
end
play serie, mode: :at do |key:, at:| ... end
play serie, mode: :neumalang, decoder: decoder do |gdv| ... end

# Timed series
play_timed timed_serie, on_stop: proc, after: proc do |values, time:, started_ago:, control:|
end

# Value animation
move from: 0, to: 127, duration: 4, every: 1/4r, on_stop: proc, after: proc do |value, next_value, control:, duration:|
end
move from: { p: 60, v: 80 }, to: { p: 72, v: 100 }, duration: 2, every: 1/4r do |values|
  values[:p]  # hash mode
end

# Events
on :event_name do |param1, param2| ... end
launch :event_name, param1, param2
```

### Control Objects

All scheduling methods return a control object supporting `.stop`.

| Callback | When it fires |
|---|---|
| `on_stop { }` | Always (manual stop, natural end, duration reached, condition failed) |
| `after { }` / `after(bars) { }` | Only on natural termination (NOT on manual `.stop`) |

```ruby
ctrl = every 1r, duration: 8r do ... end
ctrl.on_stop { cleanup }
ctrl.after { launch :next_section }  # only if duration completes naturally
ctrl.stop  # triggers on_stop, NOT after
```

### SmartProcBinder

Blocks declare only the parameters they need. Undeclared parameters are silently ignored. Keywords must be declared as keyword args (`|control:|` not `|control|`).

### position

`position` returns current sequencer position in bars (Rational). Available inside any DSL block.

## Scales & Music

### Scale Construction

```ruby
tuning = Scales.et12[440.0]            # 12-TET, A=440Hz
scale = tuning.major[60]               # C major rooted at MIDI 60
scale = Scales.et12[440.0].minor[69]   # A minor
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
scale.dominant             # dominant (grade 4)
scale[:I], scale[:V]      # Roman numeral access
note.pitch                # MIDI pitch number
note.frequency            # Hz
note.sharp / note.flat    # chromatic alterations
note.sharp(7)             # +7 semitones
note.at_octave(1)         # transpose up 1 octave
```

### Chords

```ruby
chord = scale.tonic.chord              # triad from scale degree
chord = scale[0].chord(:seventh)       # 7th chord
chord = scale.chord_on(0)              # equivalent
chord = scale.chord_on(:dominant, :seventh)

chord.pitches             # => [60, 64, 67]
chord.notes               # Array of ChordGradeNote
chord.root / .third / .fifth / .seventh
chord.quality             # => :major
chord.size                # => :triad

# Modifications
chord.with_quality(:minor)
chord.with_size(:ninth)
chord.with_move(root: -1, fifth: 1)       # voicing: move tones to octaves
chord.with_duplicate(root: -2, third: [-1, 1])  # double tones
chord.octave(-1)                           # transpose down octave

# Chord-Scale navigation
scale.contains_chord?(chord)    # => true/false
scale.degree_of_chord(chord)    # => degree (0-based) or nil
chord.search_in_scales(family: :diatonic)  # find scales containing chord
chord.as_chord_in_scale(other_scale)       # recontextualize
```

### Scale Metadata

```ruby
tuning.major.class.metadata              # combined metadata hash
tuning.scale_kinds(family: :diatonic)     # filter scale kinds
tuning.scale_kinds(brightness: -1..1)     # by brightness range
Scales.extend_metadata(:dorian, mood: :dark)  # add custom metadata
```

| Metadata key | Values |
|---|---|
| `family` | `:diatonic`, `:greek_modes`, `:melodic_minor_modes`, `:pentatonic`, `:blues`, `:bebop`, `:symmetric`, `:ethnic`, `:chromatic` |
| `brightness` | -3 (very dark) to +3 (very bright); major = 0 |
| `has_leading_tone` | boolean |
| `has_tritone` | boolean |

## Generative Tools

### Markov Chains

```ruby
markov = Musa::Markov::Markov.new(
  start: 0, finish: :end,
  transitions: {
    0 => { 2 => 0.5, 4 => 0.3, 7 => 0.2 },
    7 => { 0 => 0.6, :end => 0.4 }
  }
)
melody = markov.i.to_a  # finite serie, terminates at :end
```

Transitions support: weighted hash `{ state => prob }`, array (equiprobable), or proc `{ |history| ... }`.

### Variatio (Cartesian product)

```ruby
variatio = Musa::Variatio::Variatio.new(:name) do
  field :root, [60, 64, 67]
  field :type, [:major, :minor]
  constructor do |root:, type:| { root: root, type: type } end
end
all = variatio.run           # => 6 combinations
limited = variatio.on(root: [60])  # override at runtime
```

DSL: `field`, `fieldset`, `constructor`, `with_attributes`, `finalize`.

### Rules (L-system production)

```ruby
rules = Musa::Rules::Rules.new do
  7.times do
    grow 'add note' do |melody, max_interval:|
      last = melody.last
      (-max_interval..max_interval).each do |iv|
        branch melody + [last + iv] if (last + iv).between?(48, 84)
      end
    end
  end
  cut 'no repeat' do |melody| prune if melody[-1] == melody[-2] end
  ended_when do |melody| melody.size == 8 end
end

tree = rules.apply([[60]], max_interval: 4)  # seed with [[value]] to prevent flattening
melodies = tree.combinations.map(&:last)
```

Key: each `grow` = 1 tree level. Use object accumulation (not `history`) for state tracking. `history` is always `[]` with single seed.

### GenerativeGrammar

```ruby
include Musa::GenerativeGrammar
a = N('a', size: 1)       # terminal node with attributes
b = N('b', size: 1)
d = a | b                 # alternative (OR)
grammar = (a | d).repeat(3) + N('c')  # sequence + repeat
grammar.options(content: :join)       # => ["aaac", "aabc", ...]

# Filtering
grammar.limit { |o| o.collect { |e| e.attributes[:size] }.sum <= 3 }

# Proxy for recursion
proxy = PN()
proxy.proxy_source = a + (proxy | N('end'))
```

### Darwin (evolutionary selection)

```ruby
darwin = Musa::Darwin::Darwin.new do
  measures do |obj|
    die if obj[:interval] > 12          # eliminate non-viable
    feature :stepwise if obj[:interval] <= 2   # boolean feature
    dimension :size, -obj[:interval].to_f      # numeric (normalized)
  end
  weight stepwise: 1.5, size: 2.0       # positive = favor, negative = penalize
end
ranked = darwin.select(candidates)       # sorted best-first
```

## Datasets

### Core Types

| Module | Natural Keys | Purpose |
|---|---|---|
| `GDV` | grade, sharps, octave, velocity, silence + AbsD | Scale-degree notation |
| `PDV` | pitch, velocity + AbsD | MIDI-style absolute pitch |
| `GDVd` | delta encoding of GDV | Compression |
| `AbsD` | duration, note_duration, forward_duration | Duration container |
| `V` | (array) | Value arrays |
| `PackedV` | (hash) | Key-value pairs |
| `P` | [value, duration, value, ...] | Point series |
| `PS` | from, to, duration, right_open | Parameter segments |
| `Score` | time-indexed container | Event organization |

### Conversions

```ruby
gdv = { grade: 0, duration: 1r, velocity: 0 }.extend(GDV)
pdv = gdv.to_pdv(scale)     # => { pitch: 60, duration: 1r, velocity: 64 }
gdv2 = pdv.to_gdv(scale)    # reverse

gdvd = gdv.to_gdvd(scale)                  # absolute (first note)
gdvd = gdv2.to_gdvd(scale, previous: gdv)  # delta (subsequent)

neuma_str = gdv.to_neuma    # => "(0 4 mf)" (requires gdv.base_duration)
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
score.between(1r, 4r)              # events overlapping interval
score.changes_between(0r, 4r)      # note-on/note-off timeline
score.values_of(:pitch)            # Set of unique values
score.subset { |e| e[:pitch] > 60 }  # filtered Score
```

## Transcription

### MIDI Transcriptor (ornament expansion)

```ruby
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMIDI.transcription_set(duration_factor: 1/6r),
  base_duration: 1/4r, tick_duration: 1/96r
)
# Ornaments: tr (trill), mor (mordent), turn, st (staccato)
# Expands ornaments into note sequences
```

### MusicXML Transcriptor (ornament preservation)

```ruby
transcriptor = Musa::Transcription::Transcriptor.new(
  Musa::Transcriptors::FromGDV::ToMusicXML.transcription_set,
  base_duration: 1/4r, tick_duration: 1/96r
)
# Preserves ornaments as notation symbols
```

## MIDI

### MIDIVoices

```ruby
voices = MIDIVoices.new(sequencer: transport.sequencer, output: output, channels: [0, 1, 2])
voice = voices.voices[0]

voice.note pitch: 60, velocity: 100, duration: 1/4r       # single note
voice.note pitch: [60, 64, 67], velocity: 90, duration: 1r  # chord
voice.note pitch: 60, duration: nil                         # indefinite (returns NoteControl)
voice.all_notes_off

voice.controller[:mod_wheel] = 64     # CC by symbol
voice.controller[7] = 100             # CC by number
voice.sustain_pedal = 127

voices.fast_forward = true   # silent catch-up (no MIDI output)
voices.panic(reset: false)   # all notes off
```

Controller symbols: `:mod_wheel` (1), `:breath` (2), `:volume` (7), `:expression` (11), `:general_purpose_1..4` (16-19), `:sustain_pedal` (64), `:portamento` (65). LSB variants available with `_lsb` suffix.

### MIDIRecorder

```ruby
recorder = Musa::MIDIRecorder::MIDIRecorder.new(sequencer)
input.on_message { |bytes| recorder.record(bytes) }
# After recording:
notes = recorder.transcription  # [{position:, channel:, pitch:, velocity:, duration:, velocity_off:}]
recorder.clear
```

### MIDICommunications (separate gem)

```ruby
output = MIDICommunications::Output.gets  # interactive selection
input = MIDICommunications::Input.gets
output = MIDICommunications::Output.all.first  # programmatic
input = MIDICommunications::Input.find_by_name('Device Name')
```

## Transport & Clocks

### Clock Types

| Clock | Activation | Use Case |
|---|---|---|
| `TimerClock.new(bpm:, ticks_per_beat:)` | External: call `clock.start` from another thread | Standalone compositions |
| `InputMidiClock.new(midi_input)` | External: waits for MIDI Start (0xFA) | DAW sync |
| `ExternalTickClock.new` | Manual: call `clock.tick()` per tick | Testing, game engines |
| `DummyClock.new(tick_count)` | Automatic: starts immediately | Unit tests, batch |

### Transport

```ruby
transport = Transport.new(clock, beats_per_bar, ticks_per_beat, offset: 0r)
transport.sequencer         # access sequencer
transport.start             # blocks while running (behavior varies by clock)
transport.stop              # terminates clock, triggers shutdown sequence

# Lifecycle callbacks
transport.before_begin { |seq| }     # once before first start
transport.on_start { |seq| }         # each start
transport.after_stop { |seq| }       # on stop
transport.on_change_position { |seq| }  # on seek/jump

# Position change (fast-forwards through intermediate events)
transport.change_position_to(bars: 8)
```

Shutdown sequence: `stop` -> `clock.terminate` -> `after_stop` callbacks -> sequencer reset -> `before_begin` (prepare for restart).

## Matrix

```ruby
using Musa::Extension::Matrix

# Matrix -> P format: [time, param1, param2, ...] rows
gesture = Matrix[[0, 60, 100], [0.5, 62, 110], [1, 64, 120]]
p_seq = gesture.to_p(time_dimension: 0)
# => [[[60, 100], 0.5, [62, 110], 0.5, [64, 120]]]

# Condensation: connected matrices merge
[matrix1, matrix2].to_p(time_dimension: 0)
```

## MusicXML Builder

```ruby
score = Musa::MusicXML::Builder::ScorePartwise.new do
  work_title "Title"
  creators composer: "Name"

  part :p1, name: "Piano" do
    measure do
      attributes do
        divisions 4               # per quarter note
        key 1, fifths: 0          # C major
        time 1, beats: 4, beat_type: 4
        clef 1, sign: 'G', line: 2
      end
      metronome beat_unit: 'quarter', per_minute: 120
      direction { dynamics 'f'; wedge 'crescendo' }

      pitch 'C', octave: 4, duration: 4, type: 'quarter'
      pitch 'E', octave: 4, duration: 4, type: 'quarter', alter: 1  # E#
      rest duration: 4, type: 'quarter'
      pitch 'G', octave: 4, duration: 4, type: 'quarter', slur: 'start'

      backup 16   # return to measure start for second voice/staff
      pitch 'C', octave: 3, duration: 16, type: 'whole', staff: 2, voice: 2
    end
  end
end

File.write("score.musicxml", score.to_xml.string)
```

Key parameters: `staff:` (grand staff), `voice:` (polyphony), `alter:` (accidentals), `dots:` (dotted), `slur:` (start/stop).

## Core Extensions

| Extension | Usage | Purpose |
|---|---|---|
| `Musa::Extension::Neumas` | `using` (refinement) | `.to_neumas` on strings |
| `Musa::Extension::Matrix` | `using` (refinement) | `Matrix#to_p` |
| `Musa::Extension::Arrayfy` | `using` (refinement) | `.arrayfy` normalizes to array |
| `Musa::Extension::Hashify` | `using` (refinement) | `.hashify(*keys)` array->hash |
| `Musa::Extension::DeepCopy` | `using` (refinement) | `.deep_copy` with module preservation |
| `Musa::Extension::ExplodeRanges` | `using` (refinement) | `.explode_ranges` expands Range in arrays |

### Logger

```ruby
logger = Musa::Logger.new(sequencer: sequencer, level: :debug,
  position_format_integer_digits: 3, position_format_decimal_digits: 3)
# Output: "  1.000: [INFO] message"
```

## REPL (Live Coding)

```ruby
# TCP server on port 1327 for live code evaluation
repl = Musa::REPL::REPL.new(binding)  # within sequencer context

# Protocol: #path -> filepath -> #begin -> code -> #end
# Clients: MusaLCEClientForVSCode, MusaLCEforBitwig, MusaLCEforLive
```

## Supporting Gems

| Gem | Module | Purpose |
|---|---|---|
| `midi-communications` | `MIDICommunications` | Cross-platform MIDI I/O |
| `midi-events` | `MIDIEvents` | MIDI event objects (`NoteOn`, `NoteOff`, `ChannelMessage`) |
| `midi-parser` | `MIDIParser` | Parse raw MIDI bytes to event objects |
| `musalce-server` | — | Live coding server for Bitwig/Live (CLI: `musalce-server bitwig\|live`) |

## Common Pitfalls

1. **`using Musa::Extension::Neumas` is file-scoped.** Declaring it in `main.rb` does NOT make `.to_neumas` available in `score.rb`. Declare in every file that uses it.

2. **Series are lazy, not iterable.** Series have no `.each`. Use `.next_value` (on instance), `play` in sequencer, or `.to_a` to collect. Always call `.i` to create an instance before iterating.

3. **Durations in neumas are multiples of base_duration, not fractions.** If `base_duration: 1/4r`, then `1` = quarter note, `2` = half note, `1/2` = eighth note.

4. **Use Rational for timing.** Prefer `1/4r`, `1r`, `3/4r` over `0.25`, `1.0`, `0.75` to avoid floating-point imprecision in the sequencer.

5. **Ornaments require a Transcriptor.** Without creating a `Transcriptor` with `FromGDV::ToMIDI.transcription_set` and passing it to the decoder, ornament annotations (`tr`, `mor`, `st`, `turn`) are silently ignored.

6. **TimerClock requires external activation.** `transport.start` blocks but the clock is paused. You must call `clock.start` from a separate thread. Common pattern: `transport.before_begin { Thread.new { sleep 0.1; clock.start } }`.

7. **`after` callback does NOT fire on manual `.stop`.** Use `on_stop` for cleanup that must always run. Use `after` only for chaining sections on natural completion.

8. **Series constructors are not available inside DSL blocks.** Define `S()`, `H()`, `FOR()`, etc. outside `sequencer.with do ... end` blocks, or use the module-qualified form `Musa::Series::S(...)`.

9. **Rules `history` is always `[]` with a single seed.** Use cumulative state in the object (e.g., arrays) and check `object.size` in `ended_when`, not `history.size`.

10. **Seed Rules with `[[value]]` (double array)** to prevent Ruby's arrayfy from flattening the seed.

11. **MIDI channels are 0-indexed (0-15)**, not 1-16.

12. **`play` default mode is `:wait`** -- each element must include `:duration` to determine timing between elements.

13. **`RND()` is infinite** (never exhausts). Use `.max_size(n)` to limit. `RND1()` returns a single value then exhausts.

14. **`FIBO()` starts at 0**: sequence is 0, 1, 1, 2, 3, 5, 8, 13... (not 1, 1, 2, 3...).

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
