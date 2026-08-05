#!/usr/bin/env ruby
# frozen_string_literal: true

# Checks that the documents Nota depends on are where Nota says they are.
#
# WHY THIS EXISTS. Nota stopped carrying musa-dsl's knowledge and started reading
# it from the installed gem. That trade is a good one -- the knowledge now lives
# where it can be falsified -- and it buys a new failure: the plugin now depends
# on FILE NAMES in another repository. Rename `idioms.md`, move `docs/guides/`,
# and nothing here raises. The skills go on telling the assistant to read a
# document that is not there, and the only symptom is an answer that quietly
# omits what it could not find.
#
# That symptom is exactly the one that hid a broken best-practice path for
# months. So the contract is asserted, not assumed.
#
# WHAT IT CHECKS
#
#   1. Every document `MusaDocs::ALWAYS` loads into context exists.
#   2. Every `docs/…md` a skill names exists.
#   3. Every `get_doc("x")` a skill writes resolves, by the same rules get_doc uses.
#   4. `idioms.md` still has its entries -- a file that exists and has been
#      emptied would pass 1 and teach nothing.
#
# WHAT IT DOES NOT CHECK. Whether any of it is any good. That is the retrieval
# battery, and beyond it the commissions.
#
#   ruby tools/contract-check.rb                     # against the installed gem
#   NOTA_MUSA_DSL_PATH=../musa-dsl ruby tools/contract-check.rb    # against a tree

require_relative '../src/mcp_server/musa_docs'

module NotaKnowledgeBase
  module ContractCheck
    SKILLS = File.expand_path('../src/skills', __dir__)

    # idioms.md is the one document loaded for its STRUCTURE: it is entered from
    # a symptom, so its entries are the interface. A floor, not an equality --
    # the catalogue is expected to grow.
    IDIOM_ENTRIES_FLOOR = 15

    class << self
      def run
        reason = MusaDocs.missing_gem_because
        if reason
          warn "CONTRACT NOT CHECKED: #{reason}"
          return 1
        end

        failures = always_present + skill_documents + get_doc_arguments + idioms_populated

        if failures.empty?
          puts "Contract holds against musa-dsl #{MusaDocs.version} at #{MusaDocs.directory}"
          return 0
        end

        warn "CONTRACT BROKEN against musa-dsl #{MusaDocs.version} at #{MusaDocs.directory}:"
        failures.each { |failure| warn "  #{failure}" }
        warn ''
        warn 'Either the document moved in musa-dsl and this plugin has to follow it,'
        warn 'or it was removed and what refers to it here is now a lie.'
        1
      end

      def always_present
        MusaDocs.absent.collect do |document|
          "#{document} is loaded into context at session start and is not in this musa-dsl"
        end
      end

      # `docs/whatever.md` written in a skill, in prose or in an instruction.
      def skill_documents
        mentions('`(docs/[a-z0-9/_-]+\.md)`').filter_map do |skill, document|
          next if MusaDocs.path_of(document)

          "#{skill} names #{document}, which is not in this musa-dsl"
        end
      end

      # `get_doc("x")` written in a skill, resolved the way the tool resolves it.
      def get_doc_arguments
        mentions('get_doc\(["“]([a-z0-9/_-]+)["”]\)').filter_map do |skill, name|
          candidates = [name, "docs/#{name}", "docs/#{name}.md",
                        "docs/subsystems/#{name}.md", "docs/guides/#{name}.md"]
          next if candidates.any? { |candidate| MusaDocs.path_of(candidate) }

          "#{skill} calls get_doc(#{name.inspect}), which resolves to nothing"
        end
      end

      def idioms_populated
        path = MusaDocs.path_of('docs/idioms.md')
        return [] unless path

        entries = File.read(path).scan(/^## /).size
        return [] if entries >= IDIOM_ENTRIES_FLOOR

        ["docs/idioms.md has #{entries} entries, below the #{IDIOM_ENTRIES_FLOOR} " \
         'this plugin loads it for. It is the symptom index: an empty one is worse ' \
         'than none, because nothing reports its silence.']
      end

      # [[skill, capture], …] for every match of a pattern across the skills.
      def mentions(pattern)
        regexp = Regexp.new(pattern)

        Dir.glob(File.join(SKILLS, '*', 'SKILL.md')).sort.flat_map do |path|
          skill = File.basename(File.dirname(path))

          File.read(path).scan(regexp).flatten.uniq.collect { |capture| [skill, capture] }
        end
      end
    end
  end
end

exit NotaKnowledgeBase::ContractCheck.run if __FILE__ == $PROGRAM_NAME
