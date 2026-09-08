#!/usr/bin/env ruby
# frozen_string_literal: true

# The server that answers when the other one cannot.
#
# WHY THERE ARE TWO. Claude Code gives a server thirty seconds to answer
# `initialize`. On a machine with no gems yet, installing them took longer than
# that, so the server was killed halfway through its own installation: the
# reader saw "Plugin is now active", then CONNECT_TIMEOUT, and no tools. The
# message explaining it went to stderr, which nobody reads, and `check_setup` --
# the tool written to diagnose exactly this -- lived on the server that had just
# died.
#
# So the work moved off the connection's critical path. This server needs no
# gems at all: it speaks the protocol on the standard library, in
# `stdio_server.rb`, so nothing it depends on can be missing when it starts.
# What it owns is everything that has to work before the knowledge base does --
# saying what state the installation is in, and finishing it. Installing from a
# tool call rather than from a handshake changes the budget from thirty seconds
# to hours.
#
# The other server, `knowledge-base`, needs sqlite3 and the index, and keeps
# using the `mcp` gem: by the time it runs, the gems are there, which is exactly
# what it needed established. When they are missing it connects anyway, with an
# empty tool list, because a connection that fails is cached by the harness and
# blocks the next fifteen minutes -- see `boot_knowledge.rb`. Either way the
# model sees no knowledge base tools, the skills refuse, and this server is what
# explains why.
#
# WHAT DECIDES THE STATE. Nothing here records a stage. Every answer is read
# from the disk at the moment it is asked -- is the bundle complete, is the
# loadable there, is the index there -- because a stage we wrote down can
# disagree with the directory, and a half-finished install is precisely the
# state that has to be told apart from a finished one. That disagreement has
# already cost this plugin one silent bug.

require_relative "stdio_server"

require_relative "config"
require_relative "ensure_gems"
require_relative "ensure_db"
require_relative "vec_extension"

