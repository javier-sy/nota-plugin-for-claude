# frozen_string_literal: true

# The invariants this plugin's design rests on.
#
# WHY THIS EXISTS, AND WHY IT IS SHORT. Coverage is not the point. Every example
# below corresponds to something that WENT WRONG and was found by hand: an index
# that kept the dead, a search that could not say it found nothing, a lookup that
# always answered whatever it had. Each was invisible while it lasted, because
# the failure mode of all of them is silence.
#
# What is asserted here is what nobody can check by reading: that absence is
# reported, that a name that does not exist is named as not existing, that
# pruning removes what went and nothing else.
#
# What is NOT asserted here is whether any of it is any good. Retrieval quality
# is tools/retrieval-battery.rb; whether the assistant's decisions change is the
# commissions protocol, and that is deferred.

require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../src/mcp_server/lint"
require_relative "../src/mcp_server/chunker"
require_relative "../src/mcp_server/musa_docs"
require_relative "../src/mcp_server/config"
require_relative "../src/mcp_server/vec_extension"
require_relative "../src/mcp_server/ensure_gems"

RSpec.describe "the lint" do
  # It runs when nothing else can, so it must not need anything.
  it "needs no key, no database and no network" do
    expect(NotaKnowledgeBase::Lint.report("x = 1")).to be_a(String)
  end

  it "reports a brace block on a parenthesis-free call, which is a syntax error" do
    report = NotaKnowledgeBase::Lint.report("at 1 { launch :x }\n")

    expect(report).to include("Certain")
    expect(report).to match(/SYNTAX ERROR|does not parse/)
  end

  it "reports integer division in a temporal value, and not its rational form" do
    expect(NotaKnowledgeBase::Lint.report("d = 1/4\n")).to include("INTEGER DIVISION")
    expect(NotaKnowledgeBase::Lint.report("d = 1/4r\n")).not_to include("INTEGER DIVISION")
  end

  it "reports a constructor used in a file that never included its module" do
    with_include = "include Musa::Series\nmelody = S(1, 2, 3)\n"
    without      = "melody = S(1, 2, 3)\n"

    expect(NotaKnowledgeBase::Lint.report(without)).to include("include Musa::Series")
    expect(NotaKnowledgeBase::Lint.report(with_include)).not_to include("has no `include")
  end

  # The two lists mean different things, and merging them would teach the reader
  # to discount both.
  it "keeps facts apart from shapes that are worth arguing" do
    report = NotaKnowledgeBase::Lint.report("include Musa::Series\nat 1 + start do\n  x = 1/4\nend\n")

    expect(report).to include("Certain")
    expect(report).to include("Worth arguing")
    expect(report.index("Certain")).to be < report.index("Worth arguing")
  end

  it "says a clean report is not a verdict on form" do
    expect(NotaKnowledgeBase::Lint.report("x = 1\n")).to include("says nothing about whether the FORM")
  end
end

RSpec.describe "the chunker" do
  # The bug: the best-practice directory moved and the lookup did not, so every
  # release shipped with zero best_practice chunks and nothing said so. `abort`
  # raises SystemExit, and naming both the exception and the message is the
  # difference between testing the behaviour and testing that something failed.
  it "refuses to build when a kind it expects produced nothing" do
    Dir.mktmpdir do |empty|
      expect { NotaKnowledgeBase::Chunker.chunk_all_sources(empty) }
        .to raise_error(SystemExit)
        .and output(/no chunks produced for/).to_stderr
    end
  end

  it "expects every kind a full build makes, best_practice among them" do
    expect(NotaKnowledgeBase::Chunker::EXPECTED_KINDS).to include("best_practice", "docs", "api")
  end
end

RSpec.describe "pruning the index" do
  # `upsert_chunks` inserts and replaces and never removes, so a document deleted
  # upstream answered questions for ever. Eleven chunks of two files musa-dsl had
  # deliberately deleted survived a rebuild and were still being quoted.
  it "removes what the build no longer produces, and only that" do
    require_relative "../src/mcp_server/db"

    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.db")
      db = NotaKnowledgeBase::DB.open(path)
      NotaKnowledgeBase::DB.create_schema(db)

      insert = lambda do |id, kind, source|
        db.execute("INSERT INTO chunks (id, content, kind, source) VALUES (?, ?, ?, ?)",
                   [id, "text", kind, source])
      end

      insert.call("docs/keep/0000", "docs", "musa-dsl/docs/kept.md")
      insert.call("docs/gone/0000", "docs", "musa-dsl/docs/deleted.md")
      insert.call("private_works/mine/0000", "private_works", "my-piece/score.rb")

      still_there = [NotaKnowledgeBase::Chunker::Chunk.new("docs/keep/0000", "text", { "kind" => "docs" })]
      pruned = NotaKnowledgeBase::DB.prune_absent(db, still_there)

      expect(pruned).to eq([["musa-dsl/docs/deleted.md", 1]])

      remaining = db.execute("SELECT id FROM chunks ORDER BY id").collect { |r| r["id"] }

      # The kept chunk stays, the absent one goes, and the user's own work is not
      # the build's to judge.
      expect(remaining).to eq(["docs/keep/0000", "private_works/mine/0000"])

      db.close
    end
  end
