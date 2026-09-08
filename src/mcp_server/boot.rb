#!/usr/bin/env ruby
# frozen_string_literal: true

# How the setup server starts.
#
# Nothing but stdlib runs before EnsureGems: on a machine with no gems, asking
# Bundler first kills the server at the first instruction, and the code that
# knows how to fix that is never reached.
#
# What it installs here is only the base group -- six pure-Ruby gems, about
# 6 MB, no compilation. That is the one install still inside the thirty seconds
# Claude Code allows for `initialize`, and it is small enough to fit. Everything
# that made a first install overrun -- sqlite3, the loadable, the 27 MB index --
# is installed later by the install_dependencies tool, where the budget is hours
# rather than seconds.
#
# Everything printed before the transport opens goes to stderr. Stdout belongs
# to the MCP protocol from the first byte.

require_relative 'ensure_gems'

unless NotaKnowledgeBase::EnsureGems.provide!
  warn '[Nota] The setup server cannot start without its base dependencies.'
  exit 1
end

require 'bundler/setup'
require_relative 'setup_server'

NotaKnowledgeBase.run_setup_server
