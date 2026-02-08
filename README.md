# musa-claude-plugin

Deep MusaDSL knowledge for Claude Code — semantic search over documentation, API reference, and examples for algorithmic composition.

## What it does

This plugin gives Claude Code accurate, in-depth knowledge of the [MusaDSL](https://musadsl.yeste.studio) framework through three layers:

1. **Static reference** (`rules/musadsl-reference.md`) — always loaded in context (~5-8k tokens)
2. **Semantic search** (MCP server + sqlite-vec) — retrieves relevant docs, API, and code examples on demand
3. **Works catalog** — finds similar compositions from demos and private indexed works

### Knowledge Architecture: Two Databases

The plugin uses two separate databases:

- **`knowledge.db`** (public) — Contains documentation, API reference, demo code, and gem READMEs from the MusaDSL ecosystem. This database is pre-built, automatically downloaded from GitHub Releases on session start, and periodically updated. You don't need to do anything to maintain it.

- **`private.db`** (local, optional) — Contains your own indexed compositions. This database is never touched by automatic updates, so your private works are always safe. You create it by indexing your own composition projects (see [Indexing Private Works](#indexing-private-works) below).

When you search, the plugin queries both databases and merges results by relevance (cosine distance). If `private.db` doesn't exist, searches work normally using only the public knowledge base.

### MCP Tools

| Tool | Purpose |
|------|---------|
| `search` | Semantic search across all knowledge (docs, API, demos, private works) |
| `api_reference` | Exact API reference lookup by module/method |
| `similar_works` | Find similar works and demo examples (includes private works) |
| `dependencies` | Dependency chain for a concept (what setup is needed) |
| `pattern` | Code pattern for a specific technique |
| `check_setup` | Check plugin status: API key, knowledge base, private works DB |

### Skills

| Skill | Purpose |
|-------|---------|
| `/musa-claude-plugin:hello` | Welcome, plugin overview, capabilities guide |
| `/musa-claude-plugin:setup` | Plugin configuration and troubleshooting |
| `/musa-claude-plugin:explain` | Explain any MusaDSL concept with accurate, sourced answers |
| `/musa-claude-plugin:index` | Manage private works index (add, list, update, remove compositions) |

## Installation (end users)

### Prerequisites

- Ruby 3.1+
- `VOYAGE_API_KEY` environment variable (for embedding search queries at runtime)

### Steps

Inside Claude Code, run:

```
/plugin marketplace add javier-sy/musa-claude-plugin
/plugin install musa-claude-plugin@javier-sy-musa-claude-plugin
```

Then set your Voyage AI API key (add to your shell profile for persistence):

```bash
export VOYAGE_API_KEY="your-key-here"
```

The pre-built knowledge base (`knowledge.db`) is **automatically downloaded** from GitHub Releases on first session start. No additional setup is needed.

Run `/musa-claude-plugin:hello` to get a welcome and capabilities overview, or `/musa-claude-plugin:setup` to verify configuration.

### Indexing Private Works

You can index your own composition projects so Claude can reference them during search. Private works are stored in a separate local database (`private.db`) that is never affected by knowledge base updates.

Use `/musa-claude-plugin:index` to manage your private works — add, update, remove, and list indexed compositions. The skill guides you through each operation.

The indexer looks for `musa/` subdirectories (Ruby files) and `README.md` files in each project. Once indexed, your private works appear in `search` (kind: `"all"` or `"private_works"`) and `similar_works` results.

> **For plugin developers:** The skill wraps `mcp_server/indexer.rb`, which supports `--add-work PATH`, `--scan DIR`, `--list-works`, `--remove-work NAME`, and `--status`.

## Development (plugin maintainers)

This section is for contributors who want to modify the plugin itself or rebuild the public knowledge base from source. End users do not need any of this.

### Prerequisites

- Everything from the end-user section above
- All MusaDSL source repositories cloned as siblings of `musa-claude-plugin/`
- `VOYAGE_API_KEY` with sufficient quota for embedding ~3000 chunks

### Rebuilding the public knowledge base

```bash
# Generate chunks only (no API key needed, useful for inspection)
make chunks

# Full build: chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
make build

# Package knowledge.db for distribution via GitHub Releases
make package

# Check index status
make status

# Remove all generated artifacts
make clean
```

The CI workflow (`.github/workflows/build-release.yml`) automates building and releasing the public knowledge base. It is triggered by:
- `repository_dispatch` events from the 7 source repositories (when they update)
- Manual workflow dispatch
- Pushes to main that modify the server code

The CI only rebuilds `knowledge.db` — it never touches `private.db`, which is purely local to each user.

## Project Structure

```
musa-claude-plugin/
├── .claude-plugin/          # Plugin metadata (plugin.json, marketplace.json)
├── skills/
│   ├── hello/               # /hello skill — welcome and capabilities overview
│   ├── explain/             # /explain skill — MusaDSL concept explanations
│   ├── index/               # /index skill — manage private works index
│   └── setup/               # /setup skill — configuration and troubleshooting
├── rules/                   # Static reference (always in context)
├── mcp_server/              # Ruby MCP server + sqlite-vec
│   ├── server.rb            # MCP tools (6 tools)
│   ├── search.rb            # Dual-DB search (knowledge.db + private.db)
│   ├── chunker.rb           # Source material → chunks
│   ├── indexer.rb           # Chunk + embed + store orchestrator
│   ├── embeddings.rb        # Voyage AI integration
│   ├── db.rb                # sqlite-vec database management
│   ├── ensure_db.rb         # Auto-download knowledge.db from releases
│   ├── knowledge.db         # Public knowledge base (auto-downloaded)
│   └── private.db           # Private works (local, user-created, never auto-updated)
├── hooks/                   # Session lifecycle hooks (auto-download on start)
├── .mcp.json                # MCP server configuration
├── Gemfile                  # Ruby dependencies
├── Makefile                 # Build targets (for maintainers)
└── .github/workflows/       # CI: build + release public knowledge DB
```

## License

GPL-3.0-or-later

## Author

Javier Sánchez Yeste — [yeste.studio](https://yeste.studio)
