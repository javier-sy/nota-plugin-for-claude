#!/usr/bin/env ruby
# frozen_string_literal: true

# Orchestrator: chunk + embed + store into sqlite-vec.
#
# CLI usage (public knowledge base build):
#   ruby mcp_server/indexer.rb --source-root ../.. --chunks-only
#   ruby mcp_server/indexer.rb --source-root ../.. --embed
#   ruby mcp_server/indexer.rb --status
#
# Private works management is handled via MCP tools (see server.rb).

require "json"
require "optparse"
require "fileutils"
require "pathname"

require_relative "chunker"

module MusaKnowledgeBase
  module Indexer
    module_function

    def write_chunks_jsonl(chunks, output_dir)
      FileUtils.mkdir_p(output_dir)

      by_kind = Hash.new { |h, k| h[k] = [] }
      chunks.each do |chunk|
        kind = chunk.metadata["kind"] || "unknown"
        by_kind[kind] << chunk
      end

      by_kind.each do |kind, kind_chunks|
        jsonl_path = File.join(output_dir, "#{kind}.jsonl")
        File.open(jsonl_path, "w:utf-8") do |f|
          kind_chunks.each { |chunk| f.puts(chunk.to_json) }
        end
      end

      manifest = {
        "total_chunks" => chunks.length,
        "by_kind"      => by_kind.sort.to_h.transform_values(&:length)
      }

      File.write(
        File.join(output_dir, "manifest.json"),
        JSON.pretty_generate(manifest)
      )

      manifest
    end

    def read_chunks_jsonl(chunks_dir)
      chunks = []
      Dir.glob(File.join(chunks_dir, "*.jsonl")).sort.each do |jsonl_file|
        File.foreach(jsonl_file, encoding: "utf-8") do |line|
          line = line.strip
          next if line.empty?

          data = JSON.parse(line)
          chunks << Chunker::Chunk.new(
            data["id"],
            data["content"],
            data["metadata"] || {}
          )
        end
      end
      chunks
    end

    def do_chunks_only(source_root, chunks_dir)
      lines = ["Chunking sources from: #{source_root}"]
      chunks = Chunker.chunk_all_sources(source_root)
      manifest = write_chunks_jsonl(chunks, chunks_dir)
      lines << "Generated #{manifest['total_chunks']} chunks:"
      manifest["by_kind"].each { |kind, count| lines << "  #{kind}: #{count}" }
      lines << "Written to: #{chunks_dir}"
      lines.join("\n")
    end

    def do_embed(source_root, chunks_dir, db_path)
      require_relative "db"

      lines = []

      # Step 1: Generate chunks if not already present
      manifest_path = File.join(chunks_dir, "manifest.json")
      unless File.exist?(manifest_path)
        lines << "No existing chunks found, generating..."
        lines << do_chunks_only(source_root, chunks_dir)
      end

      # Step 2: Read chunks
      lines << "Reading chunks..."
      chunks = read_chunks_jsonl(chunks_dir)
      lines << "Read #{chunks.length} chunks"

      # Step 3: Embed and store
      lines << "Embedding and storing in knowledge base at: #{db_path}"
      db = DB.open(db_path)
      begin
        DB.create_schema(db)
        DB.upsert_chunks(db, chunks)

        # Step 4: Store repo version metadata for GitHub URL generation
        lines << "Storing source metadata..."
        store_source_metadata(db, source_root)
      ensure
        db.close
      end
      lines << "Done!"

      # Write version marker
      require "time"
      File.write("#{db_path}.version", Time.now.utc.iso8601)

      lines.join("\n")
    end

    # Extract VERSION constants from source repos and store as metadata.
    # These are used to construct versioned GitHub URLs in search results.
    def store_source_metadata(db, source_root)
      DB.set_metadata(db, "github_owner", "javier-sy")

      version_files = {
        "musa-dsl"                  => "lib/musa-dsl/version.rb",
        "midi-events"               => "lib/midi-events/version.rb",
        "midi-parser"               => "lib/midi-parser/version.rb",
        "midi-communications"       => "lib/midi-communications/version.rb",
        "midi-communications-macos" => "lib/midi-communications-macos/version.rb",
        "musalce-server"            => "lib/version.rb",
      }

      Dir.children(source_root).sort.each do |repo|
        repo_dir = File.join(source_root, repo)
        next unless File.directory?(repo_dir)

        version_rel = version_files[repo]
        if version_rel
          version_file = File.join(repo_dir, version_rel)
          if File.exist?(version_file)
            content = File.read(version_file)
            if content =~ /VERSION\s*=\s*['"]([^'"]+)['"]/
              DB.set_metadata(db, "repo:#{repo}", "v#{$1}")
              next
            end
          end
        end

        # Fallback for repos without VERSION (e.g., musadsl-demo)
        DB.set_metadata(db, "repo:#{repo}", "main")
      end
    end

    # Escape glob-special characters ([] {} ? *) so Dir.glob treats them literally.
    # Needed because work paths often contain brackets, e.g. "2023-02-12 [musa bw]".
    def escape_glob(path)
      path.gsub(/[\[\]{}?*]/) { |c| "\\#{c}" }
    end

    def do_add_work(work_path, db_path)
      require_relative "db"

      escaped = escape_glob(work_path)
      chunks = []

      # Index all Ruby files recursively
      Dir.glob(File.join(escaped, "**/*.rb"))
         .reject { |f| f.include?("/vendor/") || f.include?("/.bundle/") }
         .sort.each do |rb_file|
        rel = Pathname.new(rb_file).relative_path_from(Pathname.new(work_path)).to_s
        chunks.concat(
          Chunker.chunk_demo_code(
            rb_file,
            kind: "private_works",
            source_label: "#{File.basename(work_path)}/#{rel}"
          )
        )
      end

      # Index all Markdown files recursively
      Dir.glob(File.join(escaped, "**/*.md"))
         .reject { |f| f.include?("/vendor/") || f.include?("/.bundle/") }
         .sort.each do |md_file|
        rel = Pathname.new(md_file).relative_path_from(Pathname.new(work_path)).to_s
        chunks.concat(
          Chunker.chunk_markdown(
            md_file,
            kind: "private_works",
            source_label: "#{File.basename(work_path)}/#{rel}"
          )
        )
      end

      if chunks.empty?
        return "No content found in: #{work_path}"
      end

      lines = ["Indexing #{chunks.length} chunks from: #{File.basename(work_path)}"]
      FileUtils.mkdir_p(File.dirname(db_path))
      db = DB.open(db_path)
      begin
        DB.create_schema(db)
        DB.upsert_chunks(db, chunks, collection_override: "private_works")
      ensure
        db.close
      end
      lines << "Done!"
      lines.join("\n")
    end

    def do_list_works(private_db_path)
      require_relative "db"

      unless File.exist?(private_db_path)
        return "No private works indexed yet."
      end

      db = DB.open(private_db_path)
      begin
        works = DB.list_works(db)
      ensure
        db.close
      end

      if works.empty?
        return "No private works indexed yet."
      end

      lines = ["Indexed private works:", ""]
      lines << format("  %-40s %s", "Work", "Chunks")
      lines << "  #{'-' * 40} #{'-' * 6}"
      works.each do |row|
        lines << format("  %-40s %d", row["work_name"], row["chunk_count"])
      end
      lines << ""
      lines << "Total: #{works.length} works, #{works.sum { |r| r['chunk_count'] }} chunks"
      lines.join("\n")
    end

    def do_remove_work(work_name, private_db_path)
      require_relative "db"

      unless File.exist?(private_db_path)
        return "No private works indexed yet."
      end

      db = DB.open(private_db_path)
      begin
        count = DB.remove_work_chunks(db, work_name)
      ensure
        db.close
      end

      if count == 0
        "Work '#{work_name}' not found in index."
      else
        "Removed #{count} chunks for '#{work_name}'."
      end
    end

    def do_status(chunks_dir, db_path, private_db_path)
      lines = []

      # Check chunks
      manifest_path = File.join(chunks_dir, "manifest.json")
      if File.exist?(manifest_path)
        manifest = JSON.parse(File.read(manifest_path))
        lines << "Chunks: #{manifest['total_chunks']} total"
        manifest["by_kind"].each { |kind, count| lines << "  #{kind}: #{count}" }
      else
        lines << "Chunks: not generated (run --chunks-only)"
      end

      # Check knowledge DB
      version_file = "#{db_path}.version"
      if File.exist?(version_file)
        version = File.read(version_file).strip
        lines << "\nKnowledge DB: present (built #{version})"

        begin
          require_relative "db"
          db = DB.open(db_path)
          stats = DB.collection_stats(db)
          db.close
          stats.each { |name, count| lines << "  #{name}: #{count} documents" }
        rescue => e
          lines << "  (could not read stats: #{e})"
        end
      else
        lines << "\nKnowledge DB: not built (run --embed)"
      end

      # Check private DB
      if File.exist?(private_db_path)
        lines << "\nPrivate DB: present"
        begin
          require_relative "db"
          db = DB.open(private_db_path)
          stats = DB.collection_stats(db)
          db.close
          stats.each { |name, count| lines << "  #{name}: #{count} documents" }
        rescue => e
          lines << "  (could not read stats: #{e})"
        end
      else
        lines << "\nPrivate DB: not present (use /index to manage private works)"
      end

      lines.join("\n")
    end

    # Public API for MCP tools (resolve paths automatically)

    def list_works
      require_relative "db"
      do_list_works(DB.default_private_db_path)
    end

    def add_work(work_path)
      require_relative "db"
      do_add_work(work_path, DB.default_private_db_path)
    end

    def remove_work(work_name)
      require_relative "db"
      do_remove_work(work_name, DB.default_private_db_path)
    end

    def index_status
      require_relative "db"
      script_dir = __dir__
      plugin_root = File.dirname(script_dir)
      chunks_dir = File.join(plugin_root, "data", "chunks")
      db_path = File.join(script_dir, "knowledge.db")
      do_status(chunks_dir, db_path, DB.default_private_db_path)
    end

    def main
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby mcp_server/indexer.rb [options]"
        opts.separator ""
        opts.separator "MusaDSL knowledge base indexer"

        opts.on("--source-root PATH", "Path to MusaDSL/ root directory") do |v|
          options[:source_root] = v
        end
        opts.on("--chunks-dir PATH", "Directory for JSONL chunk output") do |v|
          options[:chunks_dir] = v
        end
        opts.on("--db-path PATH", "Path for knowledge.db storage") do |v|
          options[:db_path] = v
        end

        opts.on("--chunks-only", "Generate JSONL chunks only (no API key needed)") do
          options[:command] = :chunks_only
        end
        opts.on("--embed", "Generate chunks + embeddings + DB (requires VOYAGE_API_KEY)") do
          options[:command] = :embed
        end
        opts.on("--status", "Show index status") do
          options[:command] = :status
        end
      end

      parser.parse!

      require_relative "db"

      script_dir = __dir__
      plugin_root = File.dirname(script_dir)
      chunks_dir = options[:chunks_dir] || File.join(plugin_root, "data", "chunks")
      db_path = options[:db_path] || File.join(script_dir, "knowledge.db")
      private_db_path = options[:db_path] || DB.default_private_db_path

      case options[:command]
      when :chunks_only
        abort "Error: --source-root is required for --chunks-only" unless options[:source_root]
        puts do_chunks_only(options[:source_root], chunks_dir)
      when :embed
        abort "Error: --source-root is required for --embed" unless options[:source_root]
        puts do_embed(options[:source_root], chunks_dir, db_path)
      when :status
        puts do_status(chunks_dir, db_path, private_db_path)
      else
        puts parser
        exit 1
      end
    end
  end
end

MusaKnowledgeBase::Indexer.main if __FILE__ == $PROGRAM_NAME
