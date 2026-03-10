# CLAUDE.md — nota-plugin-for-claude

## Project overview

Nota is a Claude Code plugin that transforms Claude into an algorithmic composition assistant for the [MusaDSL](https://musadsl.yeste.studio) framework. It provides 10 interactive skills, a semantic search MCP server backed by sqlite-vec, and two knowledge databases (public `knowledge.db` + private `private.db`).

## Project structure

```
nota-plugin-for-claude/
├── .claude-plugin/          # Plugin metadata
│   ├── plugin.json          #   Version, name, description
│   └── marketplace.json     #   Marketplace registry entry
├── skills/                  # 10 interactive skills (/nota:*)
├── rules/                   # Static reference (always in LLM context)
│   ├── musadsl-reference.md #   Condensed API reference (~700 lines)
│   └── best-practices.md   #   Condensed best practices (23 items)
├── data/
│   ├── best-practices/      #   Global best practice source files (23 .md)
│   └── chunks/              #   Generated JSONL chunks (gitignored)
├── defaults/                # Default frameworks (analysis, inspiration)
├── prompts/                 # Regeneration prompts for maintainers
├── mcp_server/              # Ruby MCP server (22 tools)
│   ├── server.rb            #   Tool definitions
│   ├── search.rb            #   Dual-DB semantic search
│   ├── chunker.rb           #   Source → JSONL chunks
│   ├── indexer.rb           #   Chunk + embed + store orchestrator
│   ├── embeddings.rb        #   Voyage AI integration
│   ├── db.rb                #   sqlite-vec database management
│   ├── ensure_db.rb         #   Auto-download knowledge.db on session start
│   └── knowledge.db         #   Public knowledge base (gitignored, auto-downloaded)
├── hooks/hooks.json         # SessionStart hook (auto-download)
├── .mcp.json                # MCP server configuration
├── Gemfile                  # Ruby deps: mcp, sqlite3, sqlite-vec
├── Makefile                 # Build targets
└── .github/workflows/       # CI: build-release.yml
```

## Key files and their roles

| File | Role | When to update |
|------|------|----------------|
| `rules/musadsl-reference.md` | Condensed API reference, always in context | When musa-dsl source or demos change |
| `rules/best-practices.md` | Condensed best practices summary, always in context | When best practices are added/modified |
| `data/best-practices/*.md` | Full best practice source files (embeddable) | When extracting new patterns |
| `.claude-plugin/plugin.json` | Plugin version + metadata | Every release |
| `.claude-plugin/marketplace.json` | Marketplace registry entry | Every release (keep version in sync) |
| `README.md` | User-facing documentation | When features/counts change |
| `mcp_server/chunker.rb` | Defines what gets chunked and how | When adding new content types |

## Developer workflows

### When musa-dsl source code or documentation changes

The API reference and knowledge base may be outdated.

1. **Regenerate `rules/musadsl-reference.md`** — follow the prompt in `prompts/regenerate-reference.md`. This reads all docs and source code from `../musa-dsl/` and rewrites the reference. Target: ~400-700 lines, accuracy over brevity, code is authoritative over docs.

2. **Rebuild knowledge.db** — run `make build` (requires `VOYAGE_API_KEY`). This re-chunks all sources and re-embeds.

3. **Verify** — run `make verify-server` to confirm the MCP server starts.

### When musadsl-demo changes

Demos affect both the knowledge base (demo code + READMEs are chunked) and potentially the best practices and reference.

1. **Review best practices** — read the new/changed demo code, contrast against existing practices in `data/best-practices/`, propose additions or modifications.

2. **If best practices change** — follow the "When best practices change" workflow below.

3. **Update demo index** — the demo index table at the end of `rules/musadsl-reference.md` must list all demos. Regenerate the reference if demos were added/removed.

4. **Rebuild knowledge.db** — `make build`.

### When best practices change

Best practices live in three places that must stay in sync:

1. **Source files** — `data/best-practices/*.md` (one file per practice, full content with example and anti-pattern)
2. **Condensed summary** — `rules/best-practices.md` (numbered list, one line per practice, always in LLM context)
3. **Knowledge base** — embedded in `knowledge.db` as `kind: "best_practice"` chunks

When adding, modifying, or removing practices:

1. Create/edit/delete the source file in `data/best-practices/`
2. Update `rules/best-practices.md` to reflect the change (add/edit/remove the corresponding numbered item)
3. Update the count in `README.md` (search for "practices" — appears in the best-practices skill description and in the project structure)
4. Rebuild knowledge.db — `make build`

### When releasing a new version

Checklist:

1. **Bump version** in TWO files (must match):
   - `.claude-plugin/plugin.json` → `"version"`
   - `.claude-plugin/marketplace.json` → `"version"` in the plugins array

2. **Update README.md** if any user-facing counts or features changed

3. **Rebuild knowledge.db** — `make build` (requires `VOYAGE_API_KEY`)

4. **Verify MCP server** — `make verify-server`

5. **Review all changes** before committing

6. **Commit and push** to main

7. **Tag the version** — `git tag v0.X.Y && git push --tags`

8. **Trigger knowledge.db release** — either:
   - The CI workflow triggers automatically if `chunker.rb` or `embeddings.rb` changed
   - Otherwise, manually trigger via GitHub Actions → "Build and Release Knowledge DB" → "Run workflow"
   - Users auto-download the new knowledge.db on their next session (checked every 24h)

### CI/CD: knowledge.db releases

The workflow `.github/workflows/build-release.yml` builds and releases `knowledge.db.gz` as a GitHub Release. Triggered by:

- `repository_dispatch` from source repos (musa-dsl, musadsl-demo, midi-*, musalce-server)
- Manual `workflow_dispatch`
- Push to main modifying `mcp_server/chunker.rb` or `mcp_server/embeddings.rb`

The release tag format is `db-YYYYMMDDHHMMSS`. Users download it automatically via the `ensure_db.rb` hook on session start.

## Build commands

```bash
make setup          # Install Ruby gem dependencies
make chunks         # Generate JSONL chunks only (no API key needed)
make build          # Full build: chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
make package        # gzip knowledge.db for distribution
make verify-server  # Test MCP server responds to initialize
make status         # Show index status (chunk counts by kind)
make clean          # Remove knowledge.db, chunks, and generated artifacts
```

## Important conventions

- **Rational for all timing values** — `1/4r`, never `0.25` or `1/4` (which is integer 0 in Ruby)
- **Best practice format** — each `.md` file has: `# Title`, `## Description`, `## Example` (```ruby), `## Anti-pattern` (```ruby). Optional: `## Variant` sections.
- **Source repos are siblings** — the Makefile assumes all MusaDSL repos are cloned as siblings under `../` (e.g., `../musa-dsl/`, `../musadsl-demo/`)
- **Two version files** — `plugin.json` and `marketplace.json` must always have the same version number
- **knowledge.db is gitignored** — never commit it; it's distributed via GitHub Releases
