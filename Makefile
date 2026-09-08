PLUGIN_ROOT := $(shell pwd)
SOURCE_ROOT := $(PLUGIN_ROOT)/..
DB_PATH     := $(PLUGIN_ROOT)/src/mcp_server/knowledge.db
CHUNKS_DIR  := $(PLUGIN_ROOT)/src/data/chunks
RUBY        := bundle exec ruby

# `spec` collides with the spec/ directory: without .PHONY, make considers the
# target already made and `make check` passes green without running one example.
.PHONY: setup chunks embed build package clean verify-server status generate \
        generate-claude generate-opencode contract battery check spec

## Install Ruby gem dependencies
setup:
	bundle install

## Generate JSONL chunks only (no API key needed)
chunks:
	$(RUBY) src/mcp_server/indexer.rb \
		--source-root "$(SOURCE_ROOT)" \
		--chunks-dir "$(CHUNKS_DIR)" \
		--chunks-only

## Generate chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
embed:
	$(RUBY) src/mcp_server/indexer.rb \
		--source-root "$(SOURCE_ROOT)" \
		--chunks-dir "$(CHUNKS_DIR)" \
		--db-path "$(DB_PATH)" \
		--embed

## Full build: chunks + embeddings
build: chunks embed

## Package knowledge.db for distribution
package:
	gzip -c "$(DB_PATH)" > knowledge.db.gz

## Generate per-harness plugin output (claude-code + opencode) from src/ + targets/
generate:
	$(RUBY) scripts/generate.rb

generate-claude:
	$(RUBY) scripts/generate.rb --target claude-code

generate-opencode:
	$(RUBY) scripts/generate.rb --target opencode

## Remove generated artifacts
clean:
	rm -f "$(DB_PATH)" "$(DB_PATH).version" "$(DB_PATH).last_check"
	rm -rf "$(CHUNKS_DIR)" dist knowledge.db.gz

## Test MCP server starts and responds to initialize
verify-server:
	@echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}},"id":1}' | \
		$(RUBY) src/mcp_server/boot.rb 2>&1 | \
		head -1 | grep -q '"jsonrpc"' && echo "Setup server responds OK" || (echo "Setup server failed to respond" && exit 1)
	@echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}},"id":1}' | \
		$(RUBY) src/mcp_server/server.rb 2>&1 | \
		head -1 | grep -q '"jsonrpc"' && echo "Knowledge base responds OK" || (echo "Knowledge base failed to respond" && exit 1)

## Check that the documents Nota reads from musa-dsl are where it says they are
contract:
	$(RUBY) tools/contract-check.rb

## Measure whether questions asked by intention land on the right document
battery:
	$(RUBY) tools/retrieval-battery.rb

## Everything that can be checked without a person: server, contract, specs
check: verify-server contract spec

## Run the plugin's own specs
spec:
	bundle exec rspec

## Show index status
status:
	$(RUBY) src/mcp_server/indexer.rb \
		--chunks-dir "$(CHUNKS_DIR)" \
		--db-path "$(DB_PATH)" \
		--status