end

RSpec.describe "MusaDocs" do
  # The plugin depends on file names in another repository. It must describe what
  # it finds rather than assume it.
  it "answers about presence per document, not by version" do
    expect(NotaKnowledgeBase::MusaDocs::ALWAYS).to include("docs/idioms.md")
    expect(NotaKnowledgeBase::MusaDocs).not_to be_const_defined(:FLOOR)
  end

  it "serves what a tree has and names what it lacks" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "docs"))
      File.write(File.join(root, "docs", "idioms.md"), "# Idioms\n\n## 1. Something\n")

      with_override(root) do
        expect(NotaKnowledgeBase::MusaDocs.present).to eq(["docs/idioms.md"])
        expect(NotaKnowledgeBase::MusaDocs.absent).to eq(["docs/vocabulary.md"])

        context = NotaKnowledgeBase::MusaDocs.context
        expect(context).to include("Idioms")
        expect(context).to include("docs/vocabulary.md")
      end
    end
  end

  it "loads nothing, and says why, when the documents are not there" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "docs"))

      with_override(root) do
        expect(NotaKnowledgeBase::MusaDocs).not_to be_available
        expect(NotaKnowledgeBase::MusaDocs.context).to include("NOT loaded")
      end
    end
  end

  # A source of truth with no version is what this whole layer exists to prevent,
  # so using one must be impossible to do quietly.
  it "announces a working tree instead of passing it off as a release" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "docs"))
      File.write(File.join(root, "docs", "idioms.md"), "# Idioms\n")
      File.write(File.join(root, "docs", "vocabulary.md"), "# Vocabulary\n")

      with_override(root) do
        expect(NotaKnowledgeBase::MusaDocs.context).to include("WORKING TREE")
      end
    end
  end

  # WHY THIS ONE EXISTS, AND WHY IT NEEDS A SUBPROCESS. 1.0.2 gave the server its
  # own bundle — BUNDLE_PATH in .bundle/config, so installing Nota's dependencies
  # never touches the reader's Ruby. A configured BUNDLE_PATH makes Bundler point
  # GEM_HOME at that private bundle and empty GEM_PATH, and `Gem.path` collapses
  # to the one directory musa-dsl cannot be in. So `get_doc` and `list_docs`
  # answered "musa-dsl is not installed" to people who had it installed, for two
  # releases, on every platform — while the SessionStart hook, which runs in a
  # plain Ruby, read the same gem correctly in the same session.
  #
  # It was invisible to every existing example because none of them run under a
  # narrowed gem path. This one narrows it on purpose, in a subprocess, the way
  # Bundler does: the ambient GEM_HOME is captured by requiring bundler first,
  # then the environment is replaced.
  it "finds the user's musa-dsl even when the gem path has been narrowed to a bundle" do
    skip "musa-dsl is not installed here" if NotaKnowledgeBase::MusaDocs.specification.nil?

    musa_docs = File.expand_path("../src/mcp_server/musa_docs", __dir__)

    Dir.mktmpdir do |elsewhere|
      script = <<~RUBY
        require "bundler"
        ENV["GEM_HOME"] = #{elsewhere.inspect}
        ENV["GEM_PATH"] = ""
        Gem.clear_paths
        require #{musa_docs.inspect}
        puts NotaKnowledgeBase::MusaDocs.version.to_s
      RUBY

      found = IO.popen([RbConfig.ruby, "-e", script], &:read).to_s.strip

      expect(found).not_to be_empty
      expect(found).to match(/\A\d+\.\d+/)
    end
  end

  def with_override(path)
    previous = ENV.fetch("NOTA_MUSA_DSL_PATH", nil)
    ENV["NOTA_MUSA_DSL_PATH"] = path
    yield
  ensure
    ENV["NOTA_MUSA_DSL_PATH"] = previous
  end
end

