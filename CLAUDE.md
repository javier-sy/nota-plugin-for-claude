# CLAUDE.md — nota-plugin

## Project overview

Nota is a **harness-agnostic** algorithmic composition assistant for the [MusaDSL](https://musadsl.yeste.studio) framework. Repo: [`javier-sy/nota-plugin`](https://github.com/javier-sy/nota-plugin) (renamed from `nota-plugin-for-claude`; the old URL redirects, so existing references keep working). The source lives in `src/` and a generator (`scripts/generate.rb`) emits per-harness plugin output (`dist/claude-code/`, `dist/opencode/`) from a neutral `src/manifest.yml` + per-target templates in `targets/`.

Each harness has its **own distribution registry**, and neither lives in this repo: Claude Code consumes [`javier-sy/claude-plugins`](https://github.com/javier-sy/claude-plugins) (the yeste.studio marketplace catalog plus a `nota/` directory, both written by this repo's CI); opencode consumes npm. This repo holds only source.

It provides 10 interactive skills, a semantic search MCP server backed by sqlite-vec, and two knowledge databases (public `knowledge.db` + private `private.db`).

## Project structure

```
nota-plugin/                      # source repo (harness-agnostic)
├── src/                          # FUENTE agnóstica
│   ├── manifest.yml              #   Neutral descriptor: name, version, mcp, skills, instructions
│   ├── mcp_server/               #   Ruby MCP server (22 tools) — harness-agnostic
│   │   ├── config.rb             #     Config.user_dir / cmd_ref / github_repo (env-driven)
│   │   ├── server.rb             #     Tool definitions
│   │   ├── search.rb             #     Dual-DB semantic search
│   │   ├── chunker.rb            #     Source → JSONL chunks
│   │   ├── indexer.rb            #     Chunk + embed + store orchestrator
│   │   ├── embeddings.rb         #     Voyage AI integration
│   │   ├── db.rb                 #     sqlite-vec database management
│   │   ├── ensure_db.rb          #     Auto-download knowledge.db on session start
│   │   └── knowledge.db          #     Public knowledge base (gitignored, auto-downloaded)
│   ├── rules/                    #   Always in context — assistant behaviour only
│   │   └── think-journal.md      #     (musa-dsl's own docs come from the gem)
│   ├── defaults/                 #   Default frameworks (analysis, inspiration)
│   ├── data/
│   │   └── best-practices/       #     The user's own practices (4 .md)
│   └── skills/<name>/SKILL.md    #   10 skills in superset format with {{cmd:X}} placeholders
├── targets/                      # Per-harness generation templates
│   ├── claude-code.yml           #   → dist/claude-code/ (plugin.json, .mcp.json, hooks)
│   └── opencode.yml              #   → dist/opencode/ (package.json, index.ts, opencode.json)
├── scripts/
│   ├── generate.rb               #   Generator: src/ + targets/ → dist/<harness>/
│   ├── update-marketplace-entry.rb # Rewrites nota's entry in the shared catalog
│   └── templates/
│       └── opencode-index.ts     #   TS plugin wrapper template for opencode
├── .github/workflows/
│   ├── build-release.yml         # CI: build + release knowledge.db.gz
│   └── generate-dist.yml         # CI: generate dist/ → publish to claude-plugins (+ npm)
├── Gemfile  Gemfile.lock         # Ruby deps: mcp, sqlite3, sqlite-vec (+ generator deps)
├── Makefile  .version  VERSION   # Build + version tooling
├── CLAUDE.md  README.md  LICENSE
└── dist/                         # Generated output (gitignored, CI-published)
    ├── claude-code/              #   → copied into javier-sy/claude-plugins as nota/
    └── opencode/                 #   → published on npm (currently held back)
```

The MCP server is harness-agnostic: `src/mcp_server/config.rb` reads `NOTA_USER_DIR`, `NOTA_CMD_PREFIX`, `NOTA_GITHUB_REPO` from env, with Claude Code defaults. A harness sets only what the server cannot work out for itself.

**A generated config never computes a path in the user's home.** It is written on one machine and read on another, and `${HOME}` has no value on any Windows install (the home is `USERPROFILE`). Observed on Claude Code 2.x: a `${VAR}` with no value and no `:-default` invalidates the entire server — `mcp-config-invalid: Missing environment variables: HOME` — and the plugin arrives with its skills and none of its tools. The documentation describes a softer behaviour, a warning with the literal text passed through, which would create a folder named `${HOME}`; the config must not refer to `HOME` under either. `Config.user_dir` resolves `~/.config/nota` with Ruby's `Dir.home` on every platform, and `Config.env` reads any variable still holding an unexpanded `${...}` as unset. `spec/invariants_spec.rb` fails if a target asks the harness for anything but `CLAUDE_PLUGIN_ROOT` and `VOYAGE_API_KEY`.

**The server installs its own gems, in its own process** (`mcp_server/boot.rb` + `mcp_server/ensure_gems.rb`). `/plugin install` copies files and `bundler/setup` installs nothing, so a fresh machine met the server with `Bundler::GemNotFound` — and since the server carries `check_setup`, nothing inside the session could say so.

**The MCP command is `ruby <root>/mcp_server/boot.rb`, never `-r bundler/setup`.** That is the whole mechanism: Bundler must not be the first thing to run, or the process dies before reaching the code that would fix it. `boot.rb` uses stdlib alone, calls `EnsureGems.provide!`, and only then requires Bundler and the server. `bundle check` first (local, no network); `bundle install` only when unsatisfied; five seconds and 16 MB, once. Everything it says goes to **stderr** — stdout is the MCP transport from the first byte. `spec/` fails if `-r bundler/setup` returns to either target.

The hook only *reports* (`EnsureGems.report`), so there is a single owner and nothing to race: it runs beside the server, not before it. It is also why opencode is covered, having no session hook at all.

**Windows on ARM cannot run this, and neither dependency is ours to fix.** Ruby there reports `aarch64-mingw-ucrt`. `sqlite3` publishes no binary for it (`x64-mingw-ucrt` is its only Windows platform) and cannot be compiled there either — SQLite's own `config.sub` rejects the `aarch64-w64-windows-gnu` triplet. `sqlite-vec`'s only Windows loadable is x86_64. **Adding the platform to `Gemfile.lock` changes nothing**: there is no gem to resolve.

Their states differ, and it matters for what to do about it. `sqlite3-ruby` has an open PR — [sparklemotion/sqlite3-ruby#650](https://github.com/sparklemotion/sqlite3-ruby/pull/650), cross-compiled with `rake-compiler-dock` ≥ 1.10.0, green in the author's fork since November 2025, held back by the maintainer over unrelated Windows CI failures, last activity April 2026. Stalled, not absent; a comment there with a real use case is the cheapest thing that could move it. Nokogiri's equivalent PR has not shipped either, and RubyInstaller offers Windows-on-ARM only for Ruby 3.4. sqlite-vec, by contrast, has no build and no attempt — but it is one C file with a published amalgamation, so building it ourselves is genuinely cheap. What stops that is verification: GitHub's `windows-11-arm` runners are documented as private-repository and paid, so we could cross-compile a loadable we cannot run. `EnsureGems.unsupported_reason` detects it and both boot.rb and the hook say so — the first to stop rather than spend the harness's 30s connection window, the second because the hook's output is the only one a reader sees. The way out is an x64 Ruby under emulation, selected with `NOTA_RUBY` so it need not take over PATH.

**The MCP command is `${NOTA_RUBY:-ruby}`**, in `.mcp.json`, `hooks.json` and the opencode template. `${VAR}` expands in `command` and `args`, not only `env`.

**Nothing large may happen inside the connection handshake.** The harness gives an MCP server 30s to answer `initialize`, and boot.rb already spends part of it installing gems. `run_server` used to download knowledge.db there too (9 MB compressed, 27 MB on disk) — a first session on a slow connection reported `CONNECT_TIMEOUT`. It now arrives through the SessionStart hook, which has its own budget, and through `Search.db_available?` on the first question. A tool call can wait; a handshake cannot.

**What is actually exercised, per platform.** macOS arm64: everything, daily. Linux x86_64: `build-release.yml` runs on `ubuntu-latest` and does chunks → embed → contract check → retrieval battery, so the database layer and vector search do run there — but nobody has used the plugin on Linux as a composer, and **the CI never runs `spec/` on any platform**. Windows: no complete session on record; 1.0.2 is the first version that can start. Say this plainly wherever it is claimed, and do not upgrade "should work" to "supported" without a session that proves it.

**Residual risk, unmeasured:** the harness's own timeout for an MCP server that has not answered `initialize`. Five seconds fits comfortably; a very slow connection might not, and then the server fails that session — which is exactly what happened before this existed, so it is a strict improvement rather than a new failure.

They go to `~/.config/nota/bundle`, not the reader's GEM_HOME: a plugin should not mutate someone's Ruby, a system Ruby would need root, and the user directory survives a plugin update while the versioned cache does not. That path cannot travel through `.mcp.json` — `${HOME}` is what the harness cannot expand — but it does not need to: the hook runs in a real Ruby, writes `<plugin_root>/.bundle/config` with an absolute `BUNDLE_PATH`, and the server finds the gems with the `BUNDLE_GEMFILE` it already has.

**The private bundle hides the user's own gems, and `musa_docs.rb` has to work around it.** `BUNDLE_PATH` makes Bundler point `GEM_HOME` at the private bundle and empty `GEM_PATH`, so `Gem.path` collapses to one directory — which broke `get_doc` and `list_docs` for the whole of 1.0.2 and 1.0.3, on every platform, while the hook (plain Ruby, no Bundler) kept working and made it look like a Windows problem. `MusaDocs.gem_roots` is the union that fixes it, and it needs all three parts: `Gem.user_dir`/`Gem.default_path` for a plain install, `Bundler.original_env` for rvm/rbenv — on a machine using rvm the last is the only one that finds anything. **Any new code that looks for a user-installed gem must go through `gem_roots`, never `Gem.path`.**

**The guard that keeps this out of a checkout is a coincidence of layout.** An installed plugin has `Gemfile` and `mcp_server/` as siblings; the source tree has the Gemfile one level higher, so `src/Gemfile` does not exist and `EnsureGems.installed?` is false. Moving the Gemfile or changing how the root is found would let a hook rewrite a developer's own `.bundle/config`. `spec/` asserts it.

**`sqlite-vec` is not a bundled gem, and must not become one again.** The gem's Windows binary is sound — a real `vec0.dll` — but it is published under the platform name `x86_64-mingw32`, which no Ruby on Windows reports (`x64-mingw32` before 3.1, `x64-mingw-ucrt` after). The same defect exists for Linux ARM64 (`arm64-linux` published, `aarch64-linux` reported): [asg017/sqlite-vec#248](https://github.com/asg017/sqlite-vec/issues/248), open and unanswered since 2025-11-04, upstream quiet since 2026-05-18. While the gem is a dependency, `bundle lock` cannot add `x64-mingw-ucrt` at all, and `bundler/setup` refuses on a platform the lockfile does not name — the server never starts. So `mcp_server/vec_extension.rb` fetches the loadable from the sqlite-vec GitHub release instead, pinned, cached under `~/.config/nota/sqlite-vec/<release>/<os>-<cpu>/vec0.<ext>`. Two traps, both fixed in `spec/`: the cached file must be named `vec0` (SQLite reads the entry point from the basename, so `vec0-macos-aarch64.dylib` sends it looking for `sqlite3_vec0macosaarch64_init`), and the version is pinned because an index is written by one vec0 and read by another.

**Open option: serve the loadable from our own releases.** Today the five tarballs are fetched from upstream's release (`asg017/sqlite-vec`, five platforms, ~200 KB each), which is the honest default — the artifact is theirs and its provenance is checkable. But it makes a runtime dependency on a repository with no commits since 2026-05-18, and nothing stops a release being retagged or deleted. The alternative is to attach the five tarballs to *our* releases and point `VecExtension::REPO` at `Config.github_repo`: about 1 MB added to each release of ours, plus the obligation to re-upload them whenever the pin moves. **Take this option if** upstream deletes or retags v0.1.9, or a download failure is ever reported that is not the user's network. Not before: mirroring a dependency is a maintenance burden bought with a real, if small, loss of provenance.

## Key files and their roles

| File | Role | When to update |
|------|------|----------------|
| `src/mcp_server/musa_docs.rb` | Reads musa-dsl's `docs/idioms.md` and `docs/vocabulary.md` from the **installed gem** into context at session start | When the version floor moves, or another document has to be always-present |
| `src/data/best-practices/*.md` | The **user's own** practices. Anything that describes musa-dsl itself belongs in musa-dsl's documentation, not here | When extracting a pattern that is genuinely the composer's and not the framework's |
| `src/manifest.yml` | Neutral source of truth (name, version, skills, mcp, instructions) | When structure/version/skills change |
| `src/mcp_server/config.rb` | Harness-specific config surface (3 env vars) | When adding a new harness target |
| `targets/*.yml` | Per-harness generation templates | When a harness's output format changes |
| `scripts/generate.rb` | The generator itself | When generation logic changes |
| `scripts/update-marketplace-entry.rb` | Rewrites this plugin's entry in the shared catalog of `javier-sy/claude-plugins`, leaving other plugins' entries alone | When the catalog's entry shape changes |
| `README.md` | User-facing documentation | When features/counts change |
| `src/mcp_server/chunker.rb` | Defines what gets chunked and how | When adding new content types |

## Developer workflows

### When musa-dsl source code or documentation changes

The knowledge base may be outdated. **There is nothing to regenerate by hand.**
The plugin no longer keeps a condensed copy of musa-dsl's API or philosophy: the
conceptual layer comes from the installed gem at session start
(`src/mcp_server/musa_docs.rb`), and `docs/vocabulary.md` is generated inside
musa-dsl by its own `tools/vocabulary.rb`, with a spec that fails when it is
stale. A prompt that asks a model to re-read the sources and rewrite a summary
is how a false claim gets promoted to a rule; that is why those prompts are gone.

1. **Rebuild knowledge.db** — run `make build` (requires `VOYAGE_API_KEY`). This re-chunks all sources and re-embeds.

2. **Verify** — run `make verify-server` to confirm the MCP server starts.

3. **If musa-dsl's documentation gained something the assistant must have BEFORE
   it is asked** — a new symptom index, say — add it to `MusaDocs::ALWAYS` and
   raise `MusaDocs::FLOOR` to the version that carries it. Anything that can wait
   for a question is not always-context: it is read on request.

### When musadsl-demo changes

Demos affect both the knowledge base (demo code + READMEs are chunked) and potentially the best practices and reference.

1. **Review best practices** — read the new/changed demo code, contrast against existing practices in `src/data/best-practices/`, propose additions or modifications.

2. **If best practices change** — follow the "When best practices change" workflow below.

3. **Rebuild knowledge.db** — `make build`. The demos are found by semantic
   similarity (`demo_readme`, `demo_code`); there is no index of them to keep in
   step.

### When best practices change

**First ask where it belongs.** A practice whose justification cites a property
of musa-dsl is not a practice, it is documentation of musa-dsl, and it goes to
musa-dsl — to `docs/guides/` if it is craft, to the relevant subsystem document
if it is a fact. What stays here is what is justified by how *this composer*
works. Nineteen of the original twenty-three left under that test.

What stays lives in two places that must agree:

1. **Source files** — `src/data/best-practices/*.md` (one file per practice, full content with example and anti-pattern)
2. **Knowledge base** — embedded in `knowledge.db` as `kind: "best_practice"` chunks

When adding, modifying, or removing practices:

1. Create/edit/delete the source file in `src/data/best-practices/`
2. Update the count in `README.md` (search for "practices" — appears in the best-practices skill description and in the project structure)
3. Rebuild knowledge.db — `make build`, and check the `best_practice` count it
   prints. A source that yields zero is a bug, not an empty collection: that is
   exactly what went unnoticed while the chunker looked for the practices at
   their pre-generator path.

### When skills change

Skills live in `src/skills/<name>/SKILL.md` in **superset format** with `{{cmd:X}}` placeholders. The generator resolves `{{cmd:X}}` per target:
- `claude-code` → `/nota:X`
- `opencode` → `the X skill`

Frontmatter: `name`, `description`, `version` (all preserved in source; `version` is stripped for opencode by the generator). The opencode generator also emits two `cfg.command` slash entries per skill — `/nota:<name>` (canonical, matches Claude Code) and `/<name>` (short synonym) — as thin wrappers whose template tells the model to invoke the skill. Adding/removing/renaming a skill regenerates these command entries on the next `make generate`. After editing skills, run `make generate` to regenerate `dist/`.

### When releasing a new version

Use `version.sh` from the ecosystem root (`MusaDSL/version.sh`):

```bash
# 1. Bump version (updates VERSION + manifest.yml via POST_VERSION_COMMAND)
./version.sh new patch|minor|major nota-plugin

# 2. Update README.md if any user-facing counts or features changed (manual)

# 3. Build knowledge.db + generate + install locally for testing (requires VOYAGE_API_KEY)
export VOYAGE_API_KEY=<your-key>
./version.sh local nota-plugin

# 4. Publish: verify-server + tag + commit + push
./version.sh publish nota-plugin

# 5. CI generates dist/ and publishes to javier-sy/claude-plugins via generate-dist.yml
#    (npm is held back — see "Re-enabling the opencode channel")
```

**Trigger knowledge.db release** — either:
- The CI workflow triggers automatically if `src/mcp_server/chunker.rb` or `src/mcp_server/embeddings.rb` changed
- Otherwise, manually trigger via GitHub Actions → "Build and Release Knowledge DB" → "Run workflow"
- Users auto-download the new knowledge.db on their next session (checked every 24h)

**Manual npm publish (rare — e.g. reserving a new package name)** — only if you ever publish to npm by hand instead of via CI:
- Use `npm publish --access public ./dist/opencode` (with the `./` prefix). A bare `dist/opencode` is parsed by pacote as a GitHub shorthand `github:dist/opencode` → spurious `git ls-remote` → 403.
- The npm account has 2FA on. A **Classic Automation** token (bypasses 2FA, no per-package scoping) is stored as the `NPM_TOKEN` secret. A granular token fails with `403` on a not-yet-existing package (chicken-and-egg).

### CI/CD

Two workflows (both have `concurrency: cancel-in-progress` to coalesce redundant concurrent runs):

1. **`build-release.yml`** — builds and releases `knowledge.db.gz` as a GitHub Release. Triggered by `repository_dispatch` (`source-updated`) from the 7 source repos' `notify-plugin.yml`, manual dispatch, or push to main modifying `src/mcp_server/chunker.rb` or `src/mcp_server/embeddings.rb`. The concurrency guard prevents `db-<timestamp>` tag collisions when several sources push near-simultaneously.

2. **`generate-dist.yml`** — runs `make generate` and publishes each distribution to its registry. Triggered by push to main modifying `src/**`, `targets/**`, `scripts/**`, `Gemfile`, or `Gemfile.lock`.

   **Claude Code channel** — clones `javier-sy/claude-plugins`, replaces its `nota/` directory with `dist/claude-code/`, runs `scripts/update-marketplace-entry.rb` to rewrite nota's catalog entry, and commits. Needs the `DIST_REPO_TOKEN` secret (a fine-grained PAT with `contents: write` on the distribution repo — `GITHUB_TOKEN` cannot reach another repo). The push retries with `pull --rebase` so two plugins publishing at once cannot lose each other's commit, and `knowledge.db` is deleted before committing in case a local build left one in `dist/`.

   **Why the plugin ships next to the catalog** — Claude Code resolves a `"source": "./nota"` entry inside the already-cloned catalog. Any entry pointing at a *different* repo goes through a code path that builds a `git@github.com:` URL unconditionally, without checking whether SSH is configured, so installation fails for anyone using HTTPS-authenticated GitHub (CLI bug, present through 2.1.222). This is why the `claude-release` orphan branch was abandoned.

   **⚠️ Fail-fast version check** — when the opencode channel is enabled, the workflow queries npm for the current version before publishing anything. If it **already exists on npm the workflow FAILS**, touching neither registry. This prevents silent divergence between Claude Code (rolling — updates every CI run) and opencode (immutable npm — needs a bump). **Consequence: every push to main touching `src/targets/scripts/Gemfile` requires a version bump** (`cd ../.. && ./version.sh new patch nota-plugin`), otherwise CI goes red with an `::error::` pointing at the bump command.

### Re-enabling the opencode channel

`PUBLISH_OPENCODE: 'false'` in `generate-dist.yml` holds npm back; the Claude Code
channel publishes normally meanwhile. **While it is off the two channels diverge
by design**: npm serves `nota-plugin-for-opencode@0.11.1` (1.0.0 never made it —
CI failed at `npm publish` with `E404` on the PUT, which npm returns for an
unauthorized write, i.e. `NPM_TOKEN` is no longer valid for this package).

To turn it back on, in this order:

1. Create the `yeste-studio` org on npm (the scope is free as of 2026-08-05).
2. Replace `NPM_TOKEN` with a granular token holding read/write on the new
   package, or move the job to Trusted Publishing (OIDC). The chicken-and-egg
   noted below — granular tokens 403 on a package that does not exist yet — is
   back in play, since `@yeste-studio/nota` will be new: publish 1.0.0 by hand
   the first time, then let CI take over.
3. Flip `PUBLISH_OPENCODE` to `'true'`.
4. `npm deprecate nota-plugin-for-opencode "renamed to @yeste-studio/nota"`.

One caveat worth knowing before flipping it: the Claude Code channel publishes
**before** npm, so a failing `npm publish` leaves Claude Code ahead — exactly the
failure that produced the current divergence. The `Verify both channels agree`
step at the end of the workflow turns that into a red build instead of a silent
drift, but it cannot undo the Claude Code publication. Publishing npm first would
remove the window entirely, at the cost of a failed Claude Code push leaving npm
ahead — a deliberate trade, since npm is immutable and the Claude Code channel
can simply be re-run.

## Build commands

```bash
make setup          # Install Ruby gem dependencies
make chunks         # Generate JSONL chunks only (no API key needed)
make build          # Full build: chunks + embeddings + knowledge.db (requires VOYAGE_API_KEY)
make generate       # Generate dist/claude-code/ + dist/opencode/ from src/ + targets/
make package        # gzip knowledge.db for distribution
make verify-server  # Test MCP server responds to initialize
make status         # Show index status (chunk counts by kind)
make clean          # Remove knowledge.db, chunks, dist/, and generated artifacts
```

## Important conventions

- **Rational for all timing values** — `1/4r`, never `0.25` or `1/4` (which is integer 0 in Ruby)
- **Best practice format** — each `.md` file has: `# Title`, `## Description`, `## Example` (```ruby), `## Anti-pattern` (```ruby). Optional: `## Variant` sections.
- **Source repos are siblings** — the Makefile assumes all MusaDSL repos are cloned as siblings under `../` (e.g., `../musa-dsl/`, `../musadsl-demo/`)
- **Version lives in `src/manifest.yml`** — the generator propagates it to `plugin.json`, `package.json` and `VERSION`, and the CI carries it from the generated `plugin.json` into the distribution catalog. `./version.sh new` bumps `VERSION` and (via `POST_VERSION_COMMAND`) `manifest.yml`.
- **knowledge.db is gitignored** — never commit it; it's distributed via GitHub Releases
- **dist/ is gitignored** — never commit it; CI generates and publishes it
- **Skills use `{{cmd:X}}` placeholders** — never hardcode `/nota:X` in skill source; the generator resolves per target
- **Every push to main touching `src/targets/scripts/Gemfile` requires a version bump** — `generate-dist.yml` fails fast if the `src/manifest.yml` version already exists on npm (prevents Claude Code/opencode divergence). Run `./version.sh nota-plugin <new-version>` from `MusaDSL/` before pushing.
- **User private data at `~/.config/nota/`** (`private.db`, `best-practices/`, `private-best-practices.md`) — never read or modify without an explicit user request.

## References

- opencode config schema: https://opencode.ai/config.json
- Claude Code plugins reference: https://docs.claude.com/en/docs/claude-code/plugins-reference
- Claude Code plugin marketplaces: https://docs.claude.com/en/docs/claude-code/plugin-marketplaces
