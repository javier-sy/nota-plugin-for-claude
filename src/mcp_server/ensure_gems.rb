# frozen_string_literal: true

# The MCP server's gems, installed by the plugin instead of by the reader, and
# installed by the server itself so that nothing has to be restarted.
#
# WHY THIS EXISTS. `/plugin install` copies files; `bundler/setup` narrows the
# load path to what is already there and installs nothing. So a fresh machine met
# the server with `Bundler::GemNotFound` and no server — and because the server
# is what carries `check_setup`, nothing left inside the session could say what
# was missing. It was inconsistent as well as unhelpful: the plugin already
# fetches a 9 MB index and a loadable extension without asking, and left seven
# gems to a line in the README.
#
# WHY FROM A TOOL AND NOT FROM A BOOT. Installing while starting up was tried
# twice, with seven gems and then with six, and both times it raced the thirty
# seconds the harness allows a server to answer `initialize` in. The race got
# closer and never ended, because its clock belongs to the machine. So nothing
# here runs during a boot any more: `install!` is called by a tool, whose budget
# is hours and whose output the reader actually sees. The setup server reaches
# that tool needing no gems at all — it speaks the protocol on the standard
# library, see `stdio_server.rb`.
#
# The hook only reports (`report`), so there is one owner and nothing to race.
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
require_relative "vec_extension"

module NotaKnowledgeBase
  module EnsureGems
    module_function

    # Whether this machine can run the knowledge base at all, and if not, a
    # sentence that names the way out.
    #
    # Windows on ARM is the case that produced this: Ruby there reports
    # `aarch64-mingw-ucrt`, and NEITHER of the two things the server rests on
    # exists for it. `sqlite3` publishes no binary (only `x64-mingw-ucrt` among
    # Windows platforms) and cannot be built from source either — SQLite's own
    # `config.sub` rejects the `aarch64-w64-windows-gnu` triplet. `sqlite-vec`
    # publishes one Windows loadable and it is x86_64. Neither is ours to fix,
    # and no lockfile entry conjures a gem that was never published.
    #
    # Read from the setup server, not from a boot. That server starts on every
    # platform, including the ones named here, which is what makes an answer
    # possible at all: a machine that cannot run the knowledge base can still
    # say so, in a tool result the reader sees, instead of spending the
    # connection window and reporting `CONNECT_TIMEOUT` — a symptom that hides
    # every cause.
    def unsupported_reason
      return nil unless VecExtension.target.nil?

      platform = VecExtension.platform_name

      if platform.include?("mingw") || platform.include?("mswin")
        "[Nota] The knowledge base cannot run on #{platform}: neither sqlite3 nor sqlite-vec " \
        "publishes a build for Windows on ARM, and sqlite3 cannot be compiled there. " \
        "Install a Ruby built for x64 — Windows runs it under emulation — and set NOTA_RUBY to " \
        "its ruby.exe, so the rest of your Ruby work keeps the interpreter you already have."
      else
        "[Nota] The knowledge base cannot run on #{platform}: sqlite-vec publishes no loadable " \
        "extension for it."
      end
    end

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

    # The environment a bundler subprocess runs in.
    #
    # There is one set of gems, because there is one process that needs them.
    # The knowledge base server either has them all or has none of them, and no
    # state in between is worth a name: the setup server, which is what asks
    # these questions, runs on the standard library and wants none of them.
    def environment
      { "BUNDLE_GEMFILE" => gemfile, "BUNDLE_WITHOUT" => "development" }
    end

    # Point Bundler at the user directory. Written only when it would change:
    # the file is read on every bundler run, and rewriting it each session would
    # be noise in something a reader may have edited on purpose.
    def write_bundle_config
      desired = { "BUNDLE_PATH" => bundle_path }
      path = File.join(plugin_root, ".bundle", "config")

      return true if File.exist?(path) && (YAML.safe_load_file(path) rescue nil) == desired

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, desired.to_yaml)
      true
    rescue StandardError
      false
    end

    # Whether the gems are already there.
    #
    # Asked of bundler rather than of a marker we wrote: a marker can disagree
    # with the directory, and a half-finished install is exactly the state that
    # has to be told apart from a finished one.
    def satisfied?
      _out, _err, status = Open3.capture3(environment, *bundle_command("check"))
      status.success?
    rescue StandardError
      false
    end

    # Returns [ok, output] so that a caller can show what happened -- this runs
    # from a tool, whose result the reader actually sees, unlike the stderr the
    # old design shouted into.
    def install!
      return [false, "the plugin is not installed (no Gemfile at #{gemfile})"] unless installed?
      return [false, "could not write #{File.join(plugin_root, '.bundle', 'config')}"] unless write_bundle_config

      out, err, status = Open3.capture3(environment, *bundle_command("install"))

      [status.success?, status.success? ? out : err]
    rescue StandardError => e
      [false, "#{e.class}: #{e.message}"]
    end

    # What the SessionStart hook says, if anything. It no longer installs
    # anything -- one owner, and it is the tool -- so this only names a state
    # the reader can act on, and stays quiet when there is nothing to act on.
    def report
      return nil unless installed?
      return nil if satisfied?

      "[Nota] The knowledge base is not installed yet. Run #{Config.cmd_ref('setup')} once " \
      "to finish setting it up; it takes a few seconds and only happens on a new machine."

    rescue StandardError
      nil
    end

    # The last lines, not the first. Bundler's verdict — "An error occurred while
    # installing sqlite3 (2.9.6), and Bundler cannot continue." — is at the end,
    # and the beginning is whatever the toolchain happened to complain about
    # first. Taking `stderr[0]` once reported a pacman permissions warning as the
    # cause of a platform that cannot compile SQLite at all.
    #
    # Lines rather than a search for known phrases: those are Bundler's wording
    # today, in whatever locale the machine happens to speak.
    def last_lines(text, count = 6)
      lines = text.to_s.split("\n").map(&:strip).reject(&:empty?)
      lines.empty? ? ["no reason given"] : lines.last(count)
    end
  end
end