RSpec.describe "what the harness is allowed to tell the server" do
  # WHY. A generated config is written on the machine that builds it and read on
  # the machine that runs it, and HOME has no value on any Windows install,
  # where the home directory is USERPROFILE. A "${HOME}/.config/nota" written
  # here reached a Windows user as
  #
  #   mcp-config-invalid: Missing environment variables: HOME
  #
  # — the whole server rejected, the plugin arriving with its skills and none of
  # its tools. The documented behaviour is softer (a warning, the literal text
  # passed through) and would have built a folder called "${HOME}" instead.
  #
  # Nothing here checks that the fallback is nice. It checks that the config does
  # not ask the harness for something the server can work out for itself.

  # The only two the server cannot know: where it was installed, and the user's key.
  # CLAUDE_PLUGIN_ROOT and VOYAGE_API_KEY the server cannot know; NOTA_RUBY is a
  # choice only the reader can make, and it carries its own default.
  ADMISSIBLE = %w[CLAUDE_PLUGIN_ROOT VOYAGE_API_KEY NOTA_RUBY].freeze

  Dir[File.join(__dir__, "..", "targets", "*.yml")].each do |target_file|
    it "asks #{File.basename(target_file, '.yml')} for nothing but the install root and the key" do
      env = YAML.load_file(target_file)["mcp_env"] || {}
      referenced = env.values.flat_map { |v| v.to_s.scan(/\$\{(\w+)/) }.flatten.uniq

      expect(referenced - ADMISSIBLE).to be_empty
    end
  end

  # A fresh install has no key yet, and /nota:setup is the skill that fixes that.
  # It cannot run if the server the skill inspects was rejected for the very
  # variable it was written to ask about.
  it "gives the key a default, so a keyless install still gets a server" do
    env = YAML.load_file(File.join(__dir__, "..", "targets", "claude-code.yml"))["mcp_env"]

    expect(env["VOYAGE_API_KEY"]).to eq("${VOYAGE_API_KEY:-}")
  end

  it "does not build a home directory in the opencode template either" do
    template = File.read(File.join(__dir__, "..", "scripts", "templates", "opencode-index.ts"))

    expect(template).not_to match(/process\.env\.HOME/)
  end

  # A hook command is a shell line, and the plugin root holds spaces and
  # backslashes on Windows. Unquoted it is not the path it spells — and that
  # applies to the interpreter too, now that it is a variable a reader sets to
  # something like C:\\Program Files\\Ruby34-x64\\bin\\ruby.exe.
  it "quotes both the interpreter and the path in the hook command" do
    generator = File.read(File.join(__dir__, "..", "scripts", "generate.rb"))

    expect(generator).to include(%(%("${NOTA_RUBY:-ruby}" "\#{prefix}\#{hook_script}")))
  end
end

RSpec.describe "Config" do
  # An unexpanded placeholder is the absence of a value, not a value.
  it "reads a placeholder the harness could not expand as nothing at all" do
    with_env("NOTA_USER_DIR" => "${HOME}/.config/nota") do
      expect(NotaKnowledgeBase::Config.user_dir).to eq(File.join(Dir.home, ".config", "nota"))
    end
  end

  it "still lets a harness override where the user's material lives" do
    with_env("NOTA_USER_DIR" => "/somewhere/else") do
      expect(NotaKnowledgeBase::Config.user_dir).to eq("/somewhere/else")
    end
  end

  # Empty is opencode saying "skills have no slash here". It is not an absence.
  it "keeps an empty command prefix, which means something" do
    with_env("NOTA_CMD_PREFIX" => "") do
      expect(NotaKnowledgeBase::Config.cmd_ref("setup")).to eq("the setup skill")
    end
  end

  def with_env(values)
    previous = values.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    values.each { |k, v| ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| ENV[k] = v }
  end
end

RSpec.describe "the sqlite-vec loadable" do
  # WHY. The knowledge base cannot be opened without it, and two ways of getting
  # it wrong are invisible until something fails far from the cause.

  # This one was committed and caught by hand in the same hour: the cache path
  # started as vec0-macos-aarch64.dylib, and SQLite — which reads the entry
  # point out of the basename — went looking for sqlite3_vec0macosaarch64_init
  # and did not find it. Release and platform belong to the directories.
  it "caches the extension under a file named vec0, whatever the platform" do
    path = NotaKnowledgeBase::VecExtension.path
    skip "no upstream build for this platform" if path.nil?

    expect(File.basename(path)).to match(/\Avec0\.(dylib|so|dll)\z/)
    expect(File.dirname(path)).to include(NotaKnowledgeBase::VecExtension::RELEASE)
  end

  # The gem publishes a Windows binary under a platform name no Ruby on Windows
  # reports (asg017/sqlite-vec#248 is the same defect for Linux ARM64). While it
  # is a dependency the lockfile cannot carry x64-mingw-ucrt, and bundler/setup
  # refuses on a platform the lock does not name — so the server never starts.
  # Nothing about that is visible in the diff that adds the gem back.
  it "is not a bundled gem, so the lockfile can carry Windows" do
    gemfile = File.read(File.join(__dir__, "..", "Gemfile"))
    lock = File.read(File.join(__dir__, "..", "Gemfile.lock"))

    expect(gemfile).not_to match(/^\s*gem ["']sqlite-vec["']/)
    expect(lock).to include("x64-mingw-ucrt")
  end
end

RSpec.describe "installing the server's gems" do
  # WHY. The hook writes a `.bundle/config` and runs `bundle install`, which is
  # the right thing to do inside an installed plugin and the wrong thing to do
  # inside a checkout: it would repoint a developer's own bundle at the user
  # directory, from a hook they did not run on purpose.
  #
  # What keeps them apart is a coincidence of layout worth stating out loud: the
  # installed plugin has Gemfile and mcp_server/ as siblings, and the source tree
  # has the Gemfile a level higher, so `src/Gemfile` does not exist. Anything
  # that moves the Gemfile or changes how the root is found silently turns the
  # guard off.
  it "does nothing when it is running from the source tree" do
    expect(NotaKnowledgeBase::EnsureGems.plugin_root).to eq(File.expand_path("../src", __dir__))
    expect(NotaKnowledgeBase::EnsureGems).not_to be_installed
  end

  # The reader is never asked for the six gems that exist for this suite.
  it "keeps the development group out of what it installs" do
    target = File.join(__dir__, "..", "targets", "claude-code.yml")

    expect(YAML.load_file(target)["mcp_env"]["BUNDLE_WITHOUT"]).to eq("development")
  end

  # The whole point of boot.rb: Bundler must not be the first thing to run, or
  # the process dies on a machine without the gems and never reaches the code
  # that installs them. Putting "-r bundler/setup" back in the command undoes it,
  # and nothing about that diff would say so.
  it "starts the server through boot.rb and not through bundler" do
    generator = File.read(File.join(__dir__, "..", "scripts", "generate.rb"))
    template = File.read(File.join(__dir__, "..", "scripts", "templates", "opencode-index.ts"))

    expect(generator).to include("mcp_server/boot.rb")
    expect(generator).not_to include(%("-r", "bundler/setup"))
    expect(template).to include("mcp_server/boot.rb")
    expect(template).not_to include(%("-r", "bundler/setup"))
  end
end

RSpec.describe "a platform the server cannot run on" do
  # WHY. On Windows ARM neither dependency exists: sqlite3 publishes no
  # aarch64-mingw-ucrt binary and cannot be compiled there (SQLite's config.sub
  # rejects the triplet), and sqlite-vec's only Windows loadable is x86_64.
  # Before this was detected, the reader got thirty seconds of nothing and then
  # CONNECT_TIMEOUT — a symptom with every cause hidden behind it.
  #
  # The predicate has to answer for both speakers: boot.rb, so the server stops
  # instead of spending the connection window, and the hook, whose output is the
  # only one a reader sees.
  it "is named, and names the way out, on Windows ARM" do
    with_host(cpu: "aarch64", os: "mingw-ucrt") do
      reason = NotaKnowledgeBase::EnsureGems.unsupported_reason

      expect(reason).to include("aarch64-mingw-ucrt")
      expect(reason).to include("NOTA_RUBY")
      expect(NotaKnowledgeBase::EnsureGems.provide!).to be(false)
    end
  end

  # The same machine with an x64 Ruby is a supported machine, and nothing must
  # make it look otherwise — that is the whole point of the advice above.
  it "says nothing about Windows on x64" do
    with_host(cpu: "x64", os: "mingw-ucrt") do
      expect(NotaKnowledgeBase::EnsureGems.unsupported_reason).to be_nil
    end
  end

  def with_host(cpu:, os:)
    previous = { "host_cpu" => RbConfig::CONFIG["host_cpu"], "host_os" => RbConfig::CONFIG["host_os"] }
    RbConfig::CONFIG["host_cpu"] = cpu
    RbConfig::CONFIG["host_os"] = os
    yield
  ensure
    previous.each { |k, v| RbConfig::CONFIG[k] = v }
  end
end
