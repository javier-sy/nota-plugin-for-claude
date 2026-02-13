#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP server exposing MusaDSL knowledge base tools (17 tools).

require "mcp"

require_relative "search"

class SearchTool < MCP::Tool
  description(
    "Search the MusaDSL knowledge base semantically. " \
    "Returns relevant passages from documentation, API, examples, private works, and composition analyses with source attribution."
  )

  input_schema(
    properties: {
      query: {
        type: "string",
        description: 'Natural language query (e.g. "how to create a Markov melody", "series operations for filtering")'
      },
      kind: {
        type: "string",
        description: 'Filter by content type. Options: "all", "docs", "api", "demo_readme", "demo_code", "gem_readme", "private_works", "analysis".',
        enum: %w[all docs api demo_readme demo_code gem_readme private_works analysis best_practice],
        default: "all"
      }
    },
    required: ["query"]
  )

  class << self
    def call(query:, kind: "all", server_context:)
      result = NotaKnowledgeBase::Search.semantic_search(query, kind)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ApiReferenceTool < MCP::Tool
  description(
    "Look up exact API reference for a MusaDSL module or method. " \
    "Returns API documentation including method signatures, parameters, return types, and usage examples."
  )

  input_schema(
    properties: {
      module_name: {
        type: "string",
        description: 'Module name (e.g. "Series", "Markov", "Sequencer", "Scales", "MIDIVoices", "NeumaDecoder", "Transport")'
      },
      method: {
        type: "string",
        description: 'Optional method name (e.g. "map", "next_value", "play", "note", "chord"). Leave empty for module overview.',
        default: ""
      }
    },
    required: ["module_name"]
  )

  class << self
    def call(module_name:, method: "", server_context:)
      result = NotaKnowledgeBase::Search.api_lookup(module_name, method)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class SimilarWorksTool < MCP::Tool
  description(
    "Find similar works, demos, or composition examples. " \
    "Returns similar demo projects, composition examples, and related analyses with descriptions and key code patterns used."
  )

  input_schema(
    properties: {
      description: {
        type: "string",
        description: 'Description of the composition technique or style (e.g. "canon using Fibonacci rhythms", "generative harmonic progression with Markov chains")'
      }
    },
    required: ["description"]
  )

  class << self
    def call(description:, server_context:)
      result = NotaKnowledgeBase::Search.similar_works(description)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class DependenciesTool < MCP::Tool
  description(
    "Get the dependency chain / setup requirements for a concept. " \
    "Returns what needs to be set up (gems, objects, configuration) to use this concept, in the correct order."
  )

  input_schema(
    properties: {
      concept: {
        type: "string",
        description: 'The MusaDSL concept to check dependencies for (e.g. "ornaments", "MIDI output", "live coding", "MusicXML export")'
      }
    },
    required: ["concept"]
  )

  class << self
    def call(concept:, server_context:)
      result = NotaKnowledgeBase::Search.dependency_chain(concept)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class PatternTool < MCP::Tool
  description(
    "Get a code pattern for a specific composition technique. " \
    "Returns working Ruby code pattern with comments explaining each part."
  )

  input_schema(
    properties: {
      technique: {
        type: "string",
        description: 'The technique to get a pattern for (e.g. "canon", "chord progression", "section chaining", "polyrhythm", "generative melody")'
      }
    },
    required: ["technique"]
  )

  class << self
    def call(technique:, server_context:)
      result = NotaKnowledgeBase::Search.code_pattern(technique)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class CheckSetupTool < MCP::Tool
  description(
    "Check the setup status of the MusaDSL knowledge base plugin. " \
    "Reports whether the API key is configured and the knowledge base is available."
  )

  class << self
    def call(server_context:)
      require_relative "embeddings"

      status = []
      status << "## Plugin Setup Status"
      status << ""

      # Check Voyage API key: not set vs set-but-invalid vs valid
      api_key_raw = ENV["VOYAGE_API_KEY"]
      if api_key_raw.nil? || api_key_raw.empty? || api_key_raw.include?("${")
        status << "- **Voyage API key**: NOT CONFIGURED — no VOYAGE_API_KEY environment variable found. " \
                  "You need to obtain a key from https://dash.voyageai.com/ and add it to your shell profile."
      else
        # Test the key with a minimal embedding call
        begin
          client = NotaKnowledgeBase::Voyage::Client.new(input_type: "query")
          client.embed(["test"])
          status << "- **Voyage API key**: valid"
        rescue => e
          status << "- **Voyage API key**: SET BUT NOT WORKING — the key is configured but the API " \
                    "rejected it. It may be expired, revoked, or mistyped. Error: #{e.message}"
        end
      end

      # Check knowledge DB
      db_path = NotaKnowledgeBase::Search.db_path
      has_db = File.exist?(db_path)
      status << "- **Knowledge base**: #{has_db ? 'present' : 'NOT FOUND'}"

      if has_db
        begin
          db = NotaKnowledgeBase::DB.open
          stats = NotaKnowledgeBase::DB.collection_stats(db)
          db.close
          status << "- **Collections**:"
          stats.each { |name, count| status << "  - #{name}: #{count} chunks" }
        rescue => e
          status << "- **DB error**: #{e.message}"
        end
      end

      # Check private DB
      private_db_path = NotaKnowledgeBase::DB.default_private_db_path
      has_private_db = File.exist?(private_db_path)
      status << "- **Private works DB**: #{has_private_db ? 'present' : 'not present — use /nota:index to manage your private works'}"

      if has_private_db
        begin
          private_db = NotaKnowledgeBase::DB.open(private_db_path)
          private_stats = NotaKnowledgeBase::DB.collection_stats(private_db)
          private_db.close
          private_stats.each { |name, count| status << "  - #{name}: #{count} chunks" }
        rescue => e
          status << "  - **Private DB error**: #{e.message}"
        end
      end

      MCP::Tool::Response.new([{ type: "text", text: status.join("\n") }])
    end
  end
