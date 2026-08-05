#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads musa-dsl's own documentation out of the INSTALLED gem.
#
# WHY THIS EXISTS. Nota used to carry its own copy of musa-dsl's knowledge --
# a condensed API reference, a philosophy document, a summary of practices --
# maintained by hand and re-derived by prompting a model to read the sources
# again. Every one of those copies drifted, and one of them amplified a false
# claim into a rule. The framework's knowledge belongs to the framework: it is
# the only place it can be falsified, by its own suite and its own doctest.
#
# So Nota stops holding it and asks the gem. Two documents come into context at
# the start of every session:
#
#   docs/idioms.md      the symptom index. It has to be present BEFORE there is
#                       a question, because you cannot ask about a reflex you do
#                       not know you have.
#   docs/vocabulary.md  what exists, on one page. The one question a lookup
#                       cannot answer, because a lookup needs the word.
#
# Everything else -- the thirteen subsystem guides, the project-structure guide,
# the examples -- waits to be asked for, and is read whole when it is.
#
# NO FALLBACK, BY DECISION. What the installed gem does not have is not fetched
# from somewhere else. The alternative was the copy indexed in knowledge.db,
# which is documentation of whatever version happened to be checked out when that
# index was built -- precisely the version mismatch reading from the gem exists
# to close. A piece cannot sound without the gem either.
#
# AND NO VERSION FLOOR. This asks whether the documents are where it expects
# them, and nothing else. A constant here saying "0.49.0 or later" would be an
# assertion about musa-dsl's history maintained inside Nota -- the same category
# as the condensed reference this file replaced, and needing the same hand to
# keep it true. It would also be answering the wrong question: it does not
# exclude wrong documentation, only old documentation, so a future release that
# introduced a false claim would pass it. What the plugin owes the reader is not
# a verdict on which releases are fit, but an accurate statement of which one it
# read -- which every response carries.
#
# Presence turns out to be the better proxy anyway, and a self-maintaining one:
# `docs/vocabulary.md` exists only where `tools/vocabulary.rb` exists, and that
# was written downstream of the doctest. A gem that has it is a gem from after
# the corpus was executed. The file says so by being there.

require 'rubygems'
require 'fileutils'

module NotaKnowledgeBase
  module MusaDocs
    GEM = 'musa-dsl'

    # Loaded into context at session start, in this order: the reflexes first,
    # then the words. Each is served if the installed gem has it, and named if
    # it does not -- a release with one and not the other is described, not
    # rejected.
    ALWAYS = ['docs/idioms.md', 'docs/vocabulary.md'].freeze

    # For working on musa-dsl and Nota side by side: point at a source tree and
    # it is read instead of the installed gem. It announces itself in the context
    # it produces -- a source of truth with no version is exactly the thing this
    # file exists to prevent, so it must never be in use without being visible.
    OVERRIDE = 'NOTA_MUSA_DSL_PATH'

    class << self
      def override
        path = ENV[OVERRIDE]
        return nil if path.nil? || path.empty?

        File.directory?(File.join(path, 'docs')) ? File.expand_path(path) : nil
      end

      # The newest installed musa-dsl, found WITHOUT resolving it as a dependency.
      #
      # `Gem::Specification.find_by_name` is the obvious call and it is wrong
      # here: the server runs under Bundler with the plugin's own Gemfile, and
      # inside a bundle only the bundled gems exist. musa-dsl is not one of them
      # and must not become one -- Nota does not depend on the framework, it
      # reads the copy the user installed for their own work. So look at the
      # gem directories themselves, which Bundler does not narrow.
      def specification
        return @specification if defined?(@specification)

        candidates = Gem.path.flat_map do |root|
          Dir.glob(File.join(root, "specifications", "#{GEM}-*.gemspec"))
        end

        specs = candidates.filter_map do |path|
          Gem::Specification.load(path)
        rescue StandardError
          nil
        end

        @specification = specs.max_by(&:version)
      end

      def version
        return 'working tree' if override

        specification&.version
      end

      def directory
        override || specification&.gem_dir
      end

      # The one thing that can go wrong before files are even a question.
      def missing_gem_because
        return nil if override || specification

        "#{GEM} is not installed. Nota reads the framework's documentation from " \
          "the installed gem, so it needs one: `gem install #{GEM}`, or add " \
          "`gem '#{GEM}'` to the project's Gemfile."
      end

      def available?
        present.any?
      end

      # Which of the always-loaded documents this gem actually has, and which it
      # does not. Answered per file, against the gem the user installed.
      def present
        return [] unless directory

        ALWAYS.select { |document| File.exist?(File.join(directory, document)) }
      end

      def absent
        return [] unless directory

        ALWAYS - present
      end

      # The full path of a document inside the installed gem, or nil. Used by
      # get_doc as well as by the session-start load.
      def path_of(document)
        return nil unless directory

        path = File.join(directory, document)
        File.exist?(path) ? path : nil
      end

      # What goes into context at session start.
      def context
        reason = missing_gem_because
        return "[Nota] The MusaDSL conceptual layer is NOT loaded: #{reason}\n" if reason

        return "[Nota] The MusaDSL conceptual layer is NOT loaded: #{GEM} #{version} at " \
               "#{directory} has none of #{ALWAYS.join(', ')}. Those documents arrived in a " \
               "later release; `gem update #{GEM}` brings them.\n" if present.empty?

        parts = if override
                  ["[Nota] MusaDSL read from a WORKING TREE at #{directory} (#{OVERRIDE} is set), " \
                   "not from an installed gem. It carries no version and no release verified it.\n"]
                else
                  ["[Nota] MusaDSL #{version}, read from the installed gem at #{directory}.\n"]
                end

        if absent.any?
          parts << "[Nota] Not in #{GEM} #{version}, so not below: #{absent.join(', ')}. " \
                   "A later release carries it.\n"
        end

        present.each do |document|
          parts << "\n<<< #{GEM} #{version} — #{document} >>>\n\n"
          parts << File.read(path_of(document))
        end

        parts.join
      end

      # For harnesses that take FILE PATHS rather than text (opencode's
      # `cfg.instructions`). The documents are handed over where they live, so
      # nothing is copied -- but a path carries no provenance, and provenance is
      # half the point. So a one-paragraph note saying which version is being
      # read is written out and listed first. It states where the knowledge came
      # from; it does not restate the knowledge.
      def paths
        return [] unless available?

        [provenance_note] + present.collect { |document| path_of(document) }
      end

      def provenance_note
        require_relative 'config'

        path = File.join(Config.user_dir, 'musa-provenance.md')
        FileUtils.mkdir_p(File.dirname(path))

        File.write(path, <<~NOTE)
          # Where the MusaDSL documentation in this context comes from

          The documents that follow (#{present.join(', ')}) are #{GEM} #{version}'s
          own, read from #{directory}. They are not Nota's copy of them: Nota does
          not keep one, because every copy of them that ever existed drifted from
          the original.#{absent.any? ? " This version does not carry #{absent.join(', ')}." : ''}

          Everything else -- the subsystem guides, the project-structure guide, the
          examples -- is in the same place and is read on request rather than kept
          here.
        NOTE

        path
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.delete('--paths')
    puts NotaKnowledgeBase::MusaDocs.paths
  else
    print NotaKnowledgeBase::MusaDocs.context
  end

  exit 0
end
