# musa-claude-plugin

Deep MusaDSL knowledge for Claude Code — semantic search, composition coding, creative ideation, and structured musical analysis for algorithmic composition.

## What it does

This plugin transforms Claude Code into an algorithmic composition assistant with deep knowledge of the [MusaDSL](https://musadsl.yeste.studio) framework. It provides 9 interactive skills that cover the entire creative process — from understanding the framework, through brainstorming ideas, to writing verified code and analyzing the results.

Everything is backed by a knowledge base with MusaDSL documentation, API reference, 23 demo projects, and (optionally) your own compositions and their musical analyses.

Say **"hello musa"** to get a welcome and capabilities overview.

## Getting Started

### Prerequisites

- Ruby 3.1+
- A [Voyage AI](https://dash.voyageai.com/) API key

### Install

Inside Claude Code, run:

```
/plugin marketplace add javier-sy/musa-claude-plugin
/plugin install musa-claude-plugin@yeste.studio
```

Then add the API key to your shell profile:

```bash
export VOYAGE_API_KEY="your-key-here"
```

The knowledge base is **automatically downloaded** on first session start. Run `/setup` to verify everything is working.

## Skills

### `/explain` — Semantic search

Ask about any MusaDSL concept and get an accurate, sourced answer. Retrieves relevant documentation, API details, and code examples from the knowledge base.

### `/think` — Creative thinking

Generates ideas for new compositions or explores new directions for existing ones. It draws from multiple sources:

- The **inspiration framework** — a configurable set of creative dimensions
- Your **previous analyses** — to detect patterns in your practice and suggest unexplored directions
- **MusaDSL knowledge** — to ensure every idea maps to concrete, implementable tools and patterns
- **WebSearch** — to connect ideas to composers, techniques, and traditions with accurate references

The default **inspiration framework** has 8 dimensions: Structure, Time, Pitch, Algorithm, Texture, Reference, Dialogue, and Constraint. Customize them with `/inspiration_framework`.

### `/code` — Composition coding

Translates musical intentions into working MusaDSL Ruby code. It can create new compositions from scratch or modify existing ones, drawing from:

- **MusaDSL knowledge** — API reference, documentation, patterns, and demo examples to verify every method call
- **Similar works** — from both the public demos and your own indexed compositions
- Your **existing code** — reading from the filesystem to understand and extend it

You describe your musical intention ("more intense", "like a canon", "more chaotic") and `/code` translates it into concrete technical approaches, always proposing the approach before writing.

### `/index` — Works indexing

Indexes your composition projects so Claude can reference them. All `.rb` and `.md` files are indexed recursively. Once indexed, your works appear in search results and inform all other skills.

Use `/index` to add, update, remove, and list indexed compositions.

### `/analyze` — Musical analysis

Reads your code, interprets it musically, and produces a detailed structured analysis. The analysis is stored as searchable knowledge, enriching future searches, `/think` ideation, and `/code` references. This transforms search from "what does the code say" to "what does the code do musically."

The default **analysis framework** has 9 dimensions: Formal Structure, Harmonic and Modal Language, Rhythmic and Temporal Strategy, Generative Strategy, Texture and Instrumentation, Idiomatic Usage and Special Features, Relation to Other Artists, Notable Technical Patterns, and Conclusion. Customize them with `/analysis_framework`.

Removing a work with `/index` also removes its associated analysis.

### Other skills

| Skill | Purpose |
|-------|---------|
| `/hello` | Welcome and capabilities overview |
| `/setup` | Plugin configuration and troubleshooting |
| `/analysis_framework` | View, customize, or reset the analysis dimensions |
| `/inspiration_framework` | View, customize, or reset the creative dimensions |

## The Creative Cycle

The plugin supports a continuous creative cycle where each step feeds into the next:

```
/think ──→ /code ──→ /index ──→ /analyze ──╮
  ↑                                          │
  ╰──────────────────────────────────────────╯
```

- **`/think`** (ideation) — generates ideas drawing from the inspiration framework, MusaDSL knowledge, and your previous analyses and works. The more you have composed and analyzed, the richer the ideation becomes.
- **`/code`** (composition) — implements ideas as working MusaDSL code, verified against the knowledge base and informed by similar works.
- **`/index`** (knowledge building) — stores the composition's code, making it searchable and available for future reference by all other skills.
- **`/analyze`** (reflection) — reads the code, interprets it musically, and stores the analysis as searchable knowledge.
- Back to **`/think`** — the new analysis enriches future ideation: patterns detected across works, unexplored directions, dialogue with composers.

The two databases are the memory of this cycle:
- **`knowledge.db`** holds MusaDSL knowledge (what is possible)
- **`private.db`** holds your creative practice (what has been done, and what it means)

The cycle is not mandatory — you can enter at any point and use any skill independently. But each step enriches the others.

## Development (plugin maintainers)

This section is for contributors who want to modify the plugin itself or rebuild the public knowledge base from source.

### Architecture

The plugin has three knowledge layers:

1. **Static reference** (`rules/musadsl-reference.md`) — always loaded in context (~5-8k tokens)
2. **Semantic search** (MCP server + sqlite-vec + Voyage AI embeddings) — retrieves relevant docs, API, and code examples on demand
3. **Works catalog** — finds similar compositions from demos and private indexed works

Two separate databases:

- **`knowledge.db`** (public) — Documentation, API reference, demo code, and gem READMEs. Pre-built, automatically downloaded from GitHub Releases on session start. The CI workflow rebuilds it when source repos update.

- **`private.db`** (local, per-user) — User's indexed compositions and musical analyses. Stored at `~/.config/musa-claude-plugin/private.db`, outside the plugin directory, persisting across updates. Never touched by CI or auto-updates.

When searching, the MCP server queries both databases and merges results by cosine distance. If `private.db` doesn't exist, searches use only the public knowledge base.

### MCP Tools (17)

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

### Building the public knowledge base

Prerequisites: all MusaDSL source repositories cloned as siblings of `musa-claude-plugin/`, and `VOYAGE_API_KEY` with sufficient quota for embedding ~3000 chunks.

```bash
make chunks    # Generate chunks only (no API key needed, useful for inspection)
make build     # Full build: chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
make package   # Package knowledge.db for distribution via GitHub Releases
make status    # Check index status
make clean     # Remove all generated artifacts
```

### CI/CD

The CI workflow (`.github/workflows/build-release.yml`) automates building and releasing the public knowledge base. It is triggered by:
- `repository_dispatch` events from the 7 source repositories (when they update)
- Manual workflow dispatch
- Pushes to main that modify the server code

The CI only rebuilds `knowledge.db` — it never touches `private.db`.

### Project Structure

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
│   ├── analysis-framework.md      # Default analysis framework (9 dimensions)
│   └── inspiration-framework.md   # Default inspiration framework (8 dimensions)
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
