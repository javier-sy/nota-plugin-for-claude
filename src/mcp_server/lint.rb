# frozen_string_literal: true

# Reads MusaDSL composition code and reports what it can see.
#
# WHY THIS EXISTS. Everything else in this plugin is instruction, and instruction
# is skipped: the modelling gate can be waved through, the idiom catalogue can be
# in context and unread, the citation column can be left empty. None of that
# raises. Idiom failures in particular are invisible to testing -- the code runs,
# the piece sounds right, and it is still not MusaDSL -- so nothing downstream
# ever reports them either.
#
# A check that runs on the text is the one thing in the circuit that cannot be
# forgotten, because it does not depend on remembering.
#
# THE LINT POINTS; THE AGENT JUDGES. Nothing here is a rule and nothing here is
# automatic. Several of these patterns are legitimate in the right place -- `at`
# for a genuine one-off landmark, a bespoke class for a structure that must be
# inspected. What is not legitimate is that the choice was never argued against
# the framework, and that is what a signal makes impossible to skip in silence.
#
# TWO CONFIDENCES, KEPT APART. `certain` findings are facts about the text: a
# Ruby syntax error, a `1/4` that is integer zero, a constructor used in a file
# that never included the module. `worth arguing` findings are shapes that are
# usually a wrong turn and sometimes exactly right. Presenting them as one list
# would teach the reader to discount both.
#
# NO API KEY, NO DATABASE, NO NETWORK. It works when the knowledge base is
# unreachable, which is when guessing is most tempting.

