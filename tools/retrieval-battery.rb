#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures whether a question written the way a composer asks it lands on the
# document that answers it.
#
# WHY THIS EXISTS. Everything downstream of retrieval is unfalsifiable without
# it. A skill that consults the knowledge base and gets the wrong layer produces
# an answer that reads exactly like one that got the right layer: fluent, plausible
# and sourced from something. The only way to tell the two apart is to ask
# questions whose right answer is known in advance, and count.
#
# WHAT IT MEASURES, AND WHAT IT DOES NOT. It measures **routing**: given the shape
# of a problem, does the search put the document that discusses it in the top few?
# That is the whole job the search has over `docs` in the design this plan arrived
# at -- the snippet routes, and the document is then read whole. It does NOT
# measure whether the retrieved text is any good, whether the skill used it, or
# whether the decision changed. Those need a person composing, and that is the
# commissions protocol, not this.
#
# HOW A CASE IS WRITTEN. By intention, never by API. "how do I stop a pattern
# that repeats" is a case; "what does Control#stop do" is not, because a lookup
# by name is a different primitive with a different failure mode. Each case names
# the kind it interrogates -- there is no `all` here any more than there should be
# in a skill -- and one or more acceptable targets, because more than one section
# can legitimately answer.
#
#   ruby tools/retrieval-battery.rb              # run, compare against baseline
#   ruby tools/retrieval-battery.rb --baseline   # run and write the baseline
#   ruby tools/retrieval-battery.rb -v           # show every case, not just misses

require 'json'
require_relative '../src/mcp_server/db'
require_relative '../src/mcp_server/embeddings'

