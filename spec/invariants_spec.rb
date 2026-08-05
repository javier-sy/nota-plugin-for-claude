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

require_relative "../src/mcp_server/lint"
require_relative "../src/mcp_server/chunker"
require_relative "../src/mcp_server/musa_docs"

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

  def with_override(path)
    previous = ENV.fetch("NOTA_MUSA_DSL_PATH", nil)
    ENV["NOTA_MUSA_DSL_PATH"] = path
    yield
  ensure
    ENV["NOTA_MUSA_DSL_PATH"] = previous
  end
end
