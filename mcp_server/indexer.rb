#!/usr/bin/env ruby
# frozen_string_literal: true

# Orchestrator: chunk + embed + store into sqlite-vec.
#
# Usage:
#   ruby mcp_server/indexer.rb --source-root ../.. --chunks-only
#   ruby mcp_server/indexer.rb --source-root ../.. --embed
#   ruby mcp_server/indexer.rb --add-work /path/to/work
#   ruby mcp_server/indexer.rb --scan /path/to/works
#   ruby mcp_server/indexer.rb --list-works
#   ruby mcp_server/indexer.rb --remove-work NAME
#   ruby mcp_server/indexer.rb --status

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
      puts "Chunking sources from: #{source_root}"
      chunks = Chunker.chunk_all_sources(source_root)
      manifest = write_chunks_jsonl(chunks, chunks_dir)
      puts "Generated #{manifest['total_chunks']} chunks:"
      manifest["by_kind"].each { |kind, count| puts "  #{kind}: #{count}" }
      puts "Written to: #{chunks_dir}"
    end

    def do_embed(source_root, chunks_dir, db_path)
      require_relative "db"

      # Step 1: Generate chunks if not already present
      manifest_path = File.join(chunks_dir, "manifest.json")
      unless File.exist?(manifest_path)
        puts "No existing chunks found, generating..."
        do_chunks_only(source_root, chunks_dir)
      end

      # Step 2: Read chunks
      puts "Reading chunks..."
      chunks = read_chunks_jsonl(chunks_dir)
      puts "Read #{chunks.length} chunks"

      # Step 3: Embed and store
      puts "Embedding and storing in knowledge base at: #{db_path}"
      db = DB.open(db_path)
      begin
        DB.create_schema(db)
        DB.upsert_chunks(db, chunks)

        # Step 4: Store repo version metadata for GitHub URL generation
        puts "Storing source metadata..."
        store_source_metadata(db, source_root)
      ensure
        db.close
      end
      puts "Done!"

      # Write version marker
      require "time"
      File.write("#{db_path}.version", Time.now.utc.iso8601)
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

    def do_add_work(work_path, db_path)
      require_relative "db"

      chunks = []

      # Parse Ruby files in musa/ subdirectory
      musa_dir = File.join(work_path, "musa")
      if File.directory?(musa_dir)
        Dir.glob(File.join(musa_dir, "*.rb")).sort.each do |rb_file|
          rel = Pathname.new(rb_file).relative_path_from(Pathname.new(work_path)).to_s
          chunks.concat(
            Chunker.chunk_demo_code(
              rb_file,
              kind: "private_works",
              source_label: "#{File.basename(work_path)}/#{rel}"
            )
          )
        end
      end

      # Parse README if present
      readme = File.join(work_path, "README.md")
      if File.exist?(readme)
        chunks.concat(
          Chunker.chunk_markdown(
            readme,
            kind: "private_works",
            source_label: "#{File.basename(work_path)}/README.md"
          )
        )
      end

      if chunks.empty?
        puts "No content found in: #{work_path}"
        return
      end

      puts "Indexing #{chunks.length} chunks from: #{File.basename(work_path)}"
      FileUtils.mkdir_p(File.dirname(db_path))
      db = DB.open(db_path)
      begin
        DB.create_schema(db)
        DB.upsert_chunks(db, chunks, collection_override: "private_works")
      ensure
        db.close
      end
      puts "Done!"
    end

    def do_scan(scan_dir, db_path)
      works_found = 0
      Dir.children(scan_dir).sort.each do |entry|
        full_path = File.join(scan_dir, entry)
        next unless File.directory?(full_path)

        musa_dir = File.join(full_path, "musa")
        readme = File.join(full_path, "README.md")
        if File.directory?(musa_dir) || File.exist?(readme)
          do_add_work(full_path, db_path)
          works_found += 1
        end
      end

      if works_found == 0
        puts "No composition works found in: #{scan_dir}"
      else
        puts "\nIndexed #{works_found} works from: #{scan_dir}"
      end
    end

    def do_list_works(private_db_path)
      require_relative "db"

      unless File.exist?(private_db_path)
        puts "No private works indexed yet."
        return
      end

      db = DB.open(private_db_path)
      begin
        works = DB.list_works(db)
      ensure
        db.close
      end

      if works.empty?
        puts "No private works indexed yet."
        return
      end

      puts "Indexed private works:"
      puts ""
      puts format("  %-40s %s", "Work", "Chunks")
      puts "  #{'-' * 40} #{'-' * 6}"
      works.each do |row|
        puts format("  %-40s %d", row["work_name"], row["chunk_count"])
      end
      puts ""
      puts "Total: #{works.length} works, #{works.sum { |r| r['chunk_count'] }} chunks"
    end

    def do_remove_work(work_name, private_db_path)
      require_relative "db"

      unless File.exist?(private_db_path)
        puts "No private works indexed yet."
        return
      end

      db = DB.open(private_db_path)
      begin
        count = DB.remove_work_chunks(db, work_name)
      ensure
        db.close
      end

      if count == 0
        puts "Work '#{work_name}' not found in index."
      else
        puts "Removed #{count} chunks for '#{work_name}'."
      end
    end

    def do_status(chunks_dir, db_path, private_db_path)
      # Check chunks
      manifest_path = File.join(chunks_dir, "manifest.json")
      if File.exist?(manifest_path)
        manifest = JSON.parse(File.read(manifest_path))
        puts "Chunks: #{manifest['total_chunks']} total"
        manifest["by_kind"].each { |kind, count| puts "  #{kind}: #{count}" }
      else
        puts "Chunks: not generated (run --chunks-only)"
      end

      # Check knowledge DB
      version_file = "#{db_path}.version"
      if File.exist?(version_file)
        version = File.read(version_file).strip
        puts "\nKnowledge DB: present (built #{version})"

        begin
          require_relative "db"
          db = DB.open(db_path)
          stats = DB.collection_stats(db)
          db.close
          stats.each { |name, count| puts "  #{name}: #{count} documents" }
        rescue => e
          puts "  (could not read stats: #{e})"
        end
      else
        puts "\nKnowledge DB: not built (run --embed)"
      end

      # Check private DB
      if File.exist?(private_db_path)
        puts "\nPrivate DB: present"
        begin
          require_relative "db"
          db = DB.open(private_db_path)
          stats = DB.collection_stats(db)
          db.close
          stats.each { |name, count| puts "  #{name}: #{count} documents" }
        rescue => e
          puts "  (could not read stats: #{e})"
        end
      else
        puts "\nPrivate DB: not present (use --add-work, --scan, or /index to index private works)"
      end
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
        opts.on("--add-work PATH", "Index a private composition work") do |v|
          options[:command] = :add_work
          options[:work_path] = v
        end
        opts.on("--scan DIR", "Scan directory for composition works and index all") do |v|
          options[:command] = :scan
          options[:scan_dir] = v
        end
        opts.on("--list-works", "List all indexed private works") do
          options[:command] = :list_works
        end
        opts.on("--remove-work NAME", "Remove a private work from the index") do |v|
          options[:command] = :remove_work
          options[:work_name] = v
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
        do_chunks_only(options[:source_root], chunks_dir)
      when :embed
        abort "Error: --source-root is required for --embed" unless options[:source_root]
        do_embed(options[:source_root], chunks_dir, db_path)
      when :add_work
        do_add_work(options[:work_path], private_db_path)
      when :scan
        do_scan(options[:scan_dir], private_db_path)
      when :list_works
        do_list_works(private_db_path)
      when :remove_work
        do_remove_work(options[:work_name], private_db_path)
      when :status
        do_status(chunks_dir, db_path, private_db_path)
      else
        puts parser
        exit 1
      end
    end
  end
end

MusaKnowledgeBase::Indexer.main if __FILE__ == $PROGRAM_NAME
