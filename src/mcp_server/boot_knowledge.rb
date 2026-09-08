#!/usr/bin/env ruby
# frozen_string_literal: true

# How the knowledge base server starts, and why it gives up quickly.
#
# This one needs sqlite3, which is the half of the dependencies that is heavy
# and can need compiling. It does not install anything: installing from here is
# what used to burn the thirty seconds Claude Code allows a server to connect
# in, and be killed halfway through. The setup server owns that now, from a tool
# call, where waiting is free.
#
# So when the gems are not there this exits at once. `bundler/setup` raises in
# about ninety milliseconds with the name of the gem it wanted, against thirty
# seconds of a connection held open and then dropped -- and a reader who sees
# one server up and one down, with the one that is up able to explain it, is
# being told something. A timeout tells them nothing.

begin
  require 'bundler/setup'
rescue StandardError => e
  warn '[Nota] The knowledge base is not installed yet.'
  warn "  #{e.message.lines.first&.strip}"
  warn '[Nota] Run /nota:setup — the setup server is running and can finish the installation.'
  exit 1
end

require_relative 'server'

NotaKnowledgeBase.run_server
