# frozen_string_literal: true

# Source material chunking for MusaDSL knowledge base.
#
# Produces JSONL chunks from markdown docs, Ruby source code, and demo files.
# Each chunk has a stable ID, content, and metadata for indexing.

require "digest/sha2"
require "json"
require "ripper"

module NotaKnowledgeBase
  module Chunker
    Chunk = Struct.new(:id, :content, :metadata) do
      def to_h
        { "id" => id, "content" => content, "metadata" => metadata }
      end

      def to_json
        JSON.generate(to_h)
      end
    end

    # Every kind a full build produces. Asserted non-empty at the end of
    # chunk_all_sources -- see the note there.
    EXPECTED_KINDS = %w[api docs demo_code demo_readme gem_readme best_practice].freeze

    module_function

    def stable_id(kind, source_path, index)
      path_hash = Digest::SHA256.hexdigest(source_path)[0, 12]
      "#{kind}/#{path_hash}/#{'%04d' % index}"
    end

    def content_hash(text)
      Digest::SHA256.hexdigest(text)[0, 16]
    end

    # -------------------------------------------------------------------
    # Markdown chunking (docs, READMEs)
    # -------------------------------------------------------------------

    def chunk_markdown(filepath, kind:, source_label: nil)
      text = File.read(filepath, encoding: "utf-8")
      source = source_label || filepath.to_s
      sections = split_by_headings(text)
      chunks = []

      sections.each_with_index do |(heading, body), i|
        content = body.strip
        next if content.empty? && (heading.nil? || heading.empty?)

        content = "## #{heading}\n\n#{content}" if heading && !heading.empty?

        chunks << Chunk.new(
          stable_id(kind, source, i),
          content,
          {
            "source"       => source,
            "kind"         => kind,
            "section"      => (heading && !heading.empty?) ? heading : "(intro)",
            "content_hash" => content_hash(content)
          }
        )
      end

      chunks
    end

    # Chunk an in-memory markdown text (not a file) into sections by ## headings.
    # Used for analysis text that is generated programmatically.
    def chunk_markdown_text(text, kind:, source_label:)
      sections = split_by_headings(text)
      chunks = []

      sections.each_with_index do |(heading, body), i|
        content = body.strip
        next if content.empty? && (heading.nil? || heading.empty?)

        content = "## #{heading}\n\n#{content}" if heading && !heading.empty?

        chunks << Chunk.new(
          stable_id(kind, source_label, i),
          content,
          {
            "source"       => source_label,
            "kind"         => kind,
            "section"      => (heading && !heading.empty?) ? heading : "(intro)",
            "content_hash" => content_hash(content)
          }
        )
      end

      chunks
    end

    def split_by_headings(text)
      pattern = /^## (.+)$/
      sections = []
      last_pos = 0
      last_heading = ""

      text.scan(pattern) do
        match = Regexp.last_match
        body = text[last_pos...match.begin(0)]
        if last_pos == 0 && !body.strip.empty?
          sections << ["", body]
        elsif last_pos > 0
          sections << [last_heading, body]
        end
        last_heading = match[1].strip
        last_pos = match.end(0)
      end

      if last_pos > 0
        sections << [last_heading, text[last_pos..]]
      elsif sections.empty? && !text.strip.empty?
        sections << ["", text]
      end

      sections
    end

    # -------------------------------------------------------------------
    # Ruby source chunking via Ripper
    # -------------------------------------------------------------------

    def chunk_ruby_source(filepath, kind: "api", source_label: nil)
      source_text = File.read(filepath, encoding: "utf-8")
      source = source_label || filepath.to_s

      sexp = Ripper.sexp(source_text)
      unless sexp
        return chunk_ruby_fallback(filepath, kind, source)
      end

      lines = source_text.lines
      definitions = extract_definitions(sexp)

      private_from = private_regions(lines)

      chunks = []
      definitions.each_with_index do |defn, chunk_index|
        # Extract preceding comments
        comments = extract_preceding_comments(lines, defn[:start_line])

        next if internal?(defn, comments, private_from)

        # Extract the definition text
        end_line = [defn[:end_line], lines.length].min
        node_text = lines[(defn[:start_line] - 1)...end_line].join

        content_parts = []
        content_parts << comments unless comments.empty?
        content_parts << teaching_text(defn, node_text, comments)
        content = content_parts.join("\n")

        next if content.strip.length < 30

        chunks << Chunk.new(
          stable_id(kind, source, chunk_index),
          content,
          {
            "source"       => source,
            "kind"         => kind,
            "module"       => defn[:module_path],
            "name"         => defn[:name],
            "node_type"    => defn[:type],
            "content_hash" => content_hash(content)
          }
        )
      end

      # If no definitions found, fall back to file-level chunk
      if chunks.empty? && !source_text.strip.empty?
        truncated = source_text[0, 4000]
        chunks << Chunk.new(
          stable_id(kind, source, 0),
          truncated,
          {
            "source"       => source,
            "kind"         => kind,
            "module"       => "",
            "name"         => File.basename(filepath, ".rb"),
            "node_type"    => "file",
            "content_hash" => content_hash(truncated)
          }
        )
      end

      chunks
    end

    # Which definitions are implementation rather than API.
    #
    # WHY. A chunk is retrieved by how its text reads, so a `_next_value` body
    # sitting in the index answers questions about HOW something is built when
    # what was asked is HOW TO USE it. Three ways a definition says it is
    # internal, and all three are honoured:
    #
    #   * a leading underscore, which is this codebase's convention;
    #   * living below a bare `private` in its class or module;
    #   * `@api private` in its own documentation.
    #
    # An `@example` overrides all three. Somebody who writes one is teaching --
    # `Datasets::Helper#velocity_of` is private and its example is the only place
    # that says a velocity of 0 is `mp` -- and every one of them is executed and
    # checked by musa-dsl's own doctest, so they are the most reliable text in
    # the corpus. What is being excluded is implementation, not documentation.
    def internal?(defn, comments, private_from)
      return false if comments.include?("@example")

      return true if defn[:name].to_s.start_with?("_")
      return true if comments.include?("@api private")

      boundary = private_from[defn[:module_path]]
      !boundary.nil? && defn[:type] == "method" && defn[:start_line] > boundary
    end

    # The line at which each module or class turns private, if it does.
    #
    # Approximate on purpose: a bare `private` on its own line, attributed to the
    # innermost enclosing definition by indentation. `private def foo` and
    # `private :foo` are not detected, and the underscore convention covers most
    # of what they would.
    def private_regions(lines)
      regions = {}
      path = []

      lines.each_with_index do |line, index|
        case line
        when /^(\s*)(?:module|class)\s+([A-Z][\w:]*)/
          indent = Regexp.last_match(1).length
          path.pop while path.any? && path.last.first >= indent
          path << [indent, Regexp.last_match(2)]
        when /^(\s*)end\b/
          indent = Regexp.last_match(1).length
          path.pop while path.any? && path.last.first >= indent
        when /^\s*private\s*$/
          regions[path.map(&:last).join("::")] ||= index + 1
        end
      end

      regions
    end

    # What of a definition is worth indexing.
    #
    # A documented method's teaching content is its documentation -- the
    # `@example` is the contract -- and its body is implementation that dilutes
    # the embedding: a fifty-line `#next_value` buries the three lines that say
    # what it is for. So a documented definition contributes its signature and
    # leaves the body out; an undocumented one contributes its body, because that
    # is the only thing it has to say.
    def teaching_text(defn, node_text, comments)
      return node_text if comments.strip.empty? || defn[:type] != "method"

      node_text.lines.first.to_s.rstrip
    end

    # Walk Ripper sexp to extract module/class/def definitions with line ranges.
    def extract_definitions(sexp, module_path: [])
      definitions = []
      return definitions unless sexp.is_a?(Array)

      case sexp[0]
      when :module
        name = extract_const_name(sexp[1])
        current_path = module_path + [name]
        start_line = find_start_line(sexp)
        end_line = find_end_line(sexp)
        definitions << {
          type: "module", name: name,
          module_path: current_path.join("::"),
          start_line: start_line, end_line: end_line
        }
        # Recurse into body
        body = sexp[2]
        if body
          definitions.concat(extract_definitions(body, module_path: current_path))
        end

      when :class
        name = extract_const_name(sexp[1])
        current_path = module_path + [name]
        start_line = find_start_line(sexp)
        end_line = find_end_line(sexp)
        definitions << {
          type: "class", name: name,
          module_path: current_path.join("::"),
          start_line: start_line, end_line: end_line
        }
        # Recurse into body
        body = sexp[3] || sexp[2]
        if body
          definitions.concat(extract_definitions(body, module_path: current_path))
        end

      when :def
        name = sexp[1][1] if sexp[1].is_a?(Array) && sexp[1][0] == :@ident
        name ||= sexp[1].to_s
        start_line = find_start_line(sexp)
        end_line = find_end_line(sexp)
        definitions << {
          type: "method", name: name,
          module_path: module_path.join("::"),
          start_line: start_line, end_line: end_line
        }

      when :defs
        # singleton method: def self.foo
        name_node = sexp[3]
        name = if name_node.is_a?(Array) && name_node[0] == :@ident
                 name_node[1]
               else
                 name_node.to_s
               end
        start_line = find_start_line(sexp)
        end_line = find_end_line(sexp)
        definitions << {
          type: "singleton_method", name: name,
          module_path: module_path.join("::"),
          start_line: start_line, end_line: end_line
        }

      else
        # Recurse into child arrays
        sexp.each do |child|
          if child.is_a?(Array)
            definitions.concat(extract_definitions(child, module_path: module_path))
          end
        end
      end

      definitions
    end

    def extract_const_name(node)
      return "" unless node.is_a?(Array)

      case node[0]
      when :const_ref
        extract_const_name(node[1])
      when :const_path_ref
        left = extract_const_name(node[1])
        right = extract_const_name(node[2])
        "#{left}::#{right}"
      when :@const
        node[1]
      when :top_const_ref
        extract_const_name(node[1])
      else
        ""
      end
    end

    def find_start_line(sexp)
      return sexp[2][0] if sexp.is_a?(Array) && sexp[0].is_a?(Symbol) &&
                           sexp[0].to_s.start_with?("@") && sexp[2].is_a?(Array)

      sexp.each do |child|
        next unless child.is_a?(Array)

        if child[0].is_a?(Symbol) && child[0].to_s.start_with?("@") && child[2].is_a?(Array)
          return child[2][0]
        end

        line = find_start_line(child)
        return line if line
      end if sexp.is_a?(Array)

      nil
    end

    def find_end_line(sexp)
      max_line = nil

      if sexp.is_a?(Array)
        if sexp[0].is_a?(Symbol) && sexp[0].to_s.start_with?("@") && sexp[2].is_a?(Array)
          return sexp[2][0]
        end

        sexp.each do |child|
          next unless child.is_a?(Array)

          line = find_end_line(child)
          max_line = line if line && (max_line.nil? || line > max_line)
        end
      end

      max_line
    end

    def extract_preceding_comments(lines, start_line)
      return "" unless start_line && start_line > 1

      comments = []
      i = start_line - 2  # 0-indexed, line before definition
      while i >= 0
        line = lines[i]
        stripped = line.strip
        if stripped.start_with?("#")
          comments.unshift(line.chomp)
          i -= 1
        else
          break
        end
      end

      comments.join("\n")
    end

    def chunk_ruby_fallback(filepath, kind, source)
      text = File.read(filepath, encoding: "utf-8")
      chunks = []
      current_block = []
      chunk_index = 0

      text.each_line do |line|
        current_block << line

        if line.strip.empty? && current_block.length > 10
          content = current_block.join.strip
          unless content.empty?
            truncated = content[0, 4000]
            chunks << Chunk.new(
              stable_id(kind, source, chunk_index),
              truncated,
              {
                "source"       => source,
                "kind"         => kind,
                "module"       => "",
                "name"         => File.basename(filepath, ".rb"),
                "node_type"    => "block",
                "content_hash" => content_hash(truncated)
              }
            )
            chunk_index += 1
            current_block = []
          end
        end
      end

      # Final block
      content = current_block.join.strip
      unless content.empty?
        truncated = content[0, 4000]
        chunks << Chunk.new(
          stable_id(kind, source, chunk_index),
          truncated,
          {
            "source"       => source,
            "kind"         => kind,
            "module"       => "",
            "name"         => File.basename(filepath, ".rb"),
            "node_type"    => "block",
            "content_hash" => content_hash(truncated)
          }
        )
      end

      chunks
    end

    # -------------------------------------------------------------------
    # Demo code chunking
    # -------------------------------------------------------------------

    def chunk_demo_code(filepath, kind: "demo_code", source_label: nil)
      text = File.read(filepath, encoding: "utf-8")
      source = source_label || filepath.to_s
      sections = split_code_by_comments(text)
      chunks = []

      sections.each_with_index do |section, i|
        content = section.strip
        next if content.length < 20

        truncated = content[0, 4000]
        chunks << Chunk.new(
          stable_id(kind, source, i),
          truncated,
          {
            "source"       => source,
            "kind"         => kind,
            "section"      => extract_first_comment(section),
            "content_hash" => content_hash(truncated)
          }
        )
      end

      chunks
    end

    def split_code_by_comments(text)
      raw_sections = text.split(/\n\n+/)
      merged = []
      current = []

      raw_sections.each do |section|
        current << section
        joined = current.join("\n\n")
        if joined.length > 200 || section.strip.start_with?("end")
          merged << joined
          current = []
        end
      end

      if current.any?
        if merged.any?
          merged[-1] = merged[-1] + "\n\n" + current.join("\n\n")
        else
          merged << current.join("\n\n")
        end
      end

      merged
    end

    def extract_first_comment(text)
      text.each_line do |line|
        stripped = line.strip
        if stripped.start_with?("#") && !stripped.start_with?("#!")
          return stripped.sub(/^#\s*/, "").strip[0, 80]
        end
      end
      "(code)"
    end

    # -------------------------------------------------------------------
    # Public API: chunk all sources
    # -------------------------------------------------------------------

    def chunk_all_sources(source_root)
      source_root = File.expand_path(source_root)
      all_chunks = []

      # 1. musa-dsl docs (subsystems + getting-started)
      docs_dir = File.join(source_root, "musa-dsl", "docs")
      if File.directory?(docs_dir)
        Dir.glob(File.join(docs_dir, "**", "*.md")).sort.each do |md_file|
          rel = relative_path(md_file, source_root)
          all_chunks.concat(chunk_markdown(md_file, kind: "docs", source_label: rel))
        end
      end

      # 2. musa-dsl Ruby source (API extraction)
      lib_dir = File.join(source_root, "musa-dsl", "lib", "musa-dsl")
      if File.directory?(lib_dir)
        Dir.glob(File.join(lib_dir, "**", "*.rb")).sort.each do |rb_file|
          rel = relative_path(rb_file, source_root)
          all_chunks.concat(chunk_ruby_source(rb_file, kind: "api", source_label: rel))
        end
      end

      # 3. musadsl-demo READMEs
      demo_dir = File.join(source_root, "musadsl-demo")
      if File.directory?(demo_dir)
        Dir.glob(File.join(demo_dir, "demo-*", "README.md")).sort.each do |readme|
          rel = relative_path(readme, source_root)
          all_chunks.concat(chunk_markdown(readme, kind: "demo_readme", source_label: rel))
        end
      end

      # 4. musadsl-demo Ruby code
      if File.directory?(demo_dir)
        Dir.glob(File.join(demo_dir, "demo-*", "musa", "*.rb")).sort.each do |rb_file|
          rel = relative_path(rb_file, source_root)
          all_chunks.concat(chunk_demo_code(rb_file, kind: "demo_code", source_label: rel))
        end
      end

      # 5. Other gem READMEs and docs/
      %w[
        midi-events
        midi-parser
        midi-communications
        midi-communications-macos
        musalce-server
      ].each do |gem_name|
        readme = File.join(source_root, gem_name, "README.md")
        if File.exist?(readme)
          all_chunks.concat(
            chunk_markdown(readme, kind: "gem_readme", source_label: "#{gem_name}/README.md")
          )
        end

        gem_docs_dir = File.join(source_root, gem_name, "docs")
        next unless File.directory?(gem_docs_dir)

        Dir.glob(File.join(gem_docs_dir, "**", "*.md")).sort.each do |md_file|
          rel = relative_path(md_file, source_root)
          all_chunks.concat(chunk_markdown(md_file, kind: "docs", source_label: rel))
        end
      end

      # 6. musa-dsl README
      musa_readme = File.join(source_root, "musa-dsl", "README.md")
      if File.exist?(musa_readme)
        all_chunks.concat(
          chunk_markdown(musa_readme, kind: "gem_readme", source_label: "musa-dsl/README.md")
        )
      end

      # 7. Best practices (plugin's own data dir).
      #
      # The candidates cover both clone names and both layouts: the practices
      # moved under `src/` when the generator was introduced, and this kept
      # looking for the old path. It found nothing, said nothing, and
      # knowledge.db shipped with zero `best_practice` chunks for as long as
      # that lasted -- which is why the assertion below exists. A source that
      # yields nothing is reported, not skipped.
      bp_dir = %w[nota-plugin nota-plugin-for-claude]
               .product([%w[src data best-practices], %w[data best-practices]])
               .collect { |name, parts| File.join(source_root, name, *parts) }
               .find { |candidate| File.directory?(candidate) }

      if bp_dir
        practices = Dir.glob(File.join(bp_dir, "*.md")).sort
        warn "WARNING: #{bp_dir} has no practices to index" if practices.empty?

        practices.each do |md_file|
          rel = relative_path(md_file, source_root)
          all_chunks.concat(chunk_markdown(md_file, kind: "best_practice", source_label: rel))
        end
      else
        warn "WARNING: no best-practices directory found under #{source_root}; " \
             "knowledge.db will have no best_practice chunks"
      end

      # Validate: no chunk should leak absolute filesystem paths
      bad = all_chunks.select { |c| c.metadata["source"]&.start_with?("/") }
      unless bad.empty?
        samples = bad.first(3).map { |c| c.metadata["source"] }
        abort "ERROR: #{bad.length} chunks have absolute source paths (private filesystem info would leak into public DB).\n" \
              "Samples: #{samples.join(", ")}\n" \
              "This is likely a Unicode normalization mismatch between source_root and Dir.glob."
      end

      # Validate: every kind this build is supposed to produce produced something.
      #
      # This exists because it did not. The best-practice source directory moved
      # under `src/` when the generator was introduced and the lookup above kept
      # pointing at the old path; it found nothing, said nothing, and every
      # knowledge.db released after that shipped with zero `best_practice`
      # chunks. Skills went on instructing the assistant to search a kind that
      # was not there, and the only symptom was an answer that quietly omitted
      # what it could not find.
      #
      # A retrieval failure is silent by nature. The only defence is asserting
      # what should be present, so absence has to announce itself.
      counts = all_chunks.group_by { |c| c.metadata["kind"] }.transform_values(&:size)
      empty = EXPECTED_KINDS.reject { |kind| counts[kind].to_i.positive? }

      unless empty.empty?
        abort "ERROR: no chunks produced for #{empty.join(", ")}.\n" \
              "Got: #{counts.sort.map { |k, n| "#{k}=#{n}" }.join(" ")}\n" \
              "Either a source repository is missing from #{source_root}, or a path in " \
              "this file points somewhere the material no longer lives. Building anyway " \
              "would ship a knowledge base that answers questions about #{empty.join(" and ")} " \
              "with silence."
      end

      all_chunks
    end

    def relative_path(path, base)
      # Normalize Unicode to NFC — macOS pwd may return NFD while Dir.glob returns NFC
      path.unicode_normalize(:nfc).sub("#{base.unicode_normalize(:nfc)}/", "")
    end
  end
end
