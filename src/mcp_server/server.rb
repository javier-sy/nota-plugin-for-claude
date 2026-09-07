#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP server exposing MusaDSL knowledge base tools.

require "mcp"

require_relative "config"
require_relative "search"
require_relative "lint"

# The eight layers, in ONE place.
#
# Every tool below quotes from this. It is not repeated in the skills, because a
# rule that lives in eleven files is a rule that will disagree with itself: the
# skills cite the contract, the contract lives here, and when it changes it
# changes once.
LAYERS = <<~LAYERS
  Each kind answers a different question, and asking the wrong one gets a fluent
  answer to a question you did not have:

  - `docs`           the mental model: WHEN is this the answer, where the boundary
                     is, what the surprise is. Ask it with the SHAPE OF THE PROBLEM,
                     never with the name of the solution you already picked.
  - `api`            the contract: what it does exactly, with what signature. Ask
                     with an identifier -- and prefer api_reference, which looks
                     names up instead of guessing at them.
  - `demo_code`      the wiring: how a working case is assembled. NEVER evidence
                     for a choice of form.
  - `demo_readme`    the public precedent: does a piece like this exist.
  - `gem_readme`     the ecosystem: which gem, what setup.
  - `best_practice`  the convention: how this is done HERE.
  - `private_works`  the user's own voice: how they solved it before.
  - `analysis`       what that voice means: their tendencies, their trajectory.

  Two rules that hold across all of them:

  - A demo never justifies a choice of form. It shows how something is wired, not
    when it is the right thing to wire.
  - A `docs` snippet ROUTES; it does not decide. Read the document whole with
    get_doc before resting an argument on it.
LAYERS

