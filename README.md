# musa-claude-plugin

Deep MusaDSL knowledge for Claude Code — semantic search, composition coding, creative ideation, and structured musical analysis for algorithmic composition.

## What it does

This plugin gives Claude Code accurate, in-depth knowledge of the [MusaDSL](https://musadsl.yeste.studio) framework through three layers:

1. **Static reference** (`rules/musadsl-reference.md`) — always loaded in context (~5-8k tokens)
2. **Semantic search** (MCP server + sqlite-vec) — retrieves relevant docs, API, and code examples on demand
3. **Works catalog** — finds similar compositions from demos and private indexed works

### Knowledge Architecture: Two Databases

The plugin uses two separate databases:

- **`knowledge.db`** (public) — Contains documentation, API reference, demo code, and gem READMEs from the MusaDSL ecosystem. This database is pre-built, automatically downloaded from GitHub Releases on session start, and periodically updated. You don't need to do anything to maintain it.

- **`private.db`** (local, optional) — Contains your own indexed compositions and their musical analyses. Stored at `~/.config/musa-claude-plugin/private.db`, outside the plugin directory, so it persists across plugin updates. This database is never touched by automatic updates — your private works are always safe. You create it by indexing your own composition projects (see [Indexing Private Works](#indexing-private-works) below) and generating analyses (see [Analyzing Compositions](#analyzing-compositions)).

When you search, the plugin queries both databases and merges results by relevance (cosine distance). If `private.db` doesn't exist, searches work normally using only the public knowledge base.

### MCP Tools

| Tool | Purpose |
|------|---------|
| `search` | Semantic search across all knowledge (docs, API, demos, private works, analyses) |
| `api_reference` | Exact API reference lookup by module/method |
| `similar_works` | Find similar works and demo examples (includes private works and analyses) |
| `dependencies` | Dependency chain for a concept (what setup is needed) |
| `pattern` | Code pattern for a specific technique |
| `check_setup` | Check plugin status: API key, knowledge base, private works DB |
| `list_works` | List all indexed private works with chunk counts |
| `add_work` | Index a private composition work from a given path |
| `remove_work` | Remove a private work from the index by name (also removes associated analysis) |
| `index_status` | Show status of both knowledge databases (public and private) |
| `get_analysis_framework` | Get the current analysis framework (default or user-customized) |
| `save_analysis_framework` | Save a customized analysis framework |
| `reset_analysis_framework` | Reset the analysis framework to default |
| `add_analysis` | Store a composition analysis in the knowledge base |
| `get_inspiration_framework` | Get the current inspiration framework (default or user-customized) |
| `save_inspiration_framework` | Save a customized inspiration framework |
| `reset_inspiration_framework` | Reset the inspiration framework to default |

### Skills

| Skill | Purpose |
|-------|---------|
| `/hello` | Welcome, plugin overview, capabilities guide |
| `/setup` | Plugin configuration and troubleshooting |
| `/explain` | Explain any MusaDSL concept with accurate, sourced answers |
| `/code` | Program or modify MusaDSL compositions with API-verified accuracy |
| `/think` | Generate ideas for compositions, explore creative directions |
| `/index` | Manage private works index (add, list, update, remove compositions) |
| `/analyze` | Generate a structured musical analysis of a composition |
| `/analysis_framework` | View, customize, or reset the analysis framework dimensions |
| `/inspiration_framework` | View, customize, or reset the inspiration framework dimensions |

## Installation (end users)

### Prerequisites

- Ruby 3.1+
- `VOYAGE_API_KEY` environment variable (for embedding search queries at runtime)

### Steps

Inside Claude Code, run:

```
/plugin marketplace add javier-sy/musa-claude-plugin
/plugin install musa-claude-plugin@yeste.studio
```

Then set your Voyage AI API key (add to your shell profile for persistence):

```bash
export VOYAGE_API_KEY="your-key-here"
```

The pre-built knowledge base (`knowledge.db`) is **automatically downloaded** from GitHub Releases on first session start. No additional setup is needed.

Say **"hello musa"** to get a welcome and capabilities overview, or run `/setup` to verify configuration.

### Indexing Private Works

You can index your own composition projects so Claude can reference them during search. Private works are stored in a separate local database (`private.db`) that is never affected by knowledge base updates.

Use `/index` to manage your private works — add, update, remove, and list indexed compositions. The skill guides you through each operation.

The indexer recursively indexes all `.rb` and `.md` files from the given directory. Once indexed, your private works appear in `search` (kind: `"all"` or `"private_works"`) and `similar_works` results.

> **For plugin developers:** The `/index` skill uses the MCP tools (`list_works`, `add_work`, `remove_work`, `index_status`). The CLI (`mcp_server/indexer.rb`) is only used for building the public knowledge base (`--chunks-only`, `--embed`, `--status`).

### Analyzing Compositions

Beyond indexing code, you can generate structured musical analyses of your compositions. Use `/analyze` to have Claude read your code, interpret it musically, and produce a detailed analysis covering multiple dimensions (formal structure, harmonic language, generative strategy, etc.).

Analyses are stored as searchable knowledge in `private.db` (kind: `"analysis"`), so they enrich future searches and `similar_works` results. This transforms search from "what does the code say" to "what does the code do musically."

The analysis is guided by a configurable **analysis framework** — a set of analytical dimensions. Use `/analysis_framework` to view, customize, or reset the dimensions. The default framework covers 8 dimensions including formal structure, harmonic language, rhythmic strategy, generative tools, texture, idiomatic usage, relations to other artists, and notable patterns.

Removing a work with `/index` also removes its associated analysis.

### Composing with Code

Use `/code` to program new compositions or modify existing ones. The skill translates musical intentions into working MusaDSL Ruby code, verifying every API method against the knowledge base. It proposes an approach before writing, generates complete project structures for new compositions, and warns about common pitfalls. When you describe something musically ("more intense", "like a canon", "more chaotic"), `/code` translates it into concrete technical approaches.

### Creative Thinking

Use `/think` to brainstorm ideas for new compositions or explore new directions. The skill generates ideas across multiple creative dimensions, grounded in what MusaDSL can actually do. It uses WebSearch to connect ideas to composers, techniques, and traditions.

Creative thinking is guided by a configurable **inspiration framework** with 7 default dimensions: Structure, Time, Pitch, Algorithm, Texture, Reference, and Constraint. Use `/inspiration_framework` to customize the dimensions. The inspiration framework is independent from the analysis framework — they serve different purposes and evolve separately.

The complete creative cycle: `/think` (generate ideas) -> `/code` (implement) -> `/index` (index the work) -> `/analyze` (analyze it) -> `/think` (new ideas from the analysis).

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
│   ├── code/                # /code skill — composition coding and modification
│   ├── think/               # /think skill — creative ideation and brainstorming
│   ├── index/               # /index skill — manage private works index
│   ├── analyze/             # /analyze skill — structured composition analysis
│   ├── analysis_framework/  # /analysis_framework skill — manage analysis dimensions
│   ├── inspiration_framework/ # /inspiration_framework skill — manage inspiration dimensions
│   └── setup/               # /setup skill — configuration and troubleshooting
├── defaults/                # Default configuration files
│   ├── analysis-framework.md      # Default analysis framework (8 dimensions)
│   └── inspiration-framework.md   # Default inspiration framework (7 dimensions)
├── rules/                   # Static reference (always in context)
├── mcp_server/              # Ruby MCP server + sqlite-vec
│   ├── server.rb            # MCP tools (17 tools)
│   ├── search.rb            # Dual-DB search (knowledge.db + private.db)
│   ├── chunker.rb           # Source material → chunks
│   ├── indexer.rb           # Chunk + embed + store orchestrator
│   ├── embeddings.rb        # Voyage AI integration
│   ├── db.rb                # sqlite-vec database management
│   ├── ensure_db.rb         # Auto-download knowledge.db from releases
│   └── knowledge.db         # Public knowledge base (auto-downloaded)
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
