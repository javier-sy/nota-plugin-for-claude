#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP server exposing MusaDSL knowledge base tools.

require "mcp"

require_relative "search"

class SearchTool < MCP::Tool
  description(
    "Search the MusaDSL knowledge base semantically. " \
    "Returns relevant passages from documentation, API, and examples with source attribution."
  )

  input_schema(
    properties: {
      query: {
        type: "string",
        description: 'Natural language query (e.g. "how to create a Markov melody", "series operations for filtering")'
      },
      kind: {
        type: "string",
        description: 'Filter by content type. Options: "all", "docs", "api", "demo_readme", "demo_code", "gem_readme", "private_works".',
        enum: %w[all docs api demo_readme demo_code gem_readme private_works],
        default: "all"
      }
    },
    required: ["query"]
  )

  class << self
    def call(query:, kind: "all", server_context:)
      result = MusaKnowledgeBase::Search.semantic_search(query, kind)
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
      result = MusaKnowledgeBase::Search.api_lookup(module_name, method)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class SimilarWorksTool < MCP::Tool
  description(
    "Find similar works, demos, or composition examples. " \
    "Returns similar demo projects and composition examples with descriptions and key code patterns used."
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
      result = MusaKnowledgeBase::Search.similar_works(description)
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
      result = MusaKnowledgeBase::Search.dependency_chain(concept)
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
      result = MusaKnowledgeBase::Search.code_pattern(technique)
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
          client = MusaKnowledgeBase::Voyage::Client.new(input_type: "query")
          client.embed(["test"])
          status << "- **Voyage API key**: valid"
        rescue => e
          status << "- **Voyage API key**: SET BUT NOT WORKING — the key is configured but the API " \
                    "rejected it. It may be expired, revoked, or mistyped. Error: #{e.message}"
        end
      end

      # Check knowledge DB
      db_path = MusaKnowledgeBase::Search.db_path
      has_db = File.exist?(db_path)
      status << "- **Knowledge base**: #{has_db ? 'present' : 'NOT FOUND'}"

      if has_db
        begin
          db = MusaKnowledgeBase::DB.open
          stats = MusaKnowledgeBase::DB.collection_stats(db)
          db.close
          status << "- **Collections**:"
          stats.each { |name, count| status << "  - #{name}: #{count} chunks" }
        rescue => e
          status << "- **DB error**: #{e.message}"
        end
      end

      # Check private DB
      private_db_path = MusaKnowledgeBase::DB.default_private_db_path
      has_private_db = File.exist?(private_db_path)
      status << "- **Private works DB**: #{has_private_db ? 'present' : 'not present — use /musa-claude-plugin:index to manage your private works'}"

      if has_private_db
        begin
          private_db = MusaKnowledgeBase::DB.open(private_db_path)
          private_stats = MusaKnowledgeBase::DB.collection_stats(private_db)
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

module MusaKnowledgeBase
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
      tools: [SearchTool, ApiReferenceTool, SimilarWorksTool, DependenciesTool, PatternTool, CheckSetupTool]
    )

    transport = MCP::Server::Transports::StdioTransport.new(server)
    transport.open
  end
end

MusaKnowledgeBase.run_server if __FILE__ == $PROGRAM_NAME
