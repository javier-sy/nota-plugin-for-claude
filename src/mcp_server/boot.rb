#!/usr/bin/env ruby
# frozen_string_literal: true

# How the setup server starts: by needing nothing.
#
# Claude Code gives a server thirty seconds to answer `initialize`. Every design
# that put an install inside that window lost the race on a cold machine -- first
# with seven gems, then, after the work was split in two, with six. Each attempt
# made the race closer and none of them ended it, because the clock belongs to
# the machine and not to us.
#
# Vendoring `mcp` was the next attempt and it failed on a measurement:
# `mcp/tool/schema.rb` requires json_schemer at load time, json_schemer requires
# bigdecimal, and bigdecimal carries a C extension and stopped being a default
# gem in Ruby 3.4. (`require "mcp"` on its own does miss that -- MCP::Tool is
# autoloaded -- which is why the first measurement passed and meant nothing.)
#
# So there is no gem here at all. `stdio_server.rb` speaks the five methods this
# server needs, on the standard library. Nothing to install, nothing to
# download, nothing that can be missing: it answers, and from there it can say
# what the rest of the plugin still needs and install it from a tool call, where
# the budget is hours.

require_relative "setup_server"

NotaKnowledgeBase.run_setup_server
