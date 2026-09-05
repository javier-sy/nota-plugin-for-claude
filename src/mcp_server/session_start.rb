#!/usr/bin/env ruby
# frozen_string_literal: true

# What runs when a session opens.
#
# Three jobs, in this order because the last is the one whose output matters:
#
#   0. Say if the server is still installing its gems (it installs them itself,
#      in its own process; this only explains a slower first session)
#   1. Keep knowledge.db current, and the sqlite-vec extension present (silent)
#   2. Put musa-dsl's conceptual layer into context, read from the INSTALLED gem
#
# For SessionStart hooks, Claude Code adds stdout to the session context, so
# what step 2 prints is what the model reads. Step 1 prints nothing on success.
#
# Always exits 0: a session that cannot update an index or find a gem is a
# session that says so, not one that fails to open.

require_relative 'ensure_gems'
require_relative 'ensure_db'
require_relative 'musa_docs'
require_relative 'vec_extension'

begin
  # Only a report. The server installs its own gems, in its own process, so that
  # nothing has to be reopened — this runs beside it and would race it. Silent
  # when the bundle is already satisfied, which is every session but the first.
  gems = NotaKnowledgeBase::EnsureGems.report
  puts gems if gems
rescue StandardError
  nil
end

begin
  NotaKnowledgeBase::EnsureDB.run
rescue StandardError
  # Graceful degradation: an index that could not be refreshed is still an index.
end

begin
  # Fetch the loadable extension once, here, so that the first question of the
  # session is not the one that pays for it. Silent either way: a download that
  # fails now is retried by the tool that needs it, which is also the only place
  # that can say what its absence costs.
  NotaKnowledgeBase::VecExtension.ensure!
rescue StandardError
  nil
end

begin
  print NotaKnowledgeBase::MusaDocs.context
rescue StandardError => e
  puts "[Nota] Could not read musa-dsl's documentation: #{e.class}: #{e.message}"
end

exit 0