module NotaKnowledgeBase
  module RetrievalBattery
    BASELINE = File.expand_path('retrieval-baseline.json', __dir__)
    TOP_K = 5

    # Questions as they are actually asked, with where the answer lives.
    #
    # A target is `source-fragment > section`: the fragment has to appear in the
    # chunk's source and the section has to match exactly. Several targets mean
    # any of them counts, which is honest -- "how do I make one melody into two
    # voices" is answered by series.md and by idioms.md, and either is a hit.
    CASES = [
      # --- the shape of a plan: the commonest wrong turn in the whole framework
      { question: 'I have a plan of sections, each with a duration, and I want them to sound one after another',
        kind: 'docs',
        expect: ['idioms.md > 1. Events placed in time', 'subsystems/sequencer.md > When is this the answer'] },
      { question: 'should I compute the bar number of each event before scheduling it?',
        kind: 'docs',
        expect: ['idioms.md > The root principle', 'idioms.md > 1. Events placed in time'] },
      { question: 'something has to happen every two bars for the whole piece',
        kind: 'docs',
        expect: ['subsystems/sequencer.md > When is this the answer', 'idioms.md > 1. Events placed in time'] },

      # --- sequences
      { question: 'I need a list of values that changes as the piece goes on',
        kind: 'docs',
        expect: ['idioms.md > 2. Sequences of anything', 'subsystems/series.md > When is this the answer'] },
      { question: 'the same melodic material read by two voices at their own pace',
        kind: 'docs',
        expect: ['subsystems/series.md > When is this the answer',
                 'subsystems/series.md > Prototype and instance',
                 'idioms.md > 2. Sequences of anything'] },
      { question: 'how do I write a recurrence where each value depends on the previous two',
        kind: 'docs',
        expect: ['idioms.md > 5. Recurrences and hand-made state', 'subsystems/series.md > When is this the answer'] },

      # --- pitch and harmony
      { question: 'I want to move up a third in the key rather than by semitones',
        kind: 'docs',
        expect: ['idioms.md > 3. Pitch', 'subsystems/music.md > When is this the answer'] },
      { question: 'building a chord on a degree and then inverting it',
        kind: 'docs',
        expect: ['subsystems/music.md > When is this the answer', 'idioms.md > 3. Pitch'] },

      # --- continuous change
      { question: 'a filter cutoff that opens slowly across four bars',
        kind: 'docs',
        expect: ['idioms.md > 10. Parameters that change over time', 'subsystems/sequencer.md > When is this the answer'] },
      { question: 'breathing: something that swells and recedes on a slow cycle',
        kind: 'docs',
        expect: ['idioms.md > 10. Parameters that change over time', 'subsystems/series.md > When is this the answer'] },

      # --- form
      { question: 'the piece has four sections and each one starts when the previous finishes',
        kind: 'docs',
        expect: ['idioms.md > 12. Macro form', 'subsystems/sequencer.md > When is this the answer'] },
      { question: 'how do I stop a repeating pattern without launching the next section',
        kind: 'docs',
        expect: ['subsystems/sequencer.md > When is this the answer', 'idioms.md > 12. Macro form'] },

      # --- randomness and generation
      { question: 'a melody that is random but that I can reproduce exactly tomorrow',
        kind: 'docs',
        expect: ['idioms.md > 6. Randomness', 'subsystems/generative.md > When is this the answer'] },
      { question: 'I can tell whether a result is good but I cannot describe how to build it',
        kind: 'docs',
        expect: ['subsystems/generative.md > When is this the answer', 'idioms.md > 7. Combinatorics and search'] },
      { question: 'every combination of four parameters, exhaustively',
        kind: 'docs',
        expect: ['idioms.md > 7. Combinatorics and search', 'subsystems/generative.md > When is this the answer'] },
      { question: 'each note should follow plausibly from the one before, with tendencies',
        kind: 'docs',
        expect: ['subsystems/generative.md > When is this the answer', 'idioms.md > 6. Randomness'] },

      # --- notation, ornament, layers
      { question: 'writing the material as text instead of building it in code',
        kind: 'docs',
        expect: ['idioms.md > 8. Musical material as text', 'subsystems/neumas.md > When is this the answer'] },
      { question: 'trills and mordents that turn into actual notes when played',
        kind: 'docs',
        expect: ['idioms.md > 9. Articulation and ornament', 'subsystems/transcription.md > When is this the answer'] },
      { question: 'my composition is full of MIDI note numbers and durations in seconds',
        kind: 'docs',
        expect: ['idioms.md > 4. Layers: musical intent vs. realization', 'subsystems/datasets.md > When is this the answer'] },

      # --- output and time
      { question: 'I want the piece as a score somebody can read on paper',
        kind: 'docs',
        expect: ['subsystems/musicxml-builder.md > When is this the answer', 'idioms.md > 14. Event lists for querying or export'] },
      { question: 'getting the notes out to an instrument, with the note-offs handled',
        kind: 'docs',
        expect: ['subsystems/midi.md > When is this the answer'] },
      { question: 'running the whole piece as fast as the machine can, to test it',
        kind: 'docs',
        expect: ['idioms.md > 15. Clocks', 'subsystems/transport.md > When is this the answer'] },
      { question: 'following the tempo of a DAW instead of setting my own',
        kind: 'docs',
        expect: ['subsystems/transport.md > When is this the answer', 'idioms.md > 15. Clocks'] },
      { question: 'a gesture drawn as a trajectory through several dimensions at once',
        kind: 'docs',
        expect: ['subsystems/matrix.md > When is this the answer', 'idioms.md > 13. Multiparametric gesture'] },

      # --- the craft layer, which is a document and not a subsystem
      { question: 'how should I organise the files of a piece so I can reload it while it plays',
        kind: 'docs',
        expect: ['guides/project-structure.md > Two files: infrastructure and composition',
                 'guides/project-structure.md > Reaching the infrastructure from the score'] },
      { question: 'notes keep sounding after I stop the transport',
        kind: 'docs',
        expect: ['guides/project-structure.md > Stopping'] },
      { question: 'incoming OSC messages should change what the sequencer plays',
        kind: 'docs',
        expect: ['guides/project-structure.md > Control arriving from outside'] },

      # --- live coding
      { question: 'evaluating code from my editor into a running piece',
        kind: 'docs',
        expect: ['subsystems/repl.md > When is this the answer'] },

      # --- kinds other than docs, so the battery covers the whole contract
      { question: 'a complete piece that uses Markov chains for its melodic line',
        kind: 'demo_readme',
        expect: ['demo-05'] },
      # The target is `main.rb`, not a particular demo: every project's setup
      # lives in one, and picking a demo number would test nothing but which of
      # twenty equivalent files sorted first.
      { question: 'wiring a TimerClock, a transport and MIDI voices together',
        kind: 'demo_code',
        expect: ['main.rb'] },
      { question: 'interpolating between two rhythmic patterns in tick space',
        kind: 'best_practice',
        expect: ['tick-aligned-durations'] },
      { question: 'blending two Markov transition tables with a control parameter',
        kind: 'best_practice',
        expect: ['markov-blending'] }
    ].freeze

    class << self
      def run(verbose: false)
        embedder = Voyage.query_embedder
        results = []

        db = DB.open

        begin
          CASES.each do |kase|
            embedding = embedder.embed([kase[:question]]).first
            hits = DB.knn_search(db, embedding, kind: kase[:kind], n_results: TOP_K)

            rank = hits.index { |hit| matches?(hit, kase[:expect]) }

            results << {
              'question' => kase[:question],
              'kind' => kase[:kind],
              'rank' => rank,
              'got' => hits.first(TOP_K).collect { |hit| label(hit) }
            }
          end
        ensure
          db.close
        end

        report(results, verbose: verbose)
        results
      end

      # A hit matches if any acceptable target is a substring of its label. The
      # label is `source > section`, and targets are written as fragments so a
      # source that arrives as a URL still matches.
      def matches?(hit, targets)
        text = label(hit)
        targets.any? { |target| fragments(target).all? { |part| text.include?(part) } }
      end

      def fragments(target)
        target.split(' > ').collect(&:strip)
      end

      def label(hit)
        section = hit['section'].to_s
        source = hit['source'].to_s

        section.empty? ? source : "#{source} > #{section}"
      end

      def report(results, verbose:)
        total = results.size
        at1 = results.count { |r| r['rank'] == 0 }
        at3 = results.count { |r| r['rank'] && r['rank'] < 3 }
        at5 = results.count { |r| r['rank'] }

        puts "#{total} questions, asked by intention"
        puts "  first result correct:  #{at1}/#{total}"
        puts "  in the top 3:          #{at3}/#{total}"
        puts "  in the top #{TOP_K}:          #{at5}/#{total}"

        misses = results.reject { |r| r['rank'] }
        show = verbose ? results : misses

        return if show.empty?

        puts
        puts(verbose ? 'EVERY CASE' : 'MISSED ENTIRELY')
        show.each do |r|
          mark = r['rank'] ? "top #{r['rank'] + 1}" : 'MISS'
          puts "  [#{mark}] #{r['question']}"
          r['got'].each_with_index { |g, i| puts "      #{i + 1}. #{g}" } unless r['rank'] == 0
        end
      end

      # Compare against the baseline, and FAIL on regression.
      #
      # A measurement that only prints is a measurement nobody reads. Movement in
      # either direction is reported, because an unexplained improvement is worth
      # looking at too, but only a case that got worse is an error: retrieval is
      # not deterministic across embedding-model versions and corpus growth, so
      # small drift is expected and silent decay is not.
      #
      # When the drift is legitimate -- the corpus changed, a document was
      # renamed -- the fix is to look, agree, and take a new baseline. That is a
      # deliberate act and it leaves a diff.
      def compare(results)
        unless File.exist?(BASELINE)
          warn "No baseline at #{BASELINE}. Run with --baseline to write one."
          return 1
        end

        before = JSON.parse(File.read(BASELINE))
        by_question = before['results'].to_h { |r| [r['question'], r['rank']] }

        moved = results.filter_map do |now|
          was = by_question[now['question']]
          next if was == now['rank']

          [now['question'], was, now['rank']]
        end

        puts
        if moved.empty?
          puts "No change against the baseline of #{before['taken']}."
          return 0
        end

        worse = moved.select { |_, was, now| rank_value(now) > rank_value(was) }
        better = moved - worse

        puts "CHANGED against the baseline of #{before['taken']}"
        (worse + better).each do |question, was, now|
          arrow = rank_value(now) > rank_value(was) ? 'WORSE' : 'better'
          puts "  [#{arrow}] #{describe(was)} -> #{describe(now)}   #{question}"
        end

        return 0 if worse.empty?

        warn ''
        warn "#{worse.size} question(s) retrieve worse than they did. Either something " \
             'regressed, or the corpus legitimately moved -- decide which, and take a ' \
             'new baseline only if it is the second.'
        1
      end

      # Lower is better; a miss is worse than any rank.
      def rank_value(rank)
        rank.nil? ? Float::INFINITY : rank
      end

      def describe(rank)
        rank.nil? ? 'MISS' : "top #{rank + 1}"
      end

      def write_baseline(results, taken:)
        File.write(BASELINE, JSON.pretty_generate('taken' => taken, 'results' => results) + "\n")
        puts
        puts "Baseline written to #{BASELINE}"
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  verbose = ARGV.delete('-v')
  baseline = ARGV.delete('--baseline')

  results = NotaKnowledgeBase::RetrievalBattery.run(verbose: !verbose.nil?)

  if baseline
    NotaKnowledgeBase::RetrievalBattery.write_baseline(results, taken: ARGV.first || 'unlabelled')
    exit 0
  end

  exit NotaKnowledgeBase::RetrievalBattery.compare(results)
end
