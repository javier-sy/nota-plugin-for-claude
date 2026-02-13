# Inspiration Framework

Default creative dimensions for composition ideation. Each `##` section defines one dimension. The section title names the dimension; the body contains provocations and questions to expand the creative space.

Customize this framework with `/inspiration_framework` to add, remove, or modify dimensions.

## Structure

Explore how the piece is organized in time and space:

- **Horizontal organization** — What if the piece isn't sectional? Consider: continuous mutation, gradual process (Feldman, Reich), discontinuous blocks (Stravinsky), cyclic return, open form. Is it teleological (going somewhere) or non-teleological (being somewhere)?
- **Vertical organization** — What happens when you stack things? Stratified independent layers, polyphony, homofonía, heterophony, dialogue between voices. What if each layer follows different rules?
- **Proportion and scale** — What governs the proportions? Golden ratio, Fibonacci durations, fractal self-similarity, symmetry, deliberate asymmetry. What if the micro-structure mirrors the macro-structure?
- **Connectivity** — How do parts relate? Transformation (A becomes A'), memory (B remembers A), anticipation (A foreshadows B), contrast (B negates A), independence (A and B ignore each other)
- **Emergence vs. design** — Is the form pre-planned or does it emerge from the rules? What if you set up rules and let the form surprise you?

## Time

Explore the temporal dimension:

- **Pulse and meter** — Does the piece have a pulse? Regular, irregular, shifting? What about no pulse at all — free time, event-driven? What happens with `base_duration: 1/4r` vs `1/8r` vs `1r`?
- **Polyrhythm and polymeter** — What if different voices use different subdivisions? 3 against 4, 5 against 7? How does MusaDSL's `every` scheduling enable this?
- **Tempo** — Fixed, gradual change, sudden shifts? What about a piece where tempo is a compositional parameter, not a constant?
- **Duration vocabulary** — What if you only use Fibonacci durations (1, 1, 2, 3, 5, 8)? Or powers of 2? Or prime numbers? How does limiting the duration palette shape the rhythm?
- **Silence** — Where does silence go? As punctuation, as structure, as absence? What is the ratio of sound to silence?

## Pitch

Explore the pitch dimension:

- **Scale and mode** — Beyond major/minor: what about dorian, lydian, whole-tone, octatonic, pentatonic? What about switching scales mid-piece? Polymodality (different scales in different voices)?
- **Interval focus** — What if a piece is built around one interval? All tritones, all minor seconds, all perfect fifths. How does interval restriction shape melody and harmony?
- **Register** — Where do things happen? Extreme high, extreme low, compressed middle register? What about systematic register expansion or contraction?
- **Microtonality** — MusaDSL supports arbitrary tuning systems. What about 19-TET, 31-TET, just intonation? What does non-equal temperament do to familiar patterns?
- **Pitch series** — Twelve-tone rows, limited pitch sets, pitch classes. What about deriving all pitch material from a single seed pattern?
- **Clusters and masses** — Instead of individual notes: clouds, clusters, bands. What happens when pitch becomes texture?

## Algorithm

Explore the generative and algorithmic dimension:

- **Markov chains** — What if transitions depend on context? First-order vs higher-order. What about a Markov chain trained on your own previous works? What about non-homogeneous chains where probabilities evolve?
- **L-systems (Rules)** — What if musical material grows like a plant? Simple axiom, recursive expansion. What musical meaning do you give to each symbol?
- **Genetic algorithms (Darwin)** — What if melodies compete and breed? What is the fitness function for music? Can you define "interesting"?
- **Series operations** — `map`, `select`, `merge`, `zip`, `flatten`, `repeat`, `skip` — what unexpected combinations can you make? What about series of series?
- **Feedback** — What if the output feeds back into the input? Self-modifying rules, accumulating state, pieces that learn from themselves
- **Control vs. chance** — Where on the spectrum from total control to total chance? What if different parameters have different degrees of freedom? Controlled pitches with random rhythms?
- **Seeds and determinism** — Same seed, same piece. Different seed, different piece. What is a "version" of an algorithmic composition? What about pieces that are deliberately non-reproducible?

## Texture

Explore the sonic surface:

- **Density** — How many events per unit of time? Sparse pointillism, dense saturation, gradual accumulation, sudden thinning. What is the density curve of the piece?
- **Layering** — Unison, duo, trio, tutti. What if layers enter one by one? What if each layer is a variation of the same material?
- **Roles** — Melody/accompaniment, foreground/background, leader/follower. What if roles rotate? What if there's no hierarchy — all voices equal?
- **Dynamics** — ppp to fff as a structural parameter, not just expression. What about systematic dynamic processes? Crescendo as form?
- **MIDI parameters** — Beyond notes: velocity curves, CC messages, program changes, aftertouch. What sonic possibilities do these open?
- **Timbral evolution** — Even with fixed instruments, timbre changes through register, density, velocity, articulation. How does the sonic color evolve?

## Instrumentation

Explore writing for specific instruments and ensembles:

- **Instrumental identity** — Each instrument has a character: range, agility, resonance, attack. What if you write *for* the instrument instead of writing abstract notes? How do you encode idiomatic writing (string crossings, breathing, pedaling) in MusaDSL?
- **Range and tessitura** — Where does each instrument sound best? What happens at its extremes? What if you systematically explore the registers each instrument avoids?
- **Ensemble interaction** — How do instruments relate? Unison, call-and-response, hocket, doubling, shadowing, opposition. What happens when algorithmically generated material is distributed across an ensemble?
- **Orchestration as composition** — What if the orchestration *is* the composition? Same pitch material, radically different instrumentation. What does timbre redistribution reveal?
- **MIDI mapping** — Channels as instruments, velocity as articulation, CC as expression. How do you map instrumental thinking to MIDI reality? What about multi-timbral setups where one algorithm feeds different instruments?
- **Virtual vs. physical** — Writing for software synths (infinite range, any timbre) vs. real instruments (human limits, physical effort). How does the target instrument change the algorithm?
- **Reduction and expansion** — A piece for one instrument expanded to ensemble. An ensemble piece reduced to solo. What survives the transformation?

## Reference

Connect to the broader musical world:

- **Traditions** — What musical tradition inspires you? Minimalism, spectralism, serialism, aleatoric music, process music, noise, ambient, drone, micropolyphony? How would you implement its essence algorithmically?
- **Composers** — Who are your reference points? Reich's phasing, Riley's repetition, Xenakis's stochastic clouds, Ligeti's micropolyphony, Nancarrow's tempo canons, Feldman's quiet durations? **Use WebSearch to explore composers and their techniques for accurate context.**
- **Extra-musical ideas** — Can mathematical structures (fractals, cellular automata, group theory), natural processes (weather, growth, flocking), or texts/poems drive the composition?
- **Live coding culture** — Improvisation, performance, real-time decisions. How does the live coding context change what you compose? What about pieces designed to be modified in performance?
- **Cross-domain** — What would a painting sound like? A building? A recipe? How do you translate non-musical structures into musical ones?

## Dialogue

Contrast with similar and opposite composers to generate new directions:

This dimension requires **analyzing the conversation and ideas discussed** to identify which composers, techniques, and aesthetics are emerging as reference points — then deliberately seeking both affinity and opposition.

- **Similar composers** — Based on the ideas discussed: who works in a similar territory? What specific techniques do they use that you haven't tried? **Use WebSearch to find their works, interviews, scores, or writings.** What can you learn from someone who shares your aesthetic but has different tools or experience?
- **Opposite composers** — Who represents the polar opposite of the direction you're exploring? If you're working with strict processes, who embraces total improvisation? If you favor density, who composes with silence? **Use WebSearch to explore their approach.** What would happen if you adopted one of their principles into your piece?
- **Productive tension** — What if you deliberately combined a technique from a similar composer with a principle from an opposite one? Where does the friction between the two generate something new?
- **Unexpected connections** — Are there composers from entirely different traditions or eras who faced the same compositional problem? A Baroque contrapuntist and an algorithmic composer both deal with rule-governed generation — what can one teach the other?
- **Provocation from opposition** — What would your opposite composer critique about your approach? What would they do differently with the same MusaDSL tools? Can that critique become a creative starting point?

## Constraint

Explore creative limitation as catalyst:

- **Pitch restriction** — Only 3 notes. Only one octave. Only the black keys. What does severe limitation reveal?
- **Duration restriction** — Only one duration. Only Fibonacci values. No repetition of the same duration consecutively.
- **Resource restriction** — One MIDI channel. One voice. Maximum 10 events per bar. What does scarcity force you to invent?
- **Process restriction** — The entire piece is one gradual process. No section changes. No surprises. What does process reveal that structure hides?
- **Tool restriction** — Use only Markov chains and nothing else. Or only series operations. Or only L-systems. What does each tool reveal when used in isolation?
- **Rule restriction** — Rules that contradict each other. Rules that become increasingly strict. Rules that dissolve over time. What does the tension between rule and freedom produce?
- **Compositional games** — Derive the entire piece from one number. Use today's date as the seed. Let a coin flip decide. What happens when you surrender control?
