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
# So the work moved off the connection's critical path. This server needs only
# `mcp` and its pure-Ruby dependencies, about 6 MB, and it connects. What it
# owns is everything that has to work before the knowledge base does: saying
# what state the installation is in, and finishing it. Installing from a tool
# call rather than from a handshake changes the budget from thirty seconds to
# hours.
#
# The other server, `knowledge-base`, needs sqlite3 and the index. When those
# are missing it exits in under a hundred milliseconds with a line naming what
# it wants, instead of holding the connection open until it is killed. A reader
# then sees one server up and one down, which is a truthful picture, and the one
# that is up can explain it.
#
# WHAT DECIDES THE STATE. Nothing here records a stage. Every answer is read
# from the disk at the moment it is asked -- is the bundle complete, is the
# loadable there, is the index there -- because a stage we wrote down can
# disagree with the directory, and a half-finished install is precisely the
# state that has to be told apart from a finished one. That disagreement has
# already cost this plugin one silent bug.

require "mcp"

require_relative "config"
require_relative "ensure_gems"
require_relative "ensure_db"
require_relative "vec_extension"

module NotaKnowledgeBase
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

    def base_gems = EnsureGems.satisfied?(index: false) ? :present : :missing
    def index_gems = EnsureGems.satisfied?(index: true) ? :present : :missing

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

    # Everything the knowledge base needs before it can answer anything.
    def ready?
      index_gems == :present && loadable == :present && index != :missing
    end
  end
end

# What state the installation is in, and what to do about it.
#
# On the setup server on purpose: when the knowledge base cannot start, this is
# the only thing left that can say why.
class CheckSetupTool < MCP::Tool
  description(
    "Report what Nota still needs before the knowledge base can answer: the API key, " \
    "the Ruby dependencies, the sqlite-vec extension and the index itself. Reads the " \
    "installation from disk, so it works when the knowledge base server is not running — " \
    "which is when it is most needed."
  )

  class << self
    def call(server_context:)
      s = NotaKnowledgeBase::SetupState
      lines = ["## Nota setup", ""]

      lines << "- **Voyage API key**: #{api_key_line(s.api_key)}"
      lines << "- **Base dependencies**: #{s.base_gems == :present ? 'installed' : 'MISSING'}"
      lines << "- **Index dependencies**: #{index_gems_line(s.index_gems)}"
      lines << "- **sqlite-vec extension**: #{loadable_line(s.loadable)}"
      lines << "- **Knowledge index**: #{s.index == :missing ? 'not downloaded yet' : s.index}"
      lines << "- **User directory**: `#{NotaKnowledgeBase::Config.user_dir}`"
      lines << ""
      lines << next_step(s)

      MCP::Tool::Response.new([{ type: "text", text: lines.join("\n") }])
    end

    private

    # Asked, not assumed: a key that is set and rejected looks exactly like a
    # working one from here.
    def api_key_line(state)
      return "NOT CONFIGURED — set VOYAGE_API_KEY. A key comes from https://dash.voyageai.com/" if state == :missing

      require_relative "embeddings"
      NotaKnowledgeBase::Voyage::Client.new(input_type: "query").embed(["test"])
      "valid"
    rescue StandardError => e
      "SET BUT REJECTED by the API — expired, revoked or mistyped. #{e.message}"
    end

    def index_gems_line(state)
      return "installed" if state == :present

      reason = NotaKnowledgeBase::EnsureGems.unsupported_reason
      reason ? "NOT AVAILABLE — #{reason.sub('[Nota] ', '')}" : "MISSING — run install_dependencies"
    end

    def loadable_line(state)
      case state
      when :present then "`#{NotaKnowledgeBase::VecExtension.path}`"
      when :unsupported
        "NOT AVAILABLE for #{NotaKnowledgeBase::VecExtension.platform_name} — upstream publishes no build"
      else "not downloaded yet"
      end
    end

    # One sentence naming the next action, because a list of states is not an
    # instruction and the reader of this is usually someone who just installed
    # the plugin and does not know whether they are at fault.
    def next_step(state)
      return "Everything is in place. Reload plugins if the knowledge base is not connected yet." if state.ready?

      if state.index_gems == :missing && NotaKnowledgeBase::EnsureGems.unsupported_reason
        return "This machine cannot run the knowledge base as configured; see above. " \
               "Everything else — linting, the documentation in context — keeps working."
      end

      "**Next:** run `install_dependencies` to finish setting up. It takes a few seconds on a " \
      "new machine and happens once. Then reload plugins so the knowledge base server starts."
    end
  end
