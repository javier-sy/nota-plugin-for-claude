#!/usr/bin/env ruby
# frozen_string_literal: true

# What runs when a session opens.
#
# One job that nothing else can do, and one line that nothing else can say.
#
# The job: put musa-dsl's conceptual layer into context, read from the INSTALLED
# gem. Claude Code adds a SessionStart hook's stdout to the session, so this is
# the only way that text can be there BEFORE anyone asks a question. A tool
# cannot do it -- a tool answers when called, and by then the model has already
# decided how to think about the problem.
#
# The line: whether the plugin still needs setting up. This used to install the
# gems and download the index; both moved to the setup server's tools, where a
# reader can see them work and where the budget is hours rather than the 120
# seconds a hook gets. What is left here is one sentence naming the state and
# the command that fixes it -- said at session start, which is the only moment
# the reader is looking and has not asked for anything yet.
#
# Always exits 0: a session that cannot read a gem is a session that says so,
# not one that fails to open.

require_relative 'ensure_gems'
require_relative 'musa_docs'

begin
  # Only a report, and only when there is something to act on. The setup server
  # owns installing: one owner, nothing to race.
  status = NotaKnowledgeBase::EnsureGems.report
  puts status if status
rescue StandardError
  nil
end

begin
  print NotaKnowledgeBase::MusaDocs.context
rescue StandardError => e
  puts "[Nota] Could not read musa-dsl's documentation: #{e.class}: #{e.message}"
end

exit 0