module NotaKnowledgeBase
  module Lint
    Finding = Struct.new(:line, :confidence, :rule, :message, :excerpt, keyword_init: true)

    # Facts about the text. Each is checkable and each has been wrong in real code.
    CERTAIN = [
      {
        rule: "brace block on a parenthesis-free call",
        pattern: /^\s*(at|wait|every|play|move|launch)\s+[^(\s][^#]*?\{/,
        message: "`%<verb>s x { ... }` is a Ruby SYNTAX ERROR: a brace block binds to the " \
                 "last argument, not to the method. Write `%<verb>s(x) { ... }` or " \
                 "`%<verb>s x do ... end`."
      },
      {
        rule: "integer division in a temporal value",
        pattern: %r{(?<!\w)(?<!/)\d+/\d+(?![r\d/])},
        message: "`%<match>s` is INTEGER DIVISION in Ruby -- `1/4` is 0, not a quarter. " \
                 "Musical time is rational: write `%<match>sr`."
      },
      {
        rule: "float in a position or duration",
        pattern: /\b(?:at|wait|every|duration|note_duration|forward_duration)\s*[:(]?\s*\d+\.\d+/,
        message: "A Float position is rounded to the nearest tick, silently: `at(1.3)` fires " \
                 "at 125/96r. Small enough to survive listening, large enough to accumulate. " \
                 "Use Rational."
      },
      {
        rule: "return inside an event or scheduling block",
        pattern: /^\s*return\b/,
        message: "`return` inside a block returns from the enclosing METHOD, not from the " \
                 "block. In an `on` or `at` body that is a LocalJumpError or a silent exit " \
                 "from something else. Use `next`.",
        only_inside_block: true
      }
    ].freeze

    # Shapes that are usually the generalist reflex and occasionally the right
    # answer. Each names the idiom that normally replaces it; the entry in
    # `idioms.md` carries the argument, and the agent has to make it.
    WORTH_ARGUING = [
      {
        rule: "at inside a loop",
        pattern: /^\s*(?:\w+\.)?at\s*\(?\s*\w*\s*[+*]/,
        message: "`at` with a computed position. A sequence of events in time is a serie " \
                 "carrying `duration:` consumed by `play`; `at` is for genuine one-off " \
                 "landmarks. If you are holding absolute positions, the wrong turn was " \
                 "upstream: model plans as durations. (idioms.md > 1)"
      },
      {
        rule: "hand-written recurrence",
        pattern: /(?<![\w.])(\w+)\s*,\s*(\w+)\s*=\s*\2\s*,\s*\1\s*[+*]/,
        message: "A hand-written recurrence. `FIBO(first, second)` exists, and `E(*seeds) " \
                 "{ |last_value:, caller:| ... }` for recurrences that are not Fibonacci -- " \
                 "state travels in `caller.parameters`. As a serie it composes with " \
                 "everything else. (idioms.md > 5)"
      },
      {
        rule: "arithmetic on MIDI pitches",
        pattern: /\w*pitch\w*\s*[+\-]\s*\d+|\w*pitch\w*\s*%\s*12\b/,
        message: "Arithmetic on note numbers welds the piece to one tuning and one tonic. " \
                 "`scale[grade]`, `note.at_octave`, `.sharp`/`.flat`, `chord_on`, " \
                 "`chord.with_quality`. (idioms.md > 3)"
      },
      {
        rule: "seconds or raw velocity in the musical layer",
        pattern: %r{\b60\.0?\s*/\s*bpm|\bbpm\s*/\s*60},
        message: "Seconds in the material. The musical layer stays GDV -- grade, duration as " \
                 "multiples of `base_duration`, velocity as a dynamic mark -- and becomes " \
                 "pitches and seconds only where sound is emitted. (idioms.md > 4)"
      },
      {
        rule: "unseeded randomness",
        pattern: /(?<!\w)rand\s*[( ]|\brandom\s*:\s*nil/,
        message: "`rand` not derived from a seeded `Random`. An unseeded piece is one you " \
                 "cannot come back to. `RND(values, random:)`, `.randomize(random:)`, a " \
                 "`Random.new(seed)` of your own. (idioms.md > 6)"
      },
      {
        rule: "generate then filter",
        pattern: /\.(?:product|permutation|combination)\s*\(/,
        message: "Building a candidate array to filter afterwards. That is Variatio, " \
                 "GenerativeGrammar or Darwin, and pruning during growth beats " \
                 "generate-then-filter. (idioms.md > 7)"
      },
      {
        rule: "every that nudges towards a target",
        pattern: /^\s*every\b[^#]*\bdo\b/,
        message: "If this `every` body moves a value towards a target, it is `move from:, " \
                 "to:, duration:, every:, function:`. If it repeats a fixed event, it is " \
                 "correct as it is. (idioms.md > 10)",
        soft: true
      },
      {
        rule: "manual sort by time",
        pattern: /\.sort_by\s*\{[^}]*\b(?:time|position|start)\b/,
        message: "Sorting by a time field and walking the result is `TIMED_UNION` and " \
                 "`play_timed`. (idioms.md > 11)"
      }
    ].freeze

    # Constructors that need the module in scope. Their absence is
    # self-concealing: the reflex that avoids them raises no NameError.
    CONSTRUCTORS = /(?<!\w)(S|E|H|HC|A|AC|FOR|MERGE|RND|RND1|SIN|FIBO|HARMO|QUEUE|PROXY)\s*\(/

    class << self
      def check(code, filename: nil)
        lines = code.lines
        findings = []

        findings.concat(syntax_finding(code, filename))
        findings.concat(scope_findings(code, lines))

        lines.each_with_index do |line, index|
          next if comment_or_blank?(line)

          findings.concat(rule_findings(line, index + 1, lines))
        end

        findings.sort_by { |f| [f.confidence == "certain" ? 0 : 1, f.line] }
      end

      # Ruby's own parser, first. Everything below assumes the text is Ruby.
      def syntax_finding(code, filename)
        RubyVM::InstructionSequence.compile(code, filename || "(composition)")
        []
      rescue SyntaxError => e
        line = e.message[/:(\d+):/, 1].to_i
        [Finding.new(line: line, confidence: "certain", rule: "syntax",
                     message: "This file does not parse: #{e.message.lines.first.to_s.strip}",
                     excerpt: nil)]
      rescue StandardError
        []
      end

      def scope_findings(code, lines)
        return [] unless code.match?(CONSTRUCTORS)
        return [] if code.match?(/include\s+Musa::(All|Series)\b/)

        line = lines.index { |l| l.match?(CONSTRUCTORS) }.to_i + 1
        name = code[CONSTRUCTORS, 1]

        [Finding.new(
          line: line, confidence: "certain", rule: "constructor without its module",
          message: "`#{name}(` is used and this file has no `include Musa::Series` (nor " \
                   "`Musa::All`). Its absence hides itself: the reflex that avoids the " \
                   "constructors is the reflex that would have raised NameError.",
          excerpt: lines[line - 1].to_s.strip
        )]
      end

      def rule_findings(line, number, lines)
        findings = []

        CERTAIN.each do |rule|
          next unless line.match?(rule[:pattern])
          next if rule[:only_inside_block] && !inside_block?(lines, number)

          findings << finding(rule, line, number, "certain")
        end

        WORTH_ARGUING.each do |rule|
          next unless line.match?(rule[:pattern])

          findings << finding(rule, line, number, "worth arguing")
        end

        findings
      end

      def finding(rule, line, number, confidence)
        match = line[rule[:pattern]].to_s.strip
        verb = match[/\A\s*(\w+)/, 1].to_s

        Finding.new(
          line: number,
          confidence: confidence,
          rule: rule[:rule],
          message: format(rule[:message], match: match, verb: verb),
          excerpt: line.strip
        )
      end

      def comment_or_blank?(line)
        stripped = line.strip
        stripped.empty? || stripped.start_with?("#")
      end

      # Crude and deliberately so: a `return` matters here when something above it
      # opened a block that is still open. Over-reporting a `return` is cheap;
      # missing the one inside an `on` body is not.
      def inside_block?(lines, number)
        lines.first(number - 1).any? { |l| l.match?(/\b(?:on|at|every|play|move|wait)\b.*\bdo\b|\bdo\s*\|/) }
      end

      # Rendered for the model: two lists, never merged.
      def report(code, filename: nil)
        findings = check(code, filename: filename)

        return "Nothing to report. This says the text is clean of what a reader can see; " \
               "it says nothing about whether the FORM is right, which is the modelling " \
               "table's job." if findings.empty?

        certain = findings.select { |f| f.confidence == "certain" }
        arguable = findings - certain

        parts = []

        unless certain.empty?
          parts << "## Certain — these are facts about the text\n"
          parts << certain.collect { |f| render(f) }.join("\n")
        end

        unless arguable.empty?
          parts << "## Worth arguing — usually the generalist reflex, sometimes right\n"
          parts << "**The lint points; you judge.** For each one, either change it or say " \
                   "in one line why this is the case where the reflex is correct. What is " \
                   "not acceptable is passing over it in silence.\n"
          parts << arguable.collect { |f| render(f) }.join("\n")
        end

        parts.join("\n")
      end

      def render(finding)
        head = "- **line #{finding.line}** (#{finding.rule}) — #{finding.message}"
        finding.excerpt ? "#{head}\n  `#{finding.excerpt}`" : head
      end
    end
  end
end
