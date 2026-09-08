# frozen_string_literal: true

# The slice of MCP the setup server needs, written on the standard library.
#
# WHY THIS EXISTS. A server that installs its own dependencies cannot depend on
# them to say so. Every design that put an install inside the thirty seconds
# Claude Code allows for `initialize` lost that race on a cold machine -- with
# seven gems, then with six -- and the race never ended, because its clock
# belongs to the machine. Vendoring `mcp` looked like the way out until the
# closure was measured: `mcp/tool/schema.rb` requires json_schemer at load time,
# json_schemer requires bigdecimal, and bigdecimal has a C extension and stopped
# being a default gem in Ruby 3.4. To answer three questions with text we would
# have carried a schema validator that validates nothing and an arbitrary
# precision arithmetic library.
#
# So the setup server owns this much protocol instead. Nothing is installed,
# nothing is downloaded, nothing can be missing: it answers, and from there it
# can report what the rest of the plugin still needs and install it from a tool
# call, where the budget is hours rather than seconds.
#
# WHAT IT COSTS. We follow the protocol by hand where the gem would follow it
# for us. The surface is small -- five methods -- and the failure mode is the
# better one: it shows up here, with the error in front of us, rather than on
# the machine of someone installing for the first time.
#
# The knowledge base server keeps using the gem. By the time it runs, the gems
# are there, which is precisely what it needs them to have established.

require "json"

module NotaKnowledgeBase
  module StdioServer
    # A tool as the protocol wants it: a name, a sentence for the model, and
    # something to call. Every tool here takes no arguments -- so `inputSchema`
    # is the empty object schema, which the spec still requires to be present --
    # and returns the text the reader will see.
    Tool = Struct.new(:name, :description, :body) do
      def to_h
        {
          "name" => name,
          "description" => description,
          "inputSchema" => { "type" => "object", "properties" => {} }
        }
      end
    end

    # Copied from the gem's rule rather than invented: echo the client's version
    # when we know it, and otherwise answer with a version we know it can read.
    # A server that insisted on its own would be refused by an older client for
    # no reason -- the exchange below carries nothing that ever changed.
    SUPPORTED_PROTOCOL_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"].freeze
    FALLBACK_PROTOCOL_VERSION = "2025-03-26"

    # `instructions` did not exist in the first revision, so it is dropped
    # there instead of being sent and ignored.
    VERSION_WITHOUT_INSTRUCTIONS = "2024-11-05"

    PARSE_ERROR = -32_700
    INVALID_REQUEST = -32_600
    METHOD_NOT_FOUND = -32_601
    INVALID_PARAMS = -32_602

    module_function

    # Reads one JSON object per line from stdin and writes one per line to
    # stdout, until stdin closes -- which is how the harness says it is done.
    #
    # stdout is the transport and carries nothing else. Anything this process
    # wants to say to a human goes to stderr.
    def run(name:, version:, instructions:, tools:)
      $stdout.sync = true
      by_name = tools.to_h { |tool| [tool.name, tool] }

      while (line = $stdin.gets)
        line = line.strip
        next if line.empty?

        respond(dispatch(line, name: name, version: version,
                         instructions: instructions, tools: by_name))
      end
    end

    # Returns the response to send, or nil when there is nothing to send.
    def dispatch(line, name:, version:, instructions:, tools:)
      begin
        message = JSON.parse(line)
      rescue JSON::ParserError => e
        return error(nil, PARSE_ERROR, "Parse error: #{e.message}")
      end

      return error(nil, INVALID_REQUEST, "Expected a JSON-RPC object") unless message.is_a?(Hash)

      id = message["id"]

      # A message without an id is a notification: it is told, not asked, and
      # answering one is a protocol error rather than a courtesy.
      return nil if id.nil?

      case message["method"]
      when "initialize"
        result(id, initialize_result(message["params"], name: name, version: version,
                                                        instructions: instructions))
      when "ping"
        result(id, {})
      when "tools/list"
        result(id, { "tools" => tools.values.map(&:to_h) })
      when "tools/call"
        call(id, message["params"], tools)
      else
        error(id, METHOD_NOT_FOUND, "Method not found: #{message['method']}")
      end
    end

    def initialize_result(params, name:, version:, instructions:)
      requested = params.is_a?(Hash) ? params["protocolVersion"] : nil
      negotiated = SUPPORTED_PROTOCOL_VERSIONS.include?(requested) ? requested : FALLBACK_PROTOCOL_VERSION

      {
        "protocolVersion" => negotiated,
        "capabilities" => { "tools" => { "listChanged" => false } },
        "serverInfo" => { "name" => name, "version" => version },
        "instructions" => (instructions unless negotiated == VERSION_WITHOUT_INSTRUCTIONS)
      }.compact
    end

    # A tool that raises is not a broken protocol, it is a tool that failed, and
    # the difference matters to the reader: a JSON-RPC error is swallowed by the
    # harness, while `isError` comes back as text the model can act on. These
    # tools run installs and downloads, so failing is a thing they do.
    def call(id, params, tools)
      requested = params.is_a?(Hash) ? params["name"] : nil
      tool = tools[requested]

      return error(id, INVALID_PARAMS, "Unknown tool: #{requested.inspect}") if tool.nil?

      begin
        result(id, content(tool.body.call))
      rescue StandardError, ScriptError => e
        result(id, content("#{tool.name} failed: #{e.class}: #{e.message}", error: true))
      end
    end

    def content(text, error: false)
      utf8 = text.to_s.encode("UTF-8", invalid: :replace, undef: :replace)

      { "content" => [{ "type" => "text", "text" => utf8 }], "isError" => error }
    end

    def result(id, payload) = { "jsonrpc" => "2.0", "id" => id, "result" => payload }

    def error(id, code, message)
      { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
    end

    def respond(response)
      return if response.nil?

      $stdout.puts(JSON.generate(response))
    end
  end
end
