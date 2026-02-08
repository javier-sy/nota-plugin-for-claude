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

require_relative "embeddings"

module MusaKnowledgeBase
  module DB
    COLLECTION_NAMES = %w[docs api demo_readme demo_code gem_readme].freeze
    PRIVATE_COLLECTION = "private_works"

    module_function

    def default_db_path
      env_path = ENV["KNOWLEDGE_DB_PATH"]
      return env_path if env_path

      File.join(__dir__, "knowledge.db")
    end

    def default_private_db_path
      env_path = ENV["PRIVATE_DB_PATH"]
      return env_path if env_path

      File.join(__dir__, "private.db")
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

    # Low-level KNN search: takes a pre-computed embedding, returns raw result hashes.
    # Does NOT call Voyage — caller is responsible for embedding the query.
    def knn_search(db, query_embedding, kind: "all", n_results: 5)
      vec_blob = query_embedding.pack("f*")

      # Over-fetch to allow filtering, then trim to n_results
      fetch_limit = kind == "all" ? n_results * 3 : n_results * 2

      # KNN search via sqlite-vec
      knn_rows = db.execute(
        "SELECT chunk_id, distance FROM chunks_vec WHERE embedding MATCH ? AND k = ? ORDER BY distance",
        [vec_blob, fetch_limit]
      )

      # Join with chunks table for metadata and filter by kind
      all_results = []
      kinds_to_search = if kind == "all"
                          COLLECTION_NAMES + [PRIVATE_COLLECTION]
                        else
                          [kind]
                        end

      knn_rows.each do |row|
        chunk = db.execute("SELECT * FROM chunks WHERE id = ?", [row["chunk_id"]]).first
        next unless chunk
        next unless kinds_to_search.include?(chunk["kind"])

        source = chunk["source"] || "unknown"
        source = source_to_github_url(db, source)

        all_results << {
          "content"  => chunk["content"],
          "source"   => source,
          "kind"     => chunk["kind"],
          "section"  => chunk["section"] || "",
          "module"   => chunk["module"] || "",
          "distance" => row["distance"]
        }

        break if all_results.length >= n_results
      end

      all_results
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

        content = result["content"]
        content = content[0, 2000] + "\n... (truncated)" if content.length > 2000

        "#{header}\n#{source_info}\n\n#{content}"
      end

      parts.join("\n\n---\n\n")
    end

    def collection_stats(db)
      stats = {}
      (COLLECTION_NAMES + [PRIVATE_COLLECTION]).each do |kind|
        row = db.execute("SELECT COUNT(*) AS cnt FROM chunks WHERE kind = ?", [kind]).first
        count = row["cnt"]
        stats[kind] = count if count > 0
      end
      stats
    end
  end
end
