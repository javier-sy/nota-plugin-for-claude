# frozen_string_literal: true

# Search functions backed by sqlite-vec.
#
# Searches both knowledge.db (public, downloadable) and private.db (local user works).
# Falls back gracefully when either database is not available.

require_relative "config"
require_relative "db"

module NotaKnowledgeBase
  module Search
    SETUP_HINT =
      "The plugin is not fully configured. " \
      "Please run #{Config.cmd_ref('setup')} to complete the initial setup."

    VOYAGE_ERROR_HINT =
      "The Voyage AI API key is not working (it may be expired, revoked, or mistyped). " \
      "Please run #{Config.cmd_ref('setup')} to diagnose the issue."

    module_function

    def db_path
      DB.default_db_path
    end

    def db_available?
      return true if File.exist?(db_path)

      # Fallback: attempt to download knowledge.db if the server startup
      # didn't manage to download it (e.g., network was unavailable then).
      require_relative "ensure_db"
      $stderr.puts "[musadsl-kb] knowledge.db not found, attempting download..."
      begin
        EnsureDB.run(db_path, force: true)
      rescue
        # Graceful degradation
      end

      File.exist?(db_path)
    end

    def api_key_configured?
      key = ENV["VOYAGE_API_KEY"].to_s
      !key.empty? && !key.include?("${")
    end

    # Check preconditions for search. Returns an error message string, or nil if ready.
    def check_preconditions
      return "[Knowledge base not found. #{SETUP_HINT}]" unless db_available?
      unless api_key_configured?
        return "[Voyage API key not configured — no VOYAGE_API_KEY environment variable found. #{SETUP_HINT}]"
      end

      nil
    end

    # Which database answers for which kind. The user's own material lives in
    # private.db and never shares a ranking with the public corpus: they answer
    # different questions and merging them lets whichever happens to be nearer
    # hide the other.
    PRIVATE_KINDS = %w[private_works analysis best_practice].freeze
    PUBLIC_KINDS = %w[docs api demo_readme demo_code gem_readme best_practice].freeze

    # Search one kind per query, several queries per call.
    #
    # `queries` is a list of `{kind:, query:, n_results:}`. Each is embedded and
    # ranked ON ITS OWN, under its own heading. Nothing is merged, because a
    # merged ranking answers "what most resembles the question" and the caller
    # asked something more specific than that: what does the conceptual layer
    # say, AND what is the signature, AND has this been done before. Those are
    # three questions and they deserve three answers.
    #
    # There is no `all`. A caller that does not know which layer it needs has not
    # finished forming its question, and an undifferentiated search will answer
    # the unformed version of it.
    def multi_search(queries)
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, private_db|
        sections = queries.collect do |spec|
          kind = spec[:kind].to_s
          query = spec[:query].to_s
          n_results = (spec[:n_results] || 5).to_i.clamp(1, 10)

          "## #{kind} — #{query}\n\n#{one_search(knowledge_db, private_db, kind, query, n_results)}"
        end

        sections.join("\n\n")
      end
    end

    def one_search(knowledge_db, private_db, kind, query, n_results)
      db = PRIVATE_KINDS.include?(kind) && !PUBLIC_KINDS.include?(kind) ? private_db : knowledge_db

      if db.nil?
        return "No private database yet: index a work with #{Config.cmd_ref('index')} " \
               "before asking about `#{kind}`."
      end

      embedding = Voyage.query_embedder.embed([query]).first
      results = DB.knn_search(db, embedding, kind: kind, n_results: n_results)

      # `best_practice` is the one kind that legitimately lives in both: the
      # plugin ships a few and the user keeps their own. They are still ranked
      # separately and labelled, never merged.
      if kind == "best_practice" && private_db
        mine = DB.knn_search(private_db, embedding, kind: kind, n_results: n_results)

        unless mine.empty?
          return [DB.format_results(results, query, kind: kind, collection_size: DB.kind_counts(knowledge_db)[kind].to_i),
                  "### Yours\n\n#{DB.format_results(mine, query, kind: kind)}"].join("\n\n")
        end
      end

      DB.format_results(results, query, kind: kind, collection_size: DB.kind_counts(db)[kind].to_i)
    end

    # Look up an identifier, which is not a search.
    #
    # WHY IT IS NOT KNN. Asking for `Chord#with_move` by name has a right answer,
    # and nearest-neighbour is the wrong primitive for finding one: measured over
    # the corpus, `kind: "api"` failed to fill five slots in ten of thirteen
    # lookups despite the API being more than half of everything indexed. The
    # `module` and `name` columns are populated on all 1341 API chunks and were
    # never consulted.
    #
    # So: exact, then prefix, then -- clearly labelled as a different thing --
    # semantic. And when none of the three finds it, SAY SO. The escalation the
    # skills have written down (knowledge base, then rubydoc, then source) can
    # only happen if the first step is capable of returning nothing, and until
    # now it always returned its five nearest chunks whatever they were.
    def api_lookup(module_name, method = "")
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, _private_db|
        rows = exact_api_rows(knowledge_db, module_name, method)

        unless rows.empty?
          return "Found by name.\n\n#{DB.format_results(rows, "#{module_name} #{method}".strip, kind: "api")}"
        end

        query = "#{module_name} #{method}".strip
        embedding = Voyage.query_embedder.embed([query]).first
        nearest = DB.knn_search(knowledge_db, embedding, kind: "api", n_results: 5)

        heading =
          "**Not found in the indexed API: `#{[module_name, method].reject(&:empty?).join('#')}`.** " \
          "No chunk carries that module or method name. What follows is what is " \
          "semantically nearest, which is a different thing and may be unrelated. " \
          "If the identifier is real, it is either not indexed or spelled differently " \
          "here -- check rubydoc.info before telling the user it does not exist."

        "#{heading}\n\n#{DB.format_results(nearest, query, kind: "api")}"
      end
    end

    # Exact then prefix match on the populated module/name columns.
    def exact_api_rows(db, module_name, method)
      sql_base = "SELECT * FROM chunks WHERE kind = 'api'"

      candidates =
        if method.to_s.empty?
          db.execute("#{sql_base} AND (name = ? OR module = ?) LIMIT 5", [module_name, module_name]) +
            db.execute("#{sql_base} AND (module LIKE ? OR name LIKE ?) LIMIT 5",
                       ["%#{module_name}", "#{module_name}%"])
        else
          db.execute("#{sql_base} AND name = ? AND module LIKE ? LIMIT 5", [method, "%#{module_name}%"]) +
            db.execute("#{sql_base} AND name = ? LIMIT 5", [method])
        end

      candidates.uniq { |row| row["id"] }.first(5).collect { |chunk| api_row_to_result(db, chunk) }
    end

    def api_row_to_result(db, chunk)
      {
        "content" => chunk["content"],
        "source" => DB.source_to_github_url(db, chunk["source"] || "unknown"),
        "rubydoc_url" => DB.source_to_rubydoc_url(db, chunk),
        "kind" => chunk["kind"],
        "section" => chunk["section"] || "",
        "module" => chunk["module"] || "",
        "distance" => nil
      }
    end

    # Works that resemble a description, each collection ranked on its own.
    #
    # The user's pieces used to be merged into the three slots of the public
    # demos and printed under a "Demo Descriptions" heading, which said they were
    # something they are not. Separate rankings, named for what they are: a
    # precedent someone else set is not the same evidence as a thing you did
    # yourself, and the assistant has to be able to tell them apart.
    def similar_works(description)
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, private_db|
        embedding = Voyage.query_embedder.embed([description]).first

        sections = []

        readme = DB.knn_search(knowledge_db, embedding, kind: "demo_readme", n_results: 3)
        sections << "## Public demos — what they are\n\n#{DB.format_results(readme, description, kind: 'demo_readme')}"

        code = DB.knn_search(knowledge_db, embedding, kind: "demo_code", n_results: 3)
        sections << "## Public demos — how they are wired\n\n#{DB.format_results(code, description, kind: 'demo_code')}"

        if private_db
          works = DB.knn_search(private_db, embedding, kind: "private_works", n_results: 3)
          unless works.empty?
            sections << "## Your own works\n\n#{DB.format_results(works, description, kind: 'private_works')}"
          end

          analyses = DB.knn_search(private_db, embedding, kind: "analysis", n_results: 3)
          unless analyses.empty?
            sections << "## Your own analyses\n\n#{DB.format_results(analyses, description, kind: 'analysis')}"
          end
        end

        sections.join("\n\n")
      end
    end

    # Read a whole document out of the installed musa-dsl gem.
    #
    # Not a search: a named read. The snippet a search returns is enough to route
    # to a document and not enough to decide anything, because the boundary
    # between two verbs lives in how a document relates its own parts, not in the
    # two thousand characters that most resembled the question.
    def get_doc(name)
      require_relative "musa_docs"

      reason = MusaDocs.missing_gem_because
      return "[#{reason}]" if reason

      candidates = [name, "docs/#{name}", "docs/#{name}.md",
                    "docs/subsystems/#{name}.md", "docs/guides/#{name}.md"]

      path = candidates.filter_map { |candidate| MusaDocs.path_of(candidate) }.first

      unless path
        available = list_docs
        return "No document named `#{name}` in musa-dsl #{MusaDocs.version}.\n\n#{available}"
      end

      relative = path.sub("#{MusaDocs.directory}/", "")

      "# #{relative} — musa-dsl #{MusaDocs.version}\n\n" \
        "_Read whole from the installed gem at #{MusaDocs.directory}._\n\n#{File.read(path)}"
    end

    # Enumerate what is there to be read. Listing a directory, not interpreting
    # it: which documents matter is the caller's judgement, not the server's.
    def list_docs
      require_relative "musa_docs"

      reason = MusaDocs.missing_gem_because
      return "[#{reason}]" if reason

      root = MusaDocs.directory
      files = Dir.glob(File.join(root, "docs", "**", "*.md")).sort

      return "musa-dsl #{MusaDocs.version} at #{root} ships no docs/." if files.empty?

      lines = files.collect do |file|
        relative = file.sub("#{root}/", "")
        first_heading = File.foreach(file).find { |line| line.start_with?("# ") }

        "- `#{relative.sub(%r{\Adocs/}, '').sub(/\.md\z/, '')}` — #{first_heading.to_s.sub(/\A# /, '').strip}"
      end

      "Documents in musa-dsl #{MusaDocs.version}, readable whole with `get_doc`:\n\n#{lines.join("\n")}"
    end

    # Open both DBs, yield, close, and catch Voyage AI errors gracefully.
    # private_db is nil if private.db doesn't exist (it's optional).
    def with_dbs
      knowledge_db = DB.open(DB.default_db_path)
      private_db_path = DB.default_private_db_path
      private_db = File.exist?(private_db_path) ? DB.open(private_db_path) : nil
      begin
        yield knowledge_db, private_db
      rescue RuntimeError => e
        if e.message.include?("Voyage AI")
          "[#{VOYAGE_ERROR_HINT}]"
        else
          raise
        end
      ensure
        knowledge_db.close
        private_db&.close
      end
    end
  end
end
