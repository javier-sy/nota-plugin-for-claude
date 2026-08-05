#!/usr/bin/env ruby
# frozen_string_literal: true

# What runs when a session opens.
#
# Two jobs, in this order because the second is the one whose output matters:
#
#   1. Keep knowledge.db current (silent; never fails the session)
#   2. Put musa-dsl's conceptual layer into context, read from the INSTALLED gem
#
# For SessionStart hooks, Claude Code adds stdout to the session context, so
# what step 2 prints is what the model reads. Step 1 prints nothing on success.
#
# Always exits 0: a session that cannot update an index or find a gem is a
# session that says so, not one that fails to open.

require_relative 'ensure_db'
require_relative 'musa_docs'

begin
  NotaKnowledgeBase::EnsureDB.run
rescue StandardError
  # Graceful degradation: an index that could not be refreshed is still an index.
end

begin
  print NotaKnowledgeBase::MusaDocs.context
rescue StandardError => e
  puts "[Nota] Could not read musa-dsl's documentation: #{e.class}: #{e.message}"
end

exit 0
