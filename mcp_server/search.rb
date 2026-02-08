# frozen_string_literal: true

# Search functions backed by sqlite-vec.
#
# Searches both knowledge.db (public, downloadable) and private.db (local user works).
# Falls back gracefully when either database is not available.

require_relative "db"

module MusaKnowledgeBase
  module Search
    SETUP_HINT =
      "The plugin is not fully configured. " \
      "Please run /setup to complete the initial setup."

    VOYAGE_ERROR_HINT =
      "The Voyage AI API key is not working (it may be expired, revoked, or mistyped). " \
      "Please run /setup to diagnose the issue."

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

    def semantic_search(query, kind = "all")
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, private_db|
        embedding = Voyage.query_embedder.embed([query]).first

        results = DB.knn_search(knowledge_db, embedding, kind: kind, n_results: 5)

        if private_db && %w[all private_works].include?(kind)
          private_results = DB.knn_search(private_db, embedding, kind: "private_works", n_results: 5)
          results = (results + private_results).sort_by { |r| r["distance"] }.first(5)
        end

        DB.format_results(results, query)
      end
    end

    def api_lookup(module_name, method = "")
      error = check_preconditions
      return error if error

      query = "#{module_name} #{method}".strip
      with_dbs do |knowledge_db, _private_db|
        embedding = Voyage.query_embedder.embed([query]).first
        results = DB.knn_search(knowledge_db, embedding, kind: "api", n_results: 5)
        DB.format_results(results, query)
      end
    end

    def similar_works(description)
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, private_db|
        embedding = Voyage.query_embedder.embed([description]).first

        results_readme = DB.knn_search(knowledge_db, embedding, kind: "demo_readme", n_results: 3)
        results_code = DB.knn_search(knowledge_db, embedding, kind: "demo_code", n_results: 3)

        if private_db
          private_results = DB.knn_search(private_db, embedding, kind: "private_works", n_results: 3)
          results_readme = (results_readme + private_results).sort_by { |r| r["distance"] }.first(3)
        end

        formatted_readme = DB.format_results(results_readme, description)
        formatted_code = DB.format_results(results_code, description)
        "## Demo Descriptions\n#{formatted_readme}\n\n## Demo Code\n#{formatted_code}"
      end
    end

    def dependency_chain(concept)
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, _private_db|
        embedding = Voyage.query_embedder.embed(["setup requirements for #{concept}"]).first
        docs = DB.knn_search(knowledge_db, embedding, kind: "docs", n_results: 3)
        formatted_docs = DB.format_results(docs, concept)

        code_embedding = Voyage.query_embedder.embed(["require include #{concept}"]).first
        code = DB.knn_search(knowledge_db, code_embedding, kind: "demo_code", n_results: 2)
        formatted_code = DB.format_results(code, concept)

        "## Documentation\n#{formatted_docs}\n\n## Code Examples\n#{formatted_code}"
      end
    end

    def code_pattern(technique)
      error = check_preconditions
      return error if error

      with_dbs do |knowledge_db, _private_db|
        embedding = Voyage.query_embedder.embed([technique]).first
        code = DB.knn_search(knowledge_db, embedding, kind: "demo_code", n_results: 3)
        docs = DB.knn_search(knowledge_db, embedding, kind: "docs", n_results: 2)
        formatted_code = DB.format_results(code, technique)
        formatted_docs = DB.format_results(docs, technique)
        "## Code Examples\n#{formatted_code}\n\n## Related Documentation\n#{formatted_docs}"
      end
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