end

# Finishing the installation, from a tool call rather than from a handshake.
class InstallDependenciesTool < MCP::Tool
  description(
    "Finish setting Nota up: install the Ruby gems the knowledge base needs and fetch the " \
    "sqlite-vec extension. Safe to run more than once — it installs only what is missing. " \
    "The knowledge base server needs a plugin reload afterwards to pick them up."
  )

  class << self
    def call(server_context:)
      done = []

      reason = NotaKnowledgeBase::EnsureGems.unsupported_reason
      return refuse(reason) if reason

      if NotaKnowledgeBase::EnsureGems.satisfied?(index: true)
        done << "- Ruby dependencies: already installed"
      else
        ok, output = NotaKnowledgeBase::EnsureGems.install!(index: true)
        return failed("installing the Ruby dependencies", output) unless ok

        done << "- Ruby dependencies: installed"
      end

      begin
        NotaKnowledgeBase::VecExtension.ensure!
        done << "- sqlite-vec extension: ready"
      rescue NotaKnowledgeBase::VecExtension::Unavailable => e
        return failed("fetching the sqlite-vec extension", e.message)
      end

      done << ""
      done << "**Now reload plugins** so the knowledge base server starts. The index itself " \
              "downloads on the first question you ask it."

      MCP::Tool::Response.new([{ type: "text", text: done.join("\n") }])
    end

    private

    def refuse(reason)
      MCP::Tool::Response.new([{ type: "text", text: reason.sub("[Nota] ", "") }])
    end

    def failed(what, output)
      text = "Failed while #{what}.\n\n#{NotaKnowledgeBase::EnsureGems.last_lines(output).join("\n")}"
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end
  end
end

# Keeping the index current: what the SessionStart hook used to do silently.
class UpdateKnowledgeBaseTool < MCP::Tool
  description(
    "Check whether a newer knowledge index has been published and download it if so. " \
    "Downloading is all it does, so it works from this server without the knowledge base " \
    "running. Says which version it fetched, or that the local one is already current."
  )

  class << self
    def call(server_context:)
      updated = NotaKnowledgeBase::EnsureDB.run(force: true)

      text = if updated
               "Knowledge index updated to #{updated}, at `#{NotaKnowledgeBase::Config.knowledge_db_path}`. " \
               "Reload plugins, or start a new session, for the knowledge base to read it."
             else
               "The knowledge index is already current."
             end

      MCP::Tool::Response.new([{ type: "text", text: text }])
    rescue StandardError => e
      MCP::Tool::Response.new([{ type: "text", text: "Could not update the index: #{e.class}: #{e.message}" }])
    end
  end
end

module NotaKnowledgeBase
  def self.run_setup_server
    server = MCP::Server.new(
      name: "nota-setup",
      version: "1.0.0",
      instructions:
        "Nota's setup server. Reports what the plugin still needs and installs it. " \
        "It runs on pure-Ruby dependencies alone, so it answers even when the " \
        "knowledge base server cannot start — which is exactly when its answers matter.",
      tools: [CheckSetupTool, InstallDependenciesTool, UpdateKnowledgeBaseTool]
    )

    MCP::Server::Transports::StdioTransport.new(server).open
  end
end

NotaKnowledgeBase.run_setup_server if __FILE__ == $PROGRAM_NAME
