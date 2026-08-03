# frozen_string_literal: true

# sqlite-vec database management for MusaDSL knowledge base.
#
# Schema:
#   chunks     — metadata + content (id, content, kind, source, etc.)
#   chunks_vec — vec0 virtual table for KNN search (chunk_id, embedding float[1024])
#
# Collections (kind values):
#   docs, api, demo_readme, demo_code, gem_readme, private_works

require "sqlite3"
require "sqlite_vec"

require_relative "config"
require_relative "embeddings"

module NotaKnowledgeBase
  module DB
    COLLECTION_NAMES = %w[docs api demo_readme demo_code gem_readme best_practice].freeze
    PRIVATE_COLLECTION = "private_works"
    ANALYSIS_COLLECTION = "analysis"
    BEST_PRACTICE_COLLECTION = "best_practice"

    module_function

    def default_db_path
      env_path = ENV["KNOWLEDGE_DB_PATH"]
      return env_path if env_path

      File.join(__dir__, "knowledge.db")
    end

    STABLE_PRIVATE_DB_DIR = Config.user_dir

    def default_private_db_path
      env_path = ENV["PRIVATE_DB_PATH"]
      return env_path if env_path

      File.join(STABLE_PRIVATE_DB_DIR, "private.db")
    end

    def open(path = nil)
      db_path = path || default_db_path
      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true
      db.enable_load_extension(true)
      SqliteVec.load(db)
      db.enable_load_extension(false)
      db
    end

    def create_schema(db)
      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS chunks (
          id TEXT PRIMARY KEY,
          content TEXT NOT NULL,
          kind TEXT NOT NULL,
          source TEXT,
          section TEXT,
          module TEXT,
          name TEXT,
          node_type TEXT,
          content_hash TEXT
        )
      SQL

      db.execute(<<~SQL)
        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_vec USING vec0(
          chunk_id TEXT PRIMARY KEY,
          embedding float[1024] distance_metric=cosine
        )
      SQL

      db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      SQL
    end

    def set_metadata(db, key, value)
      db.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)", [key, value])
    end

    def get_metadata(db, key)
      row = db.execute("SELECT value FROM metadata WHERE key = ?", [key]).first
      row && row["value"]
    end

    # Transform a relative source path to a GitHub URL using stored metadata.
    # Source paths are relative like "musa-dsl/lib/..." where the first component
    # is the repo name. Returns the original path unchanged if no repo metadata
    # is found (e.g., private_works).
    def source_to_github_url(db, source_path)
      return source_path unless source_path

      parts = source_path.split("/", 2)
      return source_path unless parts.length == 2

      repo_name, rest_of_path = parts
      tag = get_metadata(db, "repo:#{repo_name}")
      return source_path unless tag

      owner = get_metadata(db, "github_owner") || "javier-sy"
      "https://github.com/#{owner}/#{repo_name}/blob/#{tag}/#{rest_of_path}"
    end

    # Build a rubydoc.info URL for an API chunk, using the module/name/node_type metadata.
    # Returns nil for non-API chunks or internal definitions (nested classes).
    #
    # Rules:
    # - module/class chunks: only if module_path ends with name (self-referential, not nested)
    # - method chunks:           append #name-instance_method
    # - singleton_method chunks: append #name-class_method
    def source_to_rubydoc_url(db, chunk)
      return nil unless chunk["kind"] == "api"

      module_path = chunk["module"].to_s
      name        = chunk["name"].to_s
      node_type   = chunk["node_type"].to_s
      source      = chunk["source"].to_s

      return nil if module_path.empty? || name.empty?

      gem_name = source.split("/").first
      return nil unless gem_name

      tag = get_metadata(db, "repo:#{gem_name}")
      return nil unless tag

      version    = tag.sub(/^v/, "")
      module_url = module_path.gsub("::", "/")
      base       = "https://www.rubydoc.info/gems/#{gem_name}/#{version}/#{module_url}"

      case node_type
      when "module", "class"
        name_parts   = name.split("::")
        module_parts = module_path.split("::")
        return nil unless module_parts.last(name_parts.length) == name_parts

        base
      when "method"
        "#{base}##{name}-instance_method"
      when "singleton_method"
        "#{base}##{name}-class_method"
      end
    end

    # Upsert chunks with Voyage AI embeddings into both tables.
    def upsert_chunks(db, chunks, embedder: nil, collection_override: nil)
      embedder ||= Voyage.document_embedder
      batch_size = 100

      chunks.each_slice(batch_size).with_index do |batch, batch_idx|
        $stderr.puts "  Embedding batch #{batch_idx + 1} (#{batch.length} chunks)..."

        texts = batch.map(&:content)
        embeddings = embedder.embed(texts)

        db.transaction do
          batch.each_with_index do |chunk, i|
            kind = collection_override || chunk.metadata["kind"] || "docs"
            embedding = embeddings[i]

            db.execute(
              "INSERT OR REPLACE INTO chunks (id, content, kind, source, section, module, name, node_type, content_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
              [
                chunk.id,
                chunk.content,
                kind,
                chunk.metadata["source"],
                chunk.metadata["section"],
                chunk.metadata["module"],
                chunk.metadata["name"],
                chunk.metadata["node_type"],
                chunk.metadata["content_hash"]
              ]
            )

            # sqlite-vec: vec0 virtual tables don't support INSERT OR REPLACE,
            # so delete any existing row first, then insert.
            vec_blob = embedding.pack("f*")
            db.execute("DELETE FROM chunks_vec WHERE chunk_id = ?", [chunk.id])
            db.execute(
              "INSERT INTO chunks_vec (chunk_id, embedding) VALUES (?, ?)",
              [chunk.id, vec_blob]
            )
          end
        end
      end
    end

    # How many neighbours to ask sqlite-vec for, given that the kind filter is
    # applied AFTER the search.
    #
    # It has to be applied after: vec0 tables carry no metadata columns
    # (see the schema above), so the filter cannot go inside the MATCH. That
    # makes this a matter of CORRECTNESS, not of tuning, because the corpus is
    # heavily skewed -- `api` is around two thirds of it and `docs` around a
    # thirtieth. Asking for the ten nearest chunks overall and then keeping the
    # `docs` ones returned NOTHING for any docs query, however well that
    # collection was embedded: the whole conceptual layer of the documentation
    # was unreachable while appearing to be indexed.
    #
    # So over-fetch in inverse proportion to the kind's share of the corpus: a
    # minority kind gets the same chance of filling its results as a majority
    # one. The table is small and a large `k` costs almost nothing.
    KNN_OVERSHOOT = 3

    # The conceptual layer, and how much of an undifferentiated search is kept
    # for it.
    #
    # WHY THIS EXISTS. Once the filtering bug above was fixed, `kind: "docs"`
    # answers ten out of ten composition questions and lands on the right
    # section -- "how do I loop a sequence of notes" comes back at
    # `sequencer.md > When is this the answer`. The SAME questions asked with
    # `kind: "all"` bring the conceptual layer into the top five three times out
    # of ten. The demos bury it: 830 chunks of 2359, and a demo README describes
    # what a piece does in the very register the question is asked in, so it wins
    # on similarity fairly.
    #
    # That is the trap. An undifferentiated search rewards what RESEMBLES the
    # question, and the layer that says *when is this the answer* does not
    # resemble the question -- it answers it. Left to similarity alone, the
    # assistant gets back examples that confirm the framing it already had, which
    # is the failure the modelling gate exists to prevent.
    #
    # So reserve room rather than hope. Not a boost -- the conceptual results are
    # still the nearest ones of their kind, and if there are none the slots go
    # back to everybody else.
    CONCEPTUAL_KIND = "docs"
    CONCEPTUAL_QUOTA = 0.4

    # ...and only when the conceptual layer is actually close to the question.
    #
    # Reserving room unconditionally pads a "signature of Chord#with_move" with
    # two prose chunks that displace two API ones. Measured over the battery, the
    # two cases separate cleanly by how far the nearest conceptual chunk sits
    # from the nearest chunk overall: 1.19-1.24x for questions about what to do,
    # 1.43-1.81x for questions about a signature. A question that already knows
    # the name it is asking about does not need to be told when to use it.
    #
    # Calibrated on this corpus. What would invalidate it: a large change in the
    # proportion of conceptual text, or a different embedding model -- the ratio
    # is scale-free but the gap between the two populations may not survive
    # either. Re-run tools like the F3 battery before trusting it after such a
    # change.
    CONCEPTUAL_PROXIMITY = 1.3

    def knn_fetch_limit(db, kind, n_results)
      counts = kind_counts(db)

      # An undifferentiated search has to over-fetch too, and for the same
      # reason: reserving room for the conceptual layer does nothing if the
      # layer never reaches the candidate pool. Fifteen neighbours of a corpus
      # where `docs` is one chunk in twenty contain, on average, less than one
      # of them -- which is exactly what the measurement showed. Fetch as if the
      # search were FOR the conceptual layer, and then let everybody compete.
      kind = CONCEPTUAL_KIND if kind == "all"

      total = counts.values.sum
      of_kind = counts[kind].to_i

      return n_results * 2 if total.zero? || of_kind.zero?

      [(n_results * KNN_OVERSHOOT * total.to_f / of_kind).ceil, total].min
    end

    # Chunks per kind, read once per database.
    def kind_counts(db)
      @kind_counts ||= {}
      @kind_counts[db.object_id] ||=
        db.execute("SELECT kind, COUNT(*) AS n FROM chunks GROUP BY kind")
          .to_h { |row| [row["kind"], row["n"]] }
    end

    # Low-level KNN search: takes a pre-computed embedding, returns raw result hashes.
    # Does NOT call Voyage — caller is responsible for embedding the query.
    def knn_search(db, query_embedding, kind: "all", n_results: 5)
      vec_blob = query_embedding.pack("f*")

      # Over-fetch to allow filtering, then trim to n_results
      fetch_limit = knn_fetch_limit(db, kind, n_results)

      # KNN search via sqlite-vec
      knn_rows = db.execute(
        "SELECT chunk_id, distance FROM chunks_vec WHERE embedding MATCH ? AND k = ? ORDER BY distance",
        [vec_blob, fetch_limit]
      )

      # Join with chunks table for metadata and filter by kind
      all_results = []
      kinds_to_search = if kind == "all"
                          COLLECTION_NAMES + [PRIVATE_COLLECTION, ANALYSIS_COLLECTION]
                        else
                          [kind]
                        end

      knn_rows.each do |row|
        chunk = db.execute("SELECT * FROM chunks WHERE id = ?", [row["chunk_id"]]).first
        next unless chunk
        next unless kinds_to_search.include?(chunk["kind"])

        source      = chunk["source"] || "unknown"
        source      = source_to_github_url(db, source)
        rubydoc_url = source_to_rubydoc_url(db, chunk)

        all_results << {
          "content"     => chunk["content"],
          "source"      => source,
          "rubydoc_url" => rubydoc_url,
          "kind"        => chunk["kind"],
          "section"     => chunk["section"] || "",
          "module"      => chunk["module"] || "",
          "distance"    => row["distance"]
        }

      end

      kind == "all" ? with_conceptual_quota(all_results, n_results) : all_results.first(n_results)
    end

    # Keeps the nearest results, but reserves part of them for the conceptual
    # layer when the search did not ask for a kind.
    #
    # Order is preserved by distance within each group and across the merge, so
    # a reader still sees the nearest thing first; what changes is only which
    # ones survive the cut.
    def with_conceptual_quota(results, n_results)
      return results.first(n_results) if results.length <= n_results

      reserved = [(n_results * CONCEPTUAL_QUOTA).floor, 1].max
      nearest = results.first["distance"].to_f

      conceptual = results
                   .select { |r| r["kind"] == CONCEPTUAL_KIND }
                   .select { |r| nearest.zero? || r["distance"].to_f / nearest <= CONCEPTUAL_PROXIMITY }
                   .first(reserved)

      return results.first(n_results) if conceptual.empty?

      rest = (results - conceptual).first(n_results - conceptual.length)

      (conceptual + rest).sort_by { |r| r["distance"] }
    end

    # Search for similar chunks using KNN, optionally filtering by kind.
    # Returns formatted markdown string. Embeds the query via Voyage AI.
    def search_collections(db, query, kind: "all", n_results: 5, embedder: nil)
      embedder ||= Voyage.query_embedder

      query_embedding = embedder.embed([query]).first
      results = knn_search(db, query_embedding, kind: kind, n_results: n_results)
      format_results(results, query)
    end

    def format_results(results, query)
      return "No results found for: '#{query}'" if results.empty?

      parts = results.each_with_index.map do |result, i|
        header = "### Result #{i + 1}"
        source_info = "**Source**: #{result['source']}"
        source_info += " > #{result['section']}" unless result["section"].to_s.empty?
        source_info += " (#{result['module']})" unless result["module"].to_s.empty?
        source_info += "\n**Docs**: #{result['rubydoc_url']}" if result["rubydoc_url"]

        content = result["content"]
        content = content[0, 2000] + "\n... (truncated)" if content.length > 2000

        "#{header}\n#{source_info}\n\n#{content}"
      end

      parts.join("\n\n---\n\n")
    end

    def collection_stats(db)
      stats = {}
      (COLLECTION_NAMES + [PRIVATE_COLLECTION, ANALYSIS_COLLECTION]).each do |kind|
        row = db.execute("SELECT COUNT(*) AS cnt FROM chunks WHERE kind = ?", [kind]).first
        count = row["cnt"]
        stats[kind] = count if count > 0
      end
      stats
    end

    # List private works with chunk counts.
    # Returns array of hashes: [{"work_name" => "...", "chunk_count" => N}, ...]
    def list_works(db)
      db.execute(<<~SQL)
        SELECT
          substr(source, 1, instr(source, '/') - 1) AS work_name,
          COUNT(*) AS chunk_count
        FROM chunks
        WHERE kind = 'private_works'
        GROUP BY work_name
        ORDER BY work_name
      SQL
    end

    # Remove all chunks for a private work (from both chunks and chunks_vec tables).
    # Returns the number of chunks deleted.
    def remove_work_chunks(db, work_name)
      pattern = "#{work_name}/%"

      # Count before deletion for reporting
      row = db.execute(
        "SELECT COUNT(*) AS cnt FROM chunks WHERE kind = 'private_works' AND source LIKE ?",
        [pattern]
      ).first
      count = row["cnt"]

      return 0 if count == 0

      db.transaction do
        # Delete vectors first (referential integrity)
        db.execute(<<~SQL, [pattern])
          DELETE FROM chunks_vec
          WHERE chunk_id IN (
            SELECT id FROM chunks
            WHERE kind = 'private_works' AND source LIKE ?
          )
        SQL

        # Delete chunk metadata
        db.execute(
          "DELETE FROM chunks WHERE kind = 'private_works' AND source LIKE ?",
          [pattern]
        )
      end

      count
    end

    # Remove all analysis chunks for a work (from both chunks and chunks_vec tables).
    # Analysis chunks have kind='analysis' and source like "work_name/analysis".
    # Returns the number of chunks deleted.
    def remove_analysis_chunks(db, work_name)
      pattern = "#{work_name}/%"

      row = db.execute(
        "SELECT COUNT(*) AS cnt FROM chunks WHERE kind = 'analysis' AND source LIKE ?",
        [pattern]
      ).first
      count = row["cnt"]

      return 0 if count == 0

      db.transaction do
        db.execute(<<~SQL, [pattern])
          DELETE FROM chunks_vec
          WHERE chunk_id IN (
            SELECT id FROM chunks
            WHERE kind = 'analysis' AND source LIKE ?
          )
        SQL

        db.execute(
          "DELETE FROM chunks WHERE kind = 'analysis' AND source LIKE ?",
          [pattern]
        )
      end

      count
    end

    # Remove all best practice chunks matching a practice name (from both tables).
    # Best practice chunks have kind='best_practice' and source like "best-practices/name".
    # Returns the number of chunks deleted.
    def remove_best_practice_chunks(db, practice_name)
      pattern = "best-practices/#{practice_name}%"

      row = db.execute(
        "SELECT COUNT(*) AS cnt FROM chunks WHERE kind = 'best_practice' AND source LIKE ?",
        [pattern]
      ).first
      count = row["cnt"]

      return 0 if count == 0

      db.transaction do
        db.execute(<<~SQL, [pattern])
          DELETE FROM chunks_vec
          WHERE chunk_id IN (
            SELECT id FROM chunks
            WHERE kind = 'best_practice' AND source LIKE ?
          )
        SQL

        db.execute(
          "DELETE FROM chunks WHERE kind = 'best_practice' AND source LIKE ?",
          [pattern]
        )
      end

      count
    end

    # List best practices with chunk counts.
    # Returns array of hashes: [{"practice_name" => "...", "chunk_count" => N}, ...]
    def list_best_practices(db)
      db.execute(<<~SQL)
        SELECT
          REPLACE(source, 'best-practices/', '') AS practice_name,
          COUNT(*) AS chunk_count
        FROM chunks
        WHERE kind = 'best_practice'
        GROUP BY source
        ORDER BY source
      SQL
    end
  end
end