end

class ListWorksTool < MCP::Tool
  description("List all indexed private works with chunk counts.")

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.list_works
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class AddWorkTool < MCP::Tool
  description(
    "Index a private composition work. " \
    "Indexes all Ruby and Markdown files recursively from the given directory."
  )

  input_schema(
    properties: {
      work_path: {
        type: "string",
        description: "Absolute path to the composition project directory"
      }
    },
    required: ["work_path"]
  )

  class << self
    def call(work_path:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.add_work(work_path)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class RemoveWorkTool < MCP::Tool
  description("Remove a private work from the index by name. Also removes any associated analysis.")

  input_schema(
    properties: {
      work_name: {
        type: "string",
        description: "Name of the work to remove (as shown by list_works)"
      }
    },
    required: ["work_name"]
  )

  class << self
    def call(work_name:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.remove_work(work_name)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class IndexStatusTool < MCP::Tool
  description(
    "Show the status of both knowledge databases (public knowledge.db and private works)."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.index_status
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class GetAnalysisFrameworkTool < MCP::Tool
  description(
    "Get the current analysis framework used for composition analysis. " \
    "Returns the framework content and whether it is the default or a user-customized version."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.get_analysis_framework
      text = "**Source**: #{result[:source]}\n\n#{result[:content]}"
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end
  end
end

class SaveAnalysisFrameworkTool < MCP::Tool
  description(
    "Save a customized analysis framework. " \
    "Replaces the current framework with the provided content."
  )

  input_schema(
    properties: {
      content: {
        type: "string",
        description: "The full markdown content of the analysis framework (with ## sections for each dimension)"
      }
    },
    required: ["content"]
  )

  class << self
    def call(content:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.save_analysis_framework(content)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ResetAnalysisFrameworkTool < MCP::Tool
  description(
    "Reset the analysis framework to the default. " \
    "Removes any user customization."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.reset_analysis_framework
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class GetInspirationFrameworkTool < MCP::Tool
  description(
    "Get the current inspiration framework used for creative ideation. " \
    "Returns the framework content and whether it is the default or a user-customized version."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.get_inspiration_framework
      text = "**Source**: #{result[:source]}\n\n#{result[:content]}"
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end
  end
end

class SaveInspirationFrameworkTool < MCP::Tool
  description(
    "Save a customized inspiration framework. " \
    "Replaces the current framework with the provided content."
  )

  input_schema(
    properties: {
      content: {
        type: "string",
        description: "The full markdown content of the inspiration framework (with ## sections for each dimension)"
      }
    },
    required: ["content"]
  )

  class << self
    def call(content:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.save_inspiration_framework(content)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ResetInspirationFrameworkTool < MCP::Tool
  description(
    "Reset the inspiration framework to the default. " \
    "Removes any user customization."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.reset_inspiration_framework
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class AddAnalysisTool < MCP::Tool
  description(
    "Store a composition analysis in the knowledge base. " \
    "The analysis text is chunked by ## sections and indexed for semantic search."
  )

  input_schema(
    properties: {
      work_name: {
        type: "string",
        description: "Name of the work being analyzed (as shown by list_works, e.g. '2024-01-15 Piece Name [musa bw]')"
      },
      analysis_text: {
        type: "string",
        description: "The full analysis text in markdown format (with ## sections for each analytical dimension)"
      }
    },
    required: %w[work_name analysis_text]
  )

  class << self
    def call(work_name:, analysis_text:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.add_analysis(work_name, analysis_text)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class SaveBestPracticeTool < MCP::Tool
  description(
    "Save a best practice to the knowledge base. " \
    "Writes a markdown file and indexes it for semantic search."
  )

  input_schema(
    properties: {
      name: {
        type: "string",
        description: 'Slug-style name for the practice (e.g. "shutdown-pattern", "seed-reproducibility")'
      },
      content: {
        type: "string",
        description: "Full markdown content of the best practice (with # title, ## Description, ## Example, optional ## Anti-pattern)"
      },
      scope: {
        type: "string",
        description: 'Where to save: "private" (user, ~/.config/nota/best-practices/) or "global" (plugin, data/best-practices/). Default: "private".',
        enum: %w[private global],
        default: "private"
      }
    },
    required: %w[name content]
  )

  class << self
    def call(name:, content:, scope: "private", server_context:)
      require_relative "indexer"
      result = if scope == "global"
                 NotaKnowledgeBase::Indexer.save_global_best_practice(name, content)
               else
                 NotaKnowledgeBase::Indexer.save_best_practice(name, content)
               end
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ListBestPracticesTool < MCP::Tool
  description("List all user best practices with their indexing status.")

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.list_best_practices
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class RemoveBestPracticeTool < MCP::Tool
  description("Remove a user best practice by name. Deletes the file and removes chunks from the index.")

  input_schema(
    properties: {
      name: {
        type: "string",
        description: "Name of the practice to remove (as shown by list_best_practices)"
      }
    },
    required: ["name"]
  )

  class << self
    def call(name:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.remove_best_practice(name)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class GetBestPracticesIndexTool < MCP::Tool
  description(
    "Get the user's condensed best practices index. " \
    "Returns a summary of all user best practices, or a message if none exist yet."
  )

  class << self
    def call(server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.get_best_practices_index
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class SaveBestPracticesIndexTool < MCP::Tool
  description(
    "Save the user's condensed best practices index. " \
    "Stores a markdown summary distilled from all user best practices."
  )

  input_schema(
    properties: {
      content: {
        type: "string",
        description: "The condensed best practices index in markdown format"
      }
    },
    required: ["content"]
  )

  class << self
    def call(content:, server_context:)
      require_relative "indexer"
      result = NotaKnowledgeBase::Indexer.save_best_practices_index(content)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

module NotaKnowledgeBase
  def self.run_server
    # Ensure knowledge.db exists before accepting tool calls.
    # Covers: first install, plugin update (new cache dir), hook failure.
    require_relative "ensure_db"
    db_path = DB.default_db_path
    unless File.exist?(db_path)
      $stderr.puts "[musadsl-kb] knowledge.db not found, downloading..."
      begin
        EnsureDB.run(db_path, force: true)
      rescue => e
        $stderr.puts "[musadsl-kb] download failed: #{e.message}"
      end
    end

    server = MCP::Server.new(
      name: "musadsl-kb",
      version: "1.0.0",
      instructions:
        "MusaDSL knowledge base server. Provides semantic search over " \
        "documentation, API reference, demo examples, and composition works " \
        "for the MusaDSL algorithmic composition framework in Ruby.",
      tools: [SearchTool, ApiReferenceTool, SimilarWorksTool, DependenciesTool, PatternTool, CheckSetupTool,
              ListWorksTool, AddWorkTool, RemoveWorkTool, IndexStatusTool,
              GetAnalysisFrameworkTool, SaveAnalysisFrameworkTool, ResetAnalysisFrameworkTool, AddAnalysisTool,
              GetInspirationFrameworkTool, SaveInspirationFrameworkTool, ResetInspirationFrameworkTool,
              SaveBestPracticeTool, ListBestPracticesTool, RemoveBestPracticeTool,
              GetBestPracticesIndexTool, SaveBestPracticesIndexTool]
    )

    transport = MCP::Server::Transports::StdioTransport.new(server)
    transport.open
  end
end

NotaKnowledgeBase.run_server if __FILE__ == $PROGRAM_NAME