class SearchTool < MCP::Tool
  description(
    "Search the MusaDSL knowledge base. One kind per query, several queries per call: " \
    "each is ranked on its own, under its own heading, and nothing is merged.\n\n" \
    "Consulting is formulating SEVERAL DIFFERENT QUESTIONS, one per layer that has " \
    "something to say. Ask the conceptual layer what shape the problem is, the API " \
    "what a name means, the demos how a thing is wired -- and relate the answers " \
    "yourself. That relating is the work; no ranking can do it for you.\n\n" + LAYERS
  )

  input_schema(
    properties: {
      queries: {
        type: "array",
        description: "One entry per layer you need. Two or three is usual; one is fine when only one layer applies.",
        items: {
          type: "object",
          properties: {
            kind: {
              type: "string",
              description: "Which layer to ask. Required: there is no undifferentiated search.",
              enum: %w[docs api demo_readme demo_code gem_readme best_practice private_works analysis]
            },
            query: {
              type: "string",
              description: 'Phrased for THIS layer. For `docs`, the shape of the problem ("a plan of sections each with a duration"), not the verb you had in mind.'
            },
            n_results: {
              type: "integer",
              description: "How many results from this layer (1-10). Fewer for contracts, more for concepts.",
              default: 5
            }
          },
          required: %w[kind query]
        }
      }
    },
    required: ["queries"]
  )

  class << self
    def call(queries:, server_context:)
      specs = Array(queries).collect do |q|
        h = q.respond_to?(:transform_keys) ? q.transform_keys(&:to_sym) : q
        { kind: h[:kind], query: h[:query], n_results: h[:n_results] }
      end

      result = NotaKnowledgeBase::Search.multi_search(specs)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ApiReferenceTool < MCP::Tool
  description(
    "Look up a MusaDSL identifier BY NAME. Exact match first, then prefix, then -- " \
    "clearly labelled as something else -- the nearest chunks semantically.\n\n" \
    "It can say NO. When it reports that a name is not in the indexed API, that is " \
    "information: check rubydoc.info before telling the user the method does not exist, " \
    "and never invent one to fill the gap."
  )

  input_schema(
    properties: {
      module_name: {
        type: "string",
        description: 'Module or class name (e.g. "Series", "Markov", "Sequencer", "Scales", "MIDIVoices", "Transport")'
      },
      method: {
        type: "string",
        description: 'Optional method name (e.g. "map", "next_value", "play", "note"). Leave empty for the module itself.',
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

class GetDocTool < MCP::Tool
  description(
    "Read a whole musa-dsl document out of the INSTALLED gem.\n\n" \
    "Use this after a `docs` search has told you WHICH document discusses your " \
    "problem. The snippet routes; this decides. A boundary between two verbs lives " \
    "in how a document relates its own parts, not in the fragment that most " \
    "resembled your query -- so no choice of form should rest on a snippet.\n\n" \
    "It reads the version the user actually has installed, and says which."
  )

  input_schema(
    properties: {
      name: {
        type: "string",
        description: 'Document name, as `list_docs` gives it (e.g. "subsystems/series", "idioms", "guides/project-structure", "vocabulary").'
      }
    },
    required: ["name"]
  )

  class << self
    def call(name:, server_context:)
      result = NotaKnowledgeBase::Search.get_doc(name)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class ListDocsTool < MCP::Tool
  description(
    "List the musa-dsl documents available to read whole with `get_doc`, from the " \
    "installed gem. Enumeration, not recommendation: which one you need is your judgement."
  )

  class << self
    def call(server_context:)
      result = NotaKnowledgeBase::Search.list_docs
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end

class LintTool < MCP::Tool
  description(
    "Read MusaDSL composition code and report what a reader can see in the text. " \
    "**Run it before showing code to the user — every time, without exception.**\n\n" \
    "It needs no API key, no database and no network, so it works when everything " \
    "else is unreachable, which is exactly when guessing is most tempting.\n\n" \
    "Two lists, and they are not the same thing. *Certain* findings are facts about " \
    "the text: a syntax error, a `1/4` that is integer zero, a constructor in a file " \
    "that never included its module. Fix those. *Worth arguing* findings are shapes " \
    "that are usually the generalist reflex and occasionally exactly right — **the " \
    "lint points, you judge**: change it, or say in one line why this is the case " \
    "where the reflex is correct. Passing over one in silence is the one thing that " \
    "is not acceptable.\n\n" \
    "A clean report says the text is clean. It says NOTHING about whether the form " \
    "is right; that is the modelling table's job and no regular expression can do it."
  )

  input_schema(
    properties: {
      code: {
        type: "string",
        description: "The Ruby composition code about to be shown or written."
      },
      filename: {
        type: "string",
        description: "Optional name, used only in messages (e.g. \"score.rb\").",
        default: ""
      }
    },
    required: ["code"]
  )

  class << self
    def call(code:, filename: "", server_context:)
      name = filename.to_s.empty? ? nil : filename
      MCP::Tool::Response.new([{ type: "text", text: NotaKnowledgeBase::Lint.report(code, filename: name) }])
    end
  end
end

class SimilarWorksTool < MCP::Tool
  description(
    "Find works resembling a description. Each collection is ranked SEPARATELY and " \
    "labelled: public demos apart from the user's own pieces and analyses.\n\n" \
    "They are different evidence. A precedent somebody else set is not the same thing " \
    "as something you did yourself, and merging them into one ranking lets whichever " \
    "happens to sit nearer hide the other."
  )

  input_schema(
    properties: {
      description: {
        type: "string",
        description: 'The piece as you would describe it musically (e.g. "canon over Fibonacci rhythms", "harmony that drifts by weighted steps")'
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
      api_key_raw = NotaKnowledgeBase::Config.env("VOYAGE_API_KEY")
      if api_key_raw.nil? || api_key_raw.empty?
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

      # Check the loadable extension. It comes before the index in the report
      # because without it the index cannot be opened at all.
      if NotaKnowledgeBase::VecExtension.target.nil?
        status << "- **sqlite-vec extension**: NOT AVAILABLE for #{NotaKnowledgeBase::VecExtension.platform_name} — " \
                  "upstream publishes no build for this platform."
      elsif NotaKnowledgeBase::VecExtension.available?
        status << "- **sqlite-vec extension**: `#{NotaKnowledgeBase::VecExtension.path}`"
      else
        status << "- **sqlite-vec extension**: NOT DOWNLOADED YET — it is fetched on first use " \
                  "from #{NotaKnowledgeBase::VecExtension.asset_url}"
      end

      # Check knowledge DB.
      #
      # An absent index is not a fault, and saying "NOT FOUND" made it read like
      # one: Search downloads it on the first question asked, exactly as the
      # loadable above is fetched on first use. Reporting it as a failure sent a
      # reader looking for a remedy that was not needed -- and the remedy the
      # setup skill offered, restarting, was not even the one that works.
      db_path = NotaKnowledgeBase::Search.db_path
      has_db = File.exist?(db_path)

      status << if has_db
                  "- **Knowledge base**: present"
                else
                  "- **Knowledge base**: NOT DOWNLOADED YET — it is fetched on first use, " \
                  "from the latest release of #{NotaKnowledgeBase::Config.github_repo}"
                end

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
      # Named, not just tested: when the harness could not tell us where the
      # user's home is, this is the line that shows what we resolved instead.
      status << "- **User directory**: `#{NotaKnowledgeBase::Config.user_dir}`"

      private_db_path = NotaKnowledgeBase::DB.default_private_db_path
      has_private_db = File.exist?(private_db_path)
      private_label = has_private_db ? 'present' : "not present — use #{NotaKnowledgeBase::Config.cmd_ref('index')} to manage your private works"
      status << "- **Private works DB**: #{private_label}"

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
        description: "Where to save: \"private\" (user, #{NotaKnowledgeBase::Config.user_dir}/best-practices/) or \"global\" (plugin, data/best-practices/). Default: \"private\".",
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
    # knowledge.db is NOT downloaded here. It is 9 MB compressed, 27 MB on disk,
    # and this runs inside the harness's window for answering `initialize` —
    # thirty seconds, shared with installing the server's gems. A first session
    # on a slow connection spent it here and was reported as CONNECT_TIMEOUT,
    # which names nothing.
    #
    # It arrives by the two paths that have room for it: the SessionStart hook,
    # which has its own budget and runs in the background, and `Search.db_available?`,
    # which fetches it on the first question if the hook has not finished. A tool
    # call can wait; a handshake cannot.

    server = MCP::Server.new(
      name: "musadsl-kb",
      version: "1.0.0",
      instructions:
        "MusaDSL knowledge base server. Provides semantic search over " \
        "documentation, API reference, demo examples, and composition works " \
        "for the MusaDSL algorithmic composition framework in Ruby.",
      tools: [SearchTool, ApiReferenceTool, GetDocTool, ListDocsTool, LintTool, SimilarWorksTool, CheckSetupTool,
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
