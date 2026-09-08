#!/usr/bin/env ruby
# frozen_string_literal: true

# How the knowledge base server starts, and what it does when it cannot.
#
# This one needs sqlite3, which is the half of the dependencies that is heavy
# and can need compiling. It does not install anything: installing from here is
# what used to burn the thirty seconds Claude Code allows a server to connect
# in, and be killed halfway through. The setup server owns that now, from a tool
# call, where waiting is free.
#
# WHEN THE GEMS ARE NOT THERE, IT STILL CONNECTS, WITH NO TOOLS. It used to exit
# 1 instead, on the reasoning that a reader who sees one server up and one down
# is being told something while a timeout tells them nothing. That reasoning was
# right about the reader and wrong about the harness, and the harness is what
# decides. Measured on Windows, 2026-09-08: a failed connection is written to
# `~/.claude/mcp-needs-auth-cache.json` with a timestamp, and for the next
# fifteen minutes the server is not started at all -- not in that session, and
# not in a new process either. The decision is taken before anything is
# launched, from that file.
#
# That window is not an edge case, it is the path every install takes. The
# failure happens while installing, because the gems are not there yet;
# `install_dependencies` then takes about ninety seconds; and the reader leaves
# and comes back as soon as it finishes. One of the test restarts landed nine
# seconds inside the window.
#
# So there must be no failure to cache. Connecting with an empty tool list costs
# nothing -- `stdio_server.rb` is the standard library -- and says the same
# thing to the model, which gates on whether the tools are there rather than on
# whether the server is: absent tools mean the skills refuse either way. What
# the reader loses is a red server in `/mcp`; what they gain is that the next
# session works. `check_setup` still says exactly what is missing.

require_relative 'config'

begin
  require 'bundler/setup'
rescue StandardError => e
  warn '[Nota] The knowledge base is not installed yet.'
  warn "  #{e.message.lines.first&.strip}"
  warn "[Nota] Run #{NotaKnowledgeBase::Config.cmd_ref('setup')} — the setup server is running " \
       'and can finish the installation.'

  require_relative 'stdio_server'

  NotaKnowledgeBase::StdioServer.run(
    name: 'musadsl-kb',
    version: '1.0.0',
    instructions:
      'The MusaDSL knowledge base is not installed yet, which is why this server offers no ' \
      "tools. Run #{NotaKnowledgeBase::Config.cmd_ref('setup')} to finish the installation.",
    tools: []
  )

  exit 0
end

require_relative 'server'

NotaKnowledgeBase.run_server
