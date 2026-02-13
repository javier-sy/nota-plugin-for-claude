# Nota — plugin for Claude Code

MusaDSL composition assistant: learn the framework, code compositions, explore ideas, analyze music.

## What it does

Nota transforms Claude Code into an algorithmic composition assistant with deep knowledge of the [MusaDSL](https://musadsl.yeste.studio) framework. It provides 10 interactive skills that cover the entire creative process — from understanding the framework, through brainstorming ideas, to writing verified code, analyzing the results, and consolidating best practices.

Everything is backed by a knowledge base with MusaDSL documentation, API reference, 23 demo projects, and (optionally) your own compositions and their musical analyses.

Say **"hello musa"** to get a welcome and capabilities overview.

## Getting Started

### Prerequisites

- Ruby 3.1+
- A [Voyage AI](https://dash.voyageai.com/) API key

### Install

Inside Claude Code, run:

```
/plugin marketplace add javier-sy/nota-plugin-for-claude
/plugin install nota@yeste.studio
```

Then add the API key to your shell profile:

```bash
export VOYAGE_API_KEY="your-key-here"
```

The knowledge base is **automatically downloaded** on first session start. Run `/nota:setup` to verify everything is working.

## Skills

### `/nota:explain` — Semantic search

Ask about any MusaDSL concept and get an accurate, sourced answer. Retrieves relevant documentation, API details, and code examples from the knowledge base.

### `/nota:think` — Creative thinking

Generates ideas for new compositions or explores new directions for existing ones. It draws from multiple sources:

- The **inspiration framework** — a configurable set of creative dimensions
- Your **previous analyses** — to detect patterns in your practice and suggest unexplored directions
- **MusaDSL knowledge** — to ensure every idea maps to concrete, implementable tools and patterns
- **WebSearch** — to connect ideas to composers, techniques, and traditions with accurate references

The default **inspiration framework** has 9 dimensions: Structure, Time, Pitch, Algorithm, Texture, Instrumentation, Reference, Dialogue, and Constraint. Customize them with `/nota:inspiration_framework`.

### `/nota:code` — Composition coding

Translates musical intentions into working MusaDSL Ruby code. It can create new compositions from scratch or modify existing ones, drawing from:

- **MusaDSL knowledge** — API reference, documentation, patterns, and demo examples to verify every method call
- **Similar works** — from both the public demos and your own indexed compositions
- Your **existing code** — reading from the filesystem to understand and extend it

You describe your musical intention ("more intense", "like a canon", "more chaotic") and `/nota:code` translates it into concrete technical approaches, always proposing the approach before writing.

### `/nota:index` — Works indexing

Indexes your composition projects so Claude can reference them. All `.rb` and `.md` files are indexed recursively. Once indexed, your works appear in search results and inform all other skills.

Use `/nota:index` to add, update, remove, and list indexed compositions.

### `/nota:analyze` — Musical analysis

Reads your code, interprets it musically, and produces a detailed structured analysis. The analysis is stored as searchable knowledge, enriching future searches, `/nota:think` ideation, and `/nota:code` references. This transforms search from "what does the code say" to "what does the code do musically."

The default **analysis framework** has 10 dimensions: Formal Structure, Harmonic and Modal Language, Rhythmic and Temporal Strategy, Generative Strategy, Texture and Instrumentation, Idiomatic Usage and Special Features, Relation to Other Artists, Notable Technical Patterns, Coding Best Practices, and Conclusion. Customize them with `/nota:analysis_framework`.

Removing a work with `/nota:index` also removes its associated analysis.

### `/nota:best-practices` — Best practices management

Manages best practices for MusaDSL composition projects. Practices can be:

- **Generated from analyses** — extracts recurring patterns from your composition analyses and formalizes them
- **Added manually** — describe a practice and the LLM structures it with title, description, example, and optional anti-pattern
- **Listed, edited, removed** — full CRUD for your practice catalog

Two layers:
- **General practices** ship with the plugin (12 practices covering project structure, runtime patterns, and coding style), indexed in `knowledge.db` and searchable via `search` with `kind: "best_practice"`.
- **User practices** are private, stored in `~/.config/nota/best-practices/`, indexed in `private.db`.

`/nota:code` automatically searches best practices during its research step, so your consolidated patterns are applied when writing new code.

### Other skills

| Skill | Purpose |
|-------|---------|
| `/nota:hello` | Welcome and capabilities overview |
| `/nota:setup` | Plugin configuration and troubleshooting |
| `/nota:analysis_framework` | View, customize, or reset the analysis dimensions |
| `/nota:inspiration_framework` | View, customize, or reset the creative dimensions |

## The Creative Cycle

The plugin supports a continuous creative cycle where each step feeds into the next:

```
/nota:think ──→ /nota:code ──→ /nota:index ──→ /nota:analyze ──╮
  ↑                 ↑                              │            │
  │                 │                              ╰──→ /nota:best-practices
  │                 │                                           │
  ╰─────────────────╰───────────────────────────────────────────╯
```

- **`/nota:think`** (ideation) — generates ideas drawing from the inspiration framework, MusaDSL knowledge, and your previous analyses and works. The more you have composed and analyzed, the richer the ideation becomes.
- **`/nota:code`** (composition) — implements ideas as working MusaDSL code, verified against the knowledge base, best practices, and similar works.
- **`/nota:index`** (knowledge building) — stores the composition's code, making it searchable and available for future reference by all other skills.
- **`/nota:analyze`** (reflection) — reads the code, interprets it musically, and stores the analysis as searchable knowledge. Marks reusable patterns as **[consolidation candidate]**.
- **`/nota:best-practices`** (consolidation) — extracts recurring patterns from analyses into formalized, searchable practices that feed back into `/nota:code`.
- Back to **`/nota:think`** — the new analysis and practices enrich future ideation: patterns detected across works, unexplored directions, dialogue with composers.

The two databases are the memory of this cycle:
- **`knowledge.db`** holds MusaDSL knowledge (what is possible)
- **`private.db`** holds your creative practice (what has been done, and what it means)

The cycle is not mandatory — you can enter at any point and use any skill independently. But each step enriches the others.

## Development (plugin maintainers)

This section is for contributors who want to modify the plugin itself or rebuild the public knowledge base from source.

### Architecture

The plugin has three knowledge layers:

1. **Static reference** (`rules/musadsl-reference.md` + `rules/best-practices.md`) — always loaded in context
2. **Semantic search** (MCP server + sqlite-vec + Voyage AI embeddings) — retrieves relevant docs, API, and code examples on demand
3. **Works catalog** — finds similar compositions from demos and private indexed works

Two separate databases:

- **`knowledge.db`** (public) — Documentation, API reference, demo code, and gem READMEs. Pre-built, automatically downloaded from GitHub Releases on session start. The CI workflow rebuilds it when source repos update.

- **`private.db`** (local, per-user) — User's indexed compositions and musical analyses. Stored at `~/.config/nota/private.db`, outside the plugin directory, persisting across updates. Never touched by CI or auto-updates.

When searching, the MCP server queries both databases and merges results by cosine distance. If `private.db` doesn't exist, searches use only the public knowledge base.

### MCP Tools (22)

| Tool | Purpose |
|------|---------|
| `search` | Semantic search across all knowledge (docs, API, demos, private works, analyses, best practices) |
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
| `save_best_practice` | Save a best practice (private or global scope) |
| `list_best_practices` | List all user best practices with indexing status |
| `remove_best_practice` | Remove a user best practice by name |
| `get_best_practices_index` | Get the user's condensed best practices index |
| `save_best_practices_index` | Save the user's condensed best practices index |

### Building the public knowledge base

Prerequisites: all MusaDSL source repositories cloned as siblings of `nota/`, and `VOYAGE_API_KEY` with sufficient quota for embedding ~3000 chunks.

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
nota/
├── .claude-plugin/          # Plugin metadata (plugin.json, marketplace.json)
├── skills/
│   ├── hello/               # /nota:hello skill — welcome and capabilities overview
│   ├── explain/             # /nota:explain skill — MusaDSL concept explanations
│   ├── code/                # /nota:code skill — composition coding and modification
│   ├── think/               # /nota:think skill — creative ideation and brainstorming
│   ├── index/               # /nota:index skill — manage private works index
│   ├── analyze/             # /nota:analyze skill — structured composition analysis
│   ├── best_practices/      # /nota:best-practices skill — manage best practices
│   ├── analysis_framework/  # /nota:analysis_framework skill — manage analysis dimensions
│   ├── inspiration_framework/ # /nota:inspiration_framework skill — manage inspiration dimensions
│   └── setup/               # /nota:setup skill — configuration and troubleshooting
├── defaults/                # Default configuration files
│   ├── analysis-framework.md      # Default analysis framework (10 dimensions)
│   └── inspiration-framework.md   # Default inspiration framework (9 dimensions)
├── rules/                   # Static reference (always in context)
│   ├── musadsl-reference.md       # Condensed API reference
│   └── best-practices.md         # Condensed best practices reference
├── data/
│   ├── best-practices/      # Global best practice source files (12 .md files)
│   └── chunks/              # Generated JSONL chunks + manifest
├── prompts/                 # Regeneration prompts for maintainers
│   └── regenerate-reference.md        # How to regenerate musadsl-reference.md
├── mcp_server/              # Ruby MCP server + sqlite-vec
│   ├── server.rb            # MCP tools (22 tools)
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