module NotaKnowledgeBase
  # What to tell the reader when a server has to be picked up.
  #
  # NOT "reload plugins", which is what this said everywhere until it was
  # measured on Windows on 2026-09-08: neither `/reload-plugins` nor
  # `/reload-plugins --force` restarts an MCP server. Both reload skills, hooks
  # and agents, and the "2 plugin MCP servers" they report is a count of what is
  # declared, not of what was relaunched -- the running process kept the same
  # start time across both. So a session that installed the gems is a session
  # that cannot use them, and the only way out is a new process.
  #
  # Written for Claude Code by name, not for "your coding agent". Reloading
  # plugins is a Claude Code concept and `claude --continue` is its command;
  # opencode is the only other target and its channel is on hold, so nobody
  # knows what either sentence would be there. Naming a harness we do not ship
  # to would be inventing its behaviour. Listed in CLAUDE.md among the things to
  # revisit if that channel comes back.
  #
  # `claude --continue` is named because it is what makes this acceptable
  # advice: "restart" reads as "lose your conversation", and it does not.
  RESTART = "start a new Claude Code session — reloading plugins does not start the knowledge " \
            "base server. `claude --continue` comes back to this conversation."

  # What the installation looks like right now, read from disk.
  #
  # Shared by the tools below so that the report and the installer cannot
  # disagree about what is missing.
  module SetupState
    module_function

    def api_key
      raw = Config.env("VOYAGE_API_KEY")
      raw.nil? || raw.empty? ? :missing : :present
    end

    def gems = EnsureGems.satisfied? ? :present : :missing

    def loadable
      return :unsupported if VecExtension.target.nil?

      VecExtension.available? ? :present : :missing
    end

    def index
      path = Config.knowledge_db_path
      return :missing unless File.exist?(path)

      version = File.read("#{path}.version").strip rescue nil
      version ? "present (#{version})" : "present"
    end
  end

  # What state the installation is in, and what to do about it.
  #
  # On the setup server on purpose: when the knowledge base cannot start, this
  # is the only thing left that can say why.
  module CheckSetupTool
    NAME = "check_setup_tool"

    DESCRIPTION =
      "Report what Nota still needs before the knowledge base can answer: the API key, " \
      "the Ruby dependencies, the sqlite-vec extension and the index itself. Reads the " \
      "installation from disk, so it works when the knowledge base has no tools to offer — " \
      "which is when it is most needed."

    module_function

    def call
      s = SetupState
      lines = ["## Nota setup", ""]

      lines << "- **Voyage API key**: #{api_key_line(s.api_key)}"
      lines << "- **Ruby dependencies**: #{gems_line(s.gems)}"
      lines << "- **sqlite-vec extension**: #{loadable_line(s.loadable)}"
      lines << "- **Knowledge index**: #{s.index == :missing ? 'not downloaded yet' : s.index}"
      lines << "- **User directory**: `#{Config.user_dir}`"
      lines << ""
      lines << next_step(s)

      lines.join("\n")
    end

    # Asked, not assumed: a key that is set and rejected looks exactly like a
    # working one from here.
    def api_key_line(state)
      return "NOT CONFIGURED — set VOYAGE_API_KEY. A key comes from https://dash.voyageai.com/" if state == :missing

      require_relative "embeddings"
      Voyage::Client.new(input_type: "query").embed(["test"])
      "valid"
    rescue StandardError => e
      "SET BUT REJECTED by the API — expired, revoked or mistyped. #{e.message}"
    end

    def gems_line(state)
      return "installed" if state == :present

      reason = EnsureGems.unsupported_reason
      reason ? "NOT AVAILABLE — #{reason.sub('[Nota] ', '')}" : "MISSING — run install_dependencies"
    end

    def loadable_line(state)
      case state
      when :present then "`#{VecExtension.path}`"
      when :unsupported
        "NOT AVAILABLE for #{VecExtension.platform_name} — upstream publishes no build"
      else "not downloaded yet"
      end
    end

    # One sentence naming the next action, because a list of states is not an
    # instruction and the reader of this is usually someone who just installed
    # the plugin and does not know whether they are at fault.
    #
    # It names what is missing rather than always saying the same thing. The old
    # text said "run install_dependencies ... it takes a few seconds on a new
    # machine" in every unfinished state, including the one right after a
    # successful install -- so it described a situation the reader had just left,
    # and told them to repeat the step they had just run. That reads as if
    # nothing had happened. Reported from a clean Windows install, 2026-09-08.
    #
    # The unsupported guard is not conditioned on the gems any more: the reason
    # is that VecExtension has no build for this platform, and no state of the
    # bundle changes that.
    def next_step(state)
      if EnsureGems.unsupported_reason
        return "This machine cannot run the knowledge base as configured; see above. " \
               "Everything else — linting, the documentation in context — keeps working."
      end

      missing = []
      missing << "the Ruby dependencies" if state.gems == :missing
      missing << "the sqlite-vec extension" if state.loadable == :missing
      missing << "the knowledge index" if state.index == :missing

      return settled(state) if missing.empty?

      # The timing is reassurance for someone installing from scratch. Said to
      # someone who is only missing the index, it is just wrong.
      pace = state.gems == :missing ? " On a new machine that takes a few seconds, and happens once." : ""

      "**Next:** run `install_dependencies` — it fetches #{listed(missing)}.#{pace} " \
      "Then #{RESTART}"
    end

    # Nothing left to fetch. The key is the one thing this plugin cannot install
    # for the reader, so it is the only thing that can still be in the way.
    def settled(state)
      if state.api_key == :missing
        return "**Next:** set VOYAGE_API_KEY and start Claude Code from a terminal that has it. " \
               "Everything else is in place."
      end

      "Everything is in place. If its tools are still not there, #{RESTART}"
    end

    # "a", "a and b", "a, b and c".
    def listed(items)
      return items.first if items.size == 1

      "#{items[0..-2].join(', ')} and #{items.last}"
    end
  end

  # Finishing the installation, from a tool call rather than from a handshake.
  module InstallDependenciesTool
    NAME = "install_dependencies_tool"

    DESCRIPTION =
      "Finish setting Nota up: install the Ruby gems the knowledge base needs, fetch the " \
      "sqlite-vec extension, and download the knowledge index. Safe to run more than once — " \
      "it fetches only what is missing. The knowledge base server is picked up by a new " \
      "Claude Code session afterwards, not by reloading plugins."

    module_function

    def call
      done = []

      reason = EnsureGems.unsupported_reason
      return reason.sub("[Nota] ", "") if reason

      if EnsureGems.satisfied?
        done << "- Ruby dependencies: already installed"
      else
        ok, output = EnsureGems.install!
        return failed("installing the Ruby dependencies", output) unless ok

        done << "- Ruby dependencies: installed"
      end

      begin
        VecExtension.ensure!
        done << "- sqlite-vec extension: ready"
      rescue VecExtension::Unavailable => e
        return failed("fetching the sqlite-vec extension", e.message)
      end

      done << index_line

      done << ""
      done << "**Now** #{RESTART}"

      done.join("\n")
    end

    # The index is the fourth thing check_setup reports, and a tool that calls
    # itself "finish setting Nota up" while leaving one of the four undone is
    # lying about what it did. It was left out for a reason that has expired:
    # the download used to sit inside the knowledge base server's `initialize`,
    # where the thirty-second window made it impossible. From here the budget is
    # hours, and EnsureDB needs no gem to do it.
    #
    # A failed download does NOT fail this tool. The gems and the extension are
    # installed by then, and that work is not thrown away because a network
    # dropped -- `search` fetches the index on demand anyway, so the retry is
    # already built and the honest thing is to say so.
    def index_line
      before = File.exist?(Config.knowledge_db_path)
      updated = EnsureDB.run(force: true)

      if updated
        "- Knowledge index: downloaded (#{updated})"
      elsif before || File.exist?(Config.knowledge_db_path)
        "- Knowledge index: already current"
      else
        "- Knowledge index: NOT downloaded — no release was reachable. It will be fetched " \
        "with your first question."
      end
    rescue StandardError => e
      "- Knowledge index: NOT downloaded (#{e.class}: #{e.message}). It will be fetched " \
      "with your first question."
    end

    def failed(what, output)
      "Failed while #{what}.\n\n#{EnsureGems.last_lines(output).join("\n")}"
    end
  end

  # Keeping the index current: what the SessionStart hook used to do silently.
  module UpdateKnowledgeBaseTool
    NAME = "update_knowledge_base_tool"

    DESCRIPTION =
      "Check whether a newer knowledge index has been published and download it if so. " \
      "Downloading is all it does, so it works from this server without the knowledge base " \
      "running. Says which version it fetched, or that the local one is already current."

    module_function

    def call
      updated = EnsureDB.run(force: true)

      if updated
        "Knowledge index updated to #{updated}, at `#{Config.knowledge_db_path}`. " \
        "The next question you ask reads it; nothing needs restarting."
      else
        "The knowledge index is already current."
      end
    end
  end

  TOOLS = [CheckSetupTool, InstallDependenciesTool, UpdateKnowledgeBaseTool].freeze

  def self.run_setup_server
    StdioServer.run(
      name: "nota-setup",
      version: "1.0.0",
      instructions:
        "Nota's setup server. Reports what the plugin still needs and installs it. " \
        "It runs on the standard library alone, so it answers even when the knowledge " \
        "base has nothing to offer — which is exactly when its answers matter.",
      tools: TOOLS.map { |tool| StdioServer::Tool.new(tool::NAME, tool::DESCRIPTION, tool.method(:call)) }
    )
  end
end

NotaKnowledgeBase.run_setup_server if __FILE__ == $PROGRAM_NAME
