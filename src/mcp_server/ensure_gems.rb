# frozen_string_literal: true

# The MCP server's gems, installed by the plugin instead of by the reader, and
# installed by the server itself so that nothing has to be restarted.
#
# WHY THIS EXISTS. `/plugin install` copies files; `bundler/setup` narrows the
# load path to what is already there and installs nothing. So a fresh machine met
# the server with `Bundler::GemNotFound` and no server — and because the server
# is what carries `check_setup`, nothing left inside the session could say what
# was missing. It was inconsistent as well as unhelpful: the plugin already
# fetches a 27 MB index and a loadable extension without asking, and left seven
# gems to a line in the README.
#
# WHY IN THE SERVER AND NOT IN THE HOOK. The hook can install too — it needs no
# gems — but the harness starts the server before the hook finishes, so gems that
# arrive there serve the *next* session and the reader has to reopen. The server
# is the process that needs them, and a process that installs them before it
# loads them never has to die: `boot.rb` runs on stdlib alone, calls `provide!`,
# and only then requires Bundler and the server. The first session is a few
# seconds slower and works. The hook only reports (`report`), so there is one
# owner and nothing to race.
#
# WHERE THEY GO, AND WHY NOT THE OBVIOUS PLACE. Installing into the reader's
# default GEM_HOME would mutate their Ruby for the sake of one plugin, and on a
# system Ruby it would need root and fail. They go under the user directory
# instead — which also survives a plugin update, since the plugin's own cache is
# versioned and replaced. That location cannot be passed through `.mcp.json`
# (`${HOME}` is exactly what the harness cannot expand on Windows), but it does
# not have to be: Bundler reads `.bundle/config` beside the Gemfile, and this
# runs in a real Ruby that knows `Dir.home`. The server then finds the gems with
# the `BUNDLE_GEMFILE` it already has, and needs no new variable.
#
# WHAT IT COSTS. About five seconds and 16 MB, once. Every session after that
# pays only `bundle check`, which is local and needs no network.

require "open3"
require "yaml"
require "fileutils"
require "rbconfig"

require_relative "config"

module NotaKnowledgeBase
  module EnsureGems
    module_function

    # The installed plugin's root: the directory holding the Gemfile, one above
    # mcp_server/. In the source tree that resolves to `src/`, which has no
    # Gemfile — so running from a checkout does nothing, and a developer's own
    # bundle is never repointed by machinery meant for an install.
    def plugin_root
      File.expand_path("..", __dir__)
    end

    def gemfile
      File.join(plugin_root, "Gemfile")
    end

    def installed?
      File.exist?(gemfile)
    end

    def bundle_path
      File.join(Config.user_dir, "bundle")
    end

    # Runs the bundler that came with the running Ruby, by path and through that
    # same Ruby: `bundle` is not reliably on PATH on Windows, and the exe is a
    # Ruby script either way.
    def bundle_command(*arguments)
      exe = begin
        Gem.bin_path("bundler", "bundle")
      rescue StandardError
        File.join(RbConfig::CONFIG["bindir"], "bundle")
      end

      [RbConfig.ruby, exe, *arguments]
    end

    def environment
      { "BUNDLE_GEMFILE" => gemfile }
    end

    # Point Bundler at the user directory. Written only when it would change:
    # the file is read on every bundler run, and rewriting it each session would
    # be noise in something a reader may have edited on purpose.
    def write_bundle_config
      desired = { "BUNDLE_PATH" => bundle_path, "BUNDLE_WITHOUT" => "development" }
      path = File.join(plugin_root, ".bundle", "config")

      return true if File.exist?(path) && (YAML.safe_load_file(path) rescue nil) == desired

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, desired.to_yaml)
      true
    rescue StandardError
      false
    end

    def satisfied?
      _out, _err, status = Open3.capture3(environment, *bundle_command("check"))
      status.success?
    rescue StandardError
      false
    end

    # Called by boot.rb, in the server's own process, before Bundler exists.
    # Everything it says goes to stderr: stdout is the MCP transport, and one
    # stray line on it is a protocol error rather than a message.
    #
    # This is where the install lives, and the only place, so there is nothing
    # to race against — and it is what spares the reader a restart. The server
    # process is the one that needs the gems; a process that can install them
    # before it loads them does not have to die first.
    def provide!
      return true unless installed?
      return false unless write_bundle_config
      return true if satisfied?

      warn "[Nota] Installing the MCP server's Ruby dependencies into #{bundle_path} " \
           "(seven gems, about 16 MB; this happens once)."

      _out, err, status = Open3.capture3(environment, *bundle_command("install"))

      if status.success?
        warn "[Nota] Dependencies installed."
        true
      else
        warn "[Nota] Could not install the MCP server's dependencies: #{first_line(err)}"
        warn "[Nota] Install them by hand: bundle install --gemfile #{gemfile} --without development"
        false
      end
    rescue StandardError => e
      warn "[Nota] Could not install the MCP server's dependencies: #{e.class}: #{e.message}"
      false
    end

    # Called by the SessionStart hook, which runs beside the server and must not
    # install anything: one owner, no race. It only says what is about to happen,
    # so that a first session that takes a few seconds is explained rather than
    # merely slow.
    def report
      return nil unless installed?
      return nil if satisfied?

      "[Nota] The MCP server is installing its Ruby dependencies (seven gems, about 16 MB, " \
      "once). Its tools may take a few seconds longer than usual to answer the first time."
    rescue StandardError
      nil
    end

    def first_line(text)
      line = text.to_s.strip.split("\n").first
      line.nil? || line.empty? ? "no reason given" : line
    end
  end
end
