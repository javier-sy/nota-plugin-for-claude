#!/usr/bin/env ruby
# frozen_string_literal: true

# How the MCP server starts, and why it is not `ruby -r bundler/setup server.rb`.
#
# That command asks Bundler for the gems before any code of ours runs, so on a
# machine that does not have them yet it dies at the first instruction and the
# harness reports a server that failed to start. Nothing we could write would be
# reached — including the part that knows how to fix it.
#
# So the entry point is this file, which uses nothing but stdlib: it makes sure
# the gems exist, and only then loads Bundler and the server. The reader waits a
# few seconds on their first session instead of being told to reopen it.
#
# Everything printed before the transport opens goes to stderr. Stdout belongs to
# the MCP protocol from the first byte.

require_relative 'ensure_gems'

unless NotaKnowledgeBase::EnsureGems.provide!
  warn '[Nota] The knowledge base server cannot start without its dependencies.'
  exit 1
end

require 'bundler/setup'
require_relative 'server'

NotaKnowledgeBase.run_server
