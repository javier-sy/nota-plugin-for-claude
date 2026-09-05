# frozen_string_literal: true

# The sqlite-vec loadable extension, obtained as an asset rather than as a gem.
#
# WHY THIS EXISTS. What the knowledge base needs is a loadable SQLite extension.
# What the `sqlite-vec` gem is, is that same loadable plus eight lines of Ruby:
#
#     def self.load(db) = db.load_extension(File.expand_path('vec0', __dir__))
#
# The gem could not be used, and the reason is not the binary. Upstream builds a
# perfectly good `vec0.dll` and ships it in the gem — but labelled
# `x86_64-mingw32`, a platform name RubyInstaller has never emitted (it reports
# `x64-mingw32` before Ruby 3.1 and `x64-mingw-ucrt` after). No Windows Ruby can
# resolve it, and while it stays in the Gemfile the lockfile cannot name
# `x64-mingw-ucrt` either — so `bundler/setup` refuses before the server runs a
# line. The same defect exists for Linux ARM64 (`arm64-linux` published,
# `aarch64-linux` reported): asg017/sqlite-vec#248, open and unanswered since
# 2025-11-04, with no upstream commits since 2026-05-18.
#
# So the dependency is on the artifact, not on its packaging: the loadable is
# fetched from the same GitHub Releases that already serve knowledge.db, cached
# under the user directory, and loaded by path. When the gem's platform strings
# are fixed upstream, this file is what can be deleted.
#
# THE VERSION IS PINNED, deliberately. An index is written by one vec0 and read
# by another; "whatever is newest" is not a property an index can rely on. It
# moves when the index is rebuilt against it, not on its own.

require "net/http"
require "uri"
require "zlib"
require "stringio"
require "fileutils"
require "rubygems/package"
require "rbconfig"

require_relative "config"

module NotaKnowledgeBase
  module VecExtension
    REPO = "asg017/sqlite-vec"
    RELEASE = "v0.1.9"

    # SQLite derives an extension's entry point from its file name: `vec0`
    # becomes `sqlite3_vec0_init`, which is the symbol upstream exports. The
    # basename is load-bearing, not cosmetic.
    BASENAME = "vec0"

    # Raised when the loadable is neither present nor obtainable. It carries what
    # the reader needs to act, because this is the one failure that leaves the
    # knowledge base unable to answer anything at all.
    class Unavailable < StandardError; end

    module_function

    # What this machine needs, as [os, cpu, file suffix] in upstream's naming.
    # Returns nil for a platform upstream does not build, which is a different
    # thing from a download that failed and must read differently.
    def target
      cpu = case RbConfig::CONFIG["host_cpu"]
            when /arm64|aarch64/ then "aarch64"
            when /x86_64|amd64|x64/ then "x86_64"
            end

      os, suffix = case RbConfig::CONFIG["host_os"]
                   when /darwin/ then ["macos", "dylib"]
                   when /linux/ then ["linux", "so"]
                   when /mingw|mswin|cygwin/ then ["windows", "dll"]
                   end

      return nil if cpu.nil? || os.nil?
      # Upstream builds every combination but Windows on ARM.
      return nil if os == "windows" && cpu != "x86_64"

      [os, cpu, suffix]
    end

    def platform_name
      "#{RbConfig::CONFIG['host_cpu']}-#{RbConfig::CONFIG['host_os']}"
    end

    # Where the cached loadable lives. Release and platform are DIRECTORIES and
    # never part of the file name: SQLite reads the entry point out of the
    # basename, so `vec0-macos-aarch64.dylib` makes it look for
    # `sqlite3_vec0macosaarch64_init` and the load fails. The file is `vec0`,
    # always; the path around it is what says which one it is, and a
    # pinned-version bump fetches a new file instead of trusting a stale one.
    def path
      os, cpu, suffix = target
      return nil if os.nil?

      File.join(Config.user_dir, "sqlite-vec", RELEASE, "#{os}-#{cpu}", "#{BASENAME}.#{suffix}")
    end

    def available?
      p = path
      !p.nil? && File.exist?(p)
    end

    def asset_url
      os, cpu, = target
      version = RELEASE.delete_prefix("v")
      asset = "sqlite-vec-#{version}-loadable-#{os}-#{cpu}.tar.gz"

      "https://github.com/#{REPO}/releases/download/#{RELEASE}/#{asset}"
    end

    # Make sure the loadable is on disk, downloading it once if it is not.
    # Returns its path; raises Unavailable with a reason a person can act on.
    def ensure!
      if target.nil?
        raise Unavailable,
              "sqlite-vec publishes no loadable extension for #{platform_name}. " \
              "The knowledge base cannot open without it."
      end

      destination = path
      return destination if File.exist?(destination)

      unless download(asset_url, destination)
        raise Unavailable,
              "Could not download the sqlite-vec extension for #{platform_name} from " \
              "#{asset_url}. The knowledge base cannot open without it. Check the network " \
              "connection and reopen the session; #{Config.cmd_ref('setup')} reports the status."
      end

      destination
    end

    # Fetch the tarball and extract the single loadable it holds. The write is
    # atomic: a half-written extension that SQLite then tries to load is a worse
    # failure than no extension at all.
    def download(url, destination)
      body = fetch(URI(url))
      return false if body.nil?

      FileUtils.mkdir_p(File.dirname(destination))
      temporary = "#{destination}.#{Process.pid}.part"

      Zlib::GzipReader.wrap(StringIO.new(body)) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          entry = tar.find { |e| e.file? && File.basename(e.full_name).start_with?(BASENAME) }
          return false if entry.nil?

          File.binwrite(temporary, entry.read)
        end
      end

      File.chmod(0o755, temporary)
      FileUtils.mv(temporary, destination)
      true
    rescue StandardError
      File.unlink(temporary) if temporary && File.exist?(temporary)
      false
    end

    # GitHub redirects asset downloads to its object storage.
    def fetch(uri, redirects_left = 5)
      return nil if redirects_left.negative?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 30

      response = http.request(Net::HTTP::Get.new(uri))

      case response
      when Net::HTTPRedirection then fetch(URI(response["location"]), redirects_left - 1)
      when Net::HTTPSuccess then response.body
      end
    rescue StandardError
      nil
    end

    # The one call the rest of the server makes.
    def load(db)
      db.load_extension(ensure!)
    end
  end
end
